#!/bin/bash
# ==============================================================================
# Script Name : Fix-OneDriveSync-macOS.sh
# Version     : Master toolkit version dynamically read from launch_menu.ps1
# Purpose     : Repair OneDrive sync failures on macOS following an OS update by
#               stopping OneDrive and Office processes, removing stale OneDrive
#               Keychain credentials, deleting the OneDrive sync preference
#               files, and relaunching OneDrive for a clean sign-in.
# Author      : Dwain Henderson Jr., Superior Networks LLC
# Copyright   : (c) 2026 Superior Networks LLC. All rights reserved.
#
# Key Features:
#   - Pre-flight safety check for pending OneDrive uploads before any change
#   - Graceful quit, then force stop, of OneDrive and Office helper processes
#   - Removes "OneDrive Cached Credential" and related login keychain items
#   - Deletes UBF8T346G9.OneDriveSyncClientSuite.plist and
#     UBF8T346G9.OfficeOneDriveSyncIntegration.plist from both known locations
#   - Backs up every removed plist before deletion, timestamped
#   - Flushes the cfprefsd preference cache so old settings are not restored
#   - Timestamped transcript and master audit logs for ticket documentation
#   - Automatically opens the completed transcript in TextEdit for review
#   - --dry-run mode to preview all actions with no changes
#   - Never touches user data inside the OneDrive folder
#
# Inputs      : Optional flags
#                 --dry-run       Report actions only, change nothing
#                 --no-relaunch   Skip relaunching OneDrive at the end
#                 --no-open-log   Do not automatically open the transcript log
#                 --help          Show usage
# Outputs     : Console status output
#               Log  : ~/Library/Logs/SuperiorNetworks/Fix-OneDriveSync-<stamp>.log
#               Audit: ~/Library/Logs/SuperiorNetworks/master_audit_log.txt
#               Bkup : ~/Desktop/OneDrive-Plist-Backup-<stamp>/
# Exit Codes  : 0 success, 1 usage error, 2 unsupported platform,
#               3 run as root (not permitted), 4 OneDrive would not close
# Dependencies: macOS 12 or later, bash 3.2+, /usr/bin/security, /usr/bin/plutil,
#               /usr/bin/osascript, /usr/bin/killall. No admin rights required.
# Notes       : Run as the signed-in user, NOT with sudo. Keychain and preference
#               files are per-user. A full "reset OneDrive" is intentionally NOT
#               performed because it can remove local content. Dry-run mode does
#               not close or relaunch OneDrive because it must make no changes.
# ==============================================================================

set -u

# ------------------------------ Configuration --------------------------------
SCRIPT_NAME="Fix-OneDriveSync-macOS.sh"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

LOG_DIR="$HOME/Library/Logs/SuperiorNetworks"
LOG_FILE="$LOG_DIR/Fix-OneDriveSync-$STAMP.log"
MASTER_AUDIT_LOG="$LOG_DIR/master_audit_log.txt"
BACKUP_DIR="$HOME/Desktop/OneDrive-Plist-Backup-$STAMP"

GROUP_PREFS="$HOME/Library/Group Containers/UBF8T346G9.Office/Library/Preferences"
USER_PREFS="$HOME/Library/Preferences"

PLIST_NAMES=(
  "UBF8T346G9.OneDriveSyncClientSuite.plist"
  "UBF8T346G9.OfficeOneDriveSyncIntegration.plist"
)

# Keychain generic-password labels to purge, in order.
KEYCHAIN_LABELS=(
  "OneDrive Cached Credential"
  "OneDriveStandaloneSuite"
  "OneDrive"
)

# Process names to stop. OneDrive first, then Office integration helpers.
PROCESSES=(
  "OneDrive"
  "OneDrive File Provider"
  "OneDriveStandaloneUpdater"
  "OneDriveUpdaterDaemon"
  "OneDriveSyncIntegration"
  "Microsoft Word"
  "Microsoft Excel"
  "Microsoft PowerPoint"
  "Microsoft Outlook"
  "Microsoft Teams"
)

DRY_RUN=0
RELAUNCH=1
OPEN_LOG=1
CHANGES=0
WARNINGS=0

# -------------------------------- Utilities ----------------------------------
get_toolkit_version() {
  local launcher_path="$SCRIPT_DIR/launch_menu.ps1"
  local version=""

  if [ -f "$launcher_path" ]; then
    version="$(awk '/^Version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+/ { print $2; exit }' "$launcher_path" 2>/dev/null)"
  fi

  if [ -z "$version" ] && command -v curl >/dev/null 2>&1; then
    version="$(curl -fsSL --connect-timeout 5 --max-time 10 \
      "https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/launch_menu.ps1" \
      2>/dev/null | awk '/^Version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+/ { print $2; exit }')"
  fi

  if [ -n "$version" ]; then
    printf '%s\n' "$version"
  else
    printf '%s\n' "Unknown"
  fi
}

SCRIPT_VERSION="$(get_toolkit_version)"

write_audit_log() {
  local level="$1"
  local action="$2"
  local details="${3:-}"
  local timestamp

  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  {
    printf '[%s] [%s] [%s@%s]\n' "$timestamp" "$level" "$(id -un)" "$(hostname -s)"
    printf '  Action: %s\n' "$action"
    [ -n "$details" ] && printf '  Details: %s\n' "$details"
    printf '  Script: %s\n' "$SCRIPT_NAME"
    printf '%s\n' "======================================================================"
  } >> "$MASTER_AUDIT_LOG" 2>/dev/null
}

log()  { printf '%s  %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG_FILE"; }
head1() { log ""; log "=== $* ==="; }
ok()   { log "  [ OK ]   $*"; }
skip() { log "  [ SKIP ] $*"; }
warn() { log "  [ WARN ] $*"; WARNINGS=$((WARNINGS+1)); }
act()  { log "  [ ACT ]  $*"; CHANGES=$((CHANGES+1)); }
plan() { log "  [ DRY ]  would $*"; }

open_transcript_log() {
  printf '\n=== Opening repair transcript ===\n'

  if [ "$OPEN_LOG" -eq 0 ]; then
    printf '  [ SKIP ] Automatic transcript opening skipped by --no-open-log\n'
    write_audit_log "INFO" "OneDrive Sync Repair" "Automatic transcript opening skipped by --no-open-log; transcript=$LOG_FILE"
    return
  fi

  if [ ! -f "$LOG_FILE" ]; then
    printf '  [ WARN ] Transcript was not found, so it could not be opened: %s\n' "$LOG_FILE"
    write_audit_log "ERROR" "OneDrive Sync Repair" "Transcript was missing when automatic opening was requested; transcript=$LOG_FILE"
    return
  fi

  printf '  Transcript is complete and ready for review: %s\n' "$LOG_FILE"
  if /usr/bin/open -a TextEdit "$LOG_FILE" >/dev/null 2>&1; then
    printf '  [ OK ]   Transcript opened in TextEdit for review.\n'
    write_audit_log "SUCCESS" "OneDrive Sync Repair" "Opened transcript in TextEdit; transcript=$LOG_FILE"
  elif /usr/bin/open "$LOG_FILE" >/dev/null 2>&1; then
    printf '  [ OK ]   Transcript opened with the Mac default log viewer.\n'
    write_audit_log "SUCCESS" "OneDrive Sync Repair" "Opened transcript with default application; transcript=$LOG_FILE"
  else
    printf '  [ WARN ] Could not automatically open the transcript. Open it manually: %s\n' "$LOG_FILE"
    write_audit_log "ERROR" "OneDrive Sync Repair" "Could not automatically open transcript; transcript=$LOG_FILE"
  fi
}

get_running_onedrive_processes() {
  /usr/bin/pgrep -fl -i onedrive 2>/dev/null | grep -v "$SCRIPT_NAME" || true
}

verify_onedrive_stopped() {
  local still_running=""

  still_running="$(get_running_onedrive_processes)"
  if [ -n "$still_running" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      plan "verify OneDrive is closed before a live credential or preference repair"
      log "  [ DRY ]  OneDrive is currently running; the live repair would close it first."
      return 0
    fi

    warn "OneDrive-related processes are still running. No credential or preference changes will be made."
    printf '%s\n' "$still_running" | while IFS= read -r L; do log "           $L"; done
    write_audit_log "ERROR" "OneDrive Sync Repair" "OneDrive would not close; repair stopped before credential or preference changes"
    exit 4
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    plan "verify OneDrive is closed before a live credential or preference repair"
  else
    ok "Verified OneDrive is closed before credential and preference repair."
    write_audit_log "INFO" "OneDrive Sync Repair" "Verified OneDrive closed before credential and preference repair"
  fi
}

usage() {
  cat <<USAGE
$SCRIPT_NAME  Toolkit v$SCRIPT_VERSION  -  Superior Networks LLC

Repairs macOS OneDrive sync after an OS update.

Usage:
  ./$SCRIPT_NAME [--dry-run] [--no-relaunch] [--no-open-log]

Options:
  --dry-run       Show every action without changing anything
  --no-relaunch   Do not reopen OneDrive when finished
  --no-open-log   Do not automatically open the completed transcript
  --help          Show this help

Run as the signed-in user. Do not use sudo.
USAGE
}

# ------------------------------ Argument parse -------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)     DRY_RUN=1 ;;
    --no-relaunch) RELAUNCH=0 ;;
    --no-open-log) OPEN_LOG=0 ;;
    --help|-h)     usage; exit 0 ;;
    *)             printf 'Unknown option: %s\n\n' "$1"; usage; exit 1 ;;
  esac
  shift
done

# ------------------------------- Pre-flight ----------------------------------
mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

log "$SCRIPT_NAME Toolkit v$SCRIPT_VERSION  |  Superior Networks LLC"
log "Started $(date '+%Y-%m-%d %H:%M:%S')  User: $(id -un)  Host: $(hostname -s)"
[ "$DRY_RUN" -eq 1 ] && log "MODE: DRY RUN. No changes will be made."
log "Log file: $LOG_FILE"
write_audit_log "INFO" "OneDrive Sync Repair" "Started; toolkit version $SCRIPT_VERSION; dry-run=$DRY_RUN; relaunch=$RELAUNCH"

if [ "$(uname -s)" != "Darwin" ]; then
  log "This script supports macOS only. Exiting."
  write_audit_log "ERROR" "OneDrive Sync Repair" "Unsupported platform"
  exit 2
fi

if [ "$(id -u)" -eq 0 ]; then
  log "Do not run this script as root or with sudo. Keychain and preference"
  log "files belong to the signed-in user. Exiting."
  write_audit_log "ERROR" "OneDrive Sync Repair" "Run as root was blocked"
  exit 3
fi

log "macOS version: $(sw_vers -productVersion)"
if [ -d "/Applications/OneDrive.app" ]; then
  OD_VER="$(/usr/bin/defaults read /Applications/OneDrive.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo unknown)"
  log "OneDrive installed version: $OD_VER"
else
  warn "OneDrive.app was not found in /Applications. Verify the install."
fi

# -------------------- Step 0: pending upload safety check --------------------
head1 "Step 0: Checking for pending uploads"
PENDING=0
for CANDIDATE in "$HOME/OneDrive"* "$HOME/Library/CloudStorage/OneDrive"*; do
  [ -d "$CANDIDATE" ] || continue
  log "  Sync folder present: $CANDIDATE"
  RECENT="$(find "$CANDIDATE" -type f -mmin -15 2>/dev/null | head -5)"
  if [ -n "$RECENT" ]; then
    PENDING=1
    warn "Files modified in the last 15 minutes were found here:"
    printf '%s\n' "$RECENT" | while IFS= read -r F; do log "           $F"; done
  fi
done

if [ "$PENDING" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
  log ""
  log "  Recent edits were detected. Confirm those files show a green check or"
  log "  solid cloud in Finder before continuing."
  printf '  Continue anyway? Type YES to proceed: '
  read -r ANSWER
  if [ "$ANSWER" != "YES" ]; then
    log "Aborted at user request. No changes were made."
    write_audit_log "INFO" "OneDrive Sync Repair" "User stopped repair after pending-upload warning"
    exit 0
  fi
  log "  User confirmed. Continuing."
else
  ok "No recent-edit risk detected, or dry run in effect."
fi

# ----------------------- Step 1: stop OneDrive / Office ----------------------
head1 "Step 1: Stopping OneDrive and Office processes"
for PROC in "${PROCESSES[@]}"; do
  if /usr/bin/pgrep -x "$PROC" >/dev/null 2>&1; then
    if [ "$DRY_RUN" -eq 1 ]; then
      plan "quit \"$PROC\""
      continue
    fi
    /usr/bin/osascript -e "tell application \"$PROC\" to quit" >/dev/null 2>&1
    sleep 2
    if /usr/bin/pgrep -x "$PROC" >/dev/null 2>&1; then
      /usr/bin/killall -TERM "$PROC" >/dev/null 2>&1
      sleep 2
    fi
    if /usr/bin/pgrep -x "$PROC" >/dev/null 2>&1; then
      /usr/bin/killall -KILL "$PROC" >/dev/null 2>&1
      sleep 1
    fi
    if /usr/bin/pgrep -x "$PROC" >/dev/null 2>&1; then
      warn "\"$PROC\" is still running. macOS may be relaunching a helper."
    else
      act "Stopped \"$PROC\""
    fi
  else
    skip "\"$PROC\" was not running"
  fi
done

# Verify the live repair never changes credentials or preferences while OneDrive
# is still active. Dry-run mode reports the required sequence without changing it.
verify_onedrive_stopped

# ---------------------- Step 2: purge keychain credentials -------------------
head1 "Step 2: Removing cached OneDrive keychain credentials"
for LABEL in "${KEYCHAIN_LABELS[@]}"; do
  FOUND=0
  while /usr/bin/security find-generic-password -l "$LABEL" >/dev/null 2>&1; do
    FOUND=1
    if [ "$DRY_RUN" -eq 1 ]; then
      plan "delete keychain item \"$LABEL\""
      break
    fi
    if /usr/bin/security delete-generic-password -l "$LABEL" >/dev/null 2>&1; then
      act "Deleted keychain item \"$LABEL\""
    else
      warn "Could not delete \"$LABEL\". Remove it manually in Keychain Access."
      break
    fi
  done
  [ "$FOUND" -eq 0 ] && skip "No keychain item labeled \"$LABEL\""
done

# Also clear internet-password entries some builds create.
while /usr/bin/security find-internet-password -l "OneDrive" >/dev/null 2>&1; do
  if [ "$DRY_RUN" -eq 1 ]; then
    plan "delete internet-password item \"OneDrive\""
    break
  fi
  if /usr/bin/security delete-internet-password -l "OneDrive" >/dev/null 2>&1; then
    act "Deleted internet-password item \"OneDrive\""
  else
    break
  fi
done

# ------------------- Step 3: back up and delete the plists -------------------
head1 "Step 3: Removing OneDrive sync preference files"
if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$BACKUP_DIR"
  log "  Backup folder: $BACKUP_DIR"
fi

for DIR in "$GROUP_PREFS" "$USER_PREFS"; do
  for NAME in "${PLIST_NAMES[@]}"; do
    TARGET="$DIR/$NAME"
    if [ -f "$TARGET" ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        plan "back up and delete: $TARGET"
        continue
      fi
      SAFE="$(printf '%s' "$DIR" | tr '/ ' '__')"
      if cp -p "$TARGET" "$BACKUP_DIR/${SAFE}__${NAME}" 2>/dev/null; then
        if rm -f "$TARGET"; then
          act "Deleted $TARGET"
        else
          warn "Backed up but could not delete $TARGET"
        fi
      else
        warn "Backup failed for $TARGET. File was left in place."
      fi
    else
      skip "Not present: $TARGET"
    fi
  done
done

# Catch copies in non-standard locations under ~/Library.
EXTRA="$(find "$HOME/Library" -maxdepth 6 -name "UBF8T346G9.OneDriveSyncClientSuite.plist" \
         -o -maxdepth 6 -name "UBF8T346G9.OfficeOneDriveSyncIntegration.plist" 2>/dev/null || true)"
if [ -n "$EXTRA" ]; then
  warn "Additional copies remain in non-standard locations. Review manually:"
  printf '%s\n' "$EXTRA" | while IFS= read -r F; do log "           $F"; done
fi

# ------------------- Step 4: flush the preference cache ---------------------
head1 "Step 4: Flushing the preference cache"
if [ "$DRY_RUN" -eq 1 ]; then
  plan "restart cfprefsd so deleted settings are not restored"
else
  if /usr/bin/killall -HUP cfprefsd >/dev/null 2>&1; then
    act "Restarted cfprefsd"
  else
    warn "Could not signal cfprefsd. A restart of the Mac will accomplish this."
  fi
fi

# ------------------------ Step 5: relaunch OneDrive -------------------------
head1 "Step 5: Relaunching OneDrive"
if [ "$RELAUNCH" -eq 0 ]; then
  skip "Relaunch skipped by --no-relaunch"
  write_audit_log "INFO" "OneDrive Sync Repair" "OneDrive relaunch skipped by --no-relaunch"
elif [ "$DRY_RUN" -eq 1 ]; then
  plan "open /Applications/OneDrive.app"
elif [ -d "/Applications/OneDrive.app" ]; then
  if /usr/bin/open -a "/Applications/OneDrive.app" 2>/dev/null; then
    act "Launched OneDrive. Sign in when prompted."
    write_audit_log "SUCCESS" "OneDrive Sync Repair" "OneDrive relaunched after live repair"
  else
    warn "Could not launch OneDrive. Open it from the Applications folder."
    write_audit_log "ERROR" "OneDrive Sync Repair" "OneDrive could not be relaunched automatically"
  fi
else
  warn "OneDrive.app not found. Install the current version, then sign in."
  write_audit_log "ERROR" "OneDrive Sync Repair" "OneDrive.app was not available for relaunch"
fi

# ----------------------------- Summary -------------------------------------
head1 "Summary"
log "  Changes made : $CHANGES"
log "  Warnings     : $WARNINGS"
[ "$DRY_RUN" -eq 0 ] && log "  Plist backups: $BACKUP_DIR"
log "  Transcript   : $LOG_FILE"
log ""
log "  Next steps for the user:"
log "   1. Sign in to OneDrive with the work email address."
log "   2. Accept the EXISTING OneDrive folder location. Do not pick a new one."
log "   3. Approve any macOS system extension or file access prompt."
log "   4. Check the App Store Updates tab for OneDrive and Office updates."
log "   5. Verify sync: create sync-test.txt in the OneDrive folder, confirm it"
log "      appears at office.com, rename it there, and confirm the new name"
log "      reaches the Mac. Delete the test file when both directions pass."
log ""
log "  A full OneDrive reset was NOT performed. That step can remove local"
log "  content and should only be run after backup state is verified."
log ""

if [ "$DRY_RUN" -eq 1 ]; then
  write_audit_log "SUCCESS" "OneDrive Sync Repair" "Dry run completed successfully; changes=0; warnings=$WARNINGS"
else
  write_audit_log "SUCCESS" "OneDrive Sync Repair" "Live repair completed; changes=$CHANGES; warnings=$WARNINGS; transcript=$LOG_FILE"
fi

log "Finished $(date '+%Y-%m-%d %H:%M:%S')"
open_transcript_log

exit 0
