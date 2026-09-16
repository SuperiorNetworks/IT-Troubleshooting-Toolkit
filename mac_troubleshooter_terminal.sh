#!/bin/bash
# ==============================================================================
# Script Name : mac_troubleshooter_terminal.sh
# Version     : Master toolkit version dynamically read from launch_menu.ps1
# Purpose     : Provides a terminal-based macOS troubleshooting menu for Superior
#               Networks LLC. The first option safely guides a signed-in user
#               through the OneDrive sync repair workflow after an OS update.
# Author      : Dwain Henderson Jr., Superior Networks LLC
# Copyright   : (c) 2026 Superior Networks LLC. All rights reserved.
#
# Key Features:
#   - Interactive macOS troubleshooting terminal with a guided repair workflow
#   - Option 1 runs the OneDrive repair in dry-run mode before requesting approval
#   - Option 2 checks GitHub for a user-initiated fast-forward update
#   - Reads the single master toolkit version from launch_menu.ps1 at runtime
#   - Records terminal selections, outcomes, and errors in a master audit log
#   - Runs as the signed-in macOS user and does not require administrator access
#
# Inputs      : Interactive menu selection
# Outputs     : Console status output
#               Audit: ~/Library/Logs/SuperiorNetworks/master_audit_log.txt
# Dependencies: macOS 12 or later, bash 3.2+, Fix-OneDriveSync-macOS.sh in the
#               same directory, and read/write access to the signed-in user's home
#               directory. No admin rights required.
# Notes       : Run as the signed-in user, NOT with sudo. OneDrive credentials and
#               sync preferences are per-user. The repair tool backs up plist files
#               and never deletes content from a OneDrive sync folder.
# ==============================================================================

set -u

SCRIPT_NAME="mac_troubleshooter_terminal.sh"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ONEDRIVE_TOOL="$SCRIPT_DIR/Fix-OneDriveSync-macOS.sh"
BOOTSTRAP_TOOL="$SCRIPT_DIR/bootstrap_macos.sh"
LOG_DIR="$HOME/Library/Logs/SuperiorNetworks"
MASTER_AUDIT_LOG="$LOG_DIR/master_audit_log.txt"

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

TOOLKIT_VERSION="$(get_toolkit_version)"

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

wait_for_key() {
    printf '\nPress Return to continue...'
    read -r _unused
}

show_menu() {
    clear
    printf '\n'
    printf '  =================================================================\n'
    printf '                     SUPERIOR NETWORKS LLC                        \n'
    printf '          macOS Troubleshooter Terminal - Toolkit v%s\n' "$TOOLKIT_VERSION"
    printf '  =================================================================\n'
    printf '\n'
    printf '  Troubleshooting Tools:\n'
    printf '    1. OneDrive Sync Repair (macOS post-update failures)\n'
    printf '       Runs a dry-run preview first, then offers the safe repair.\n'
    printf '\n'
    printf '  Toolkit Management:\n'
    printf '    2. Check GitHub for Toolkit Updates\n'
    printf '       User-initiated only; preserves Git version history.\n'
    printf '\n'
    printf '    Q. Quit\n'
    printf '\n'
    printf '  Audit Log: %s\n' "$MASTER_AUDIT_LOG"
    printf '\n'
}

run_onedrive_repair() {
    local status=0
    local approval=""

    write_audit_log "INFO" "Menu Selection" "Option 1: OneDrive Sync Repair"
    clear
    printf '\n=== OneDrive Sync Repair ===\n\n'
    printf 'This workflow first previews all actions. It does not remove OneDrive data.\n'
    printf 'Preference files are backed up before a live repair changes them.\n\n'

    if [ ! -f "$ONEDRIVE_TOOL" ]; then
        printf 'Error: OneDrive repair script not found.\n'
        printf 'Expected: %s\n' "$ONEDRIVE_TOOL"
        write_audit_log "ERROR" "OneDrive Sync Repair" "Required script not found: $ONEDRIVE_TOOL"
        wait_for_key
        return
    fi

    if [ ! -x "$ONEDRIVE_TOOL" ]; then
        printf 'Making the OneDrive repair script executable...\n'
        if chmod +x "$ONEDRIVE_TOOL"; then
            write_audit_log "INFO" "OneDrive Sync Repair" "Set executable permission on Fix-OneDriveSync-macOS.sh"
        else
            printf 'Error: Could not set executable permission on the OneDrive repair script.\n'
            write_audit_log "ERROR" "OneDrive Sync Repair" "Could not set executable permission on $ONEDRIVE_TOOL"
            wait_for_key
            return
        fi
    fi

    printf 'Step 1 of 2: Running the safety preview...\n\n'
    "$ONEDRIVE_TOOL" --dry-run
    status=$?
    if [ "$status" -ne 0 ]; then
        printf '\nDry run stopped with exit code %s. No repair was performed.\n' "$status"
        write_audit_log "ERROR" "OneDrive Sync Repair" "Dry run exited with code $status"
        wait_for_key
        return
    fi

    printf '\nStep 2 of 2: Review the preview above.\n'
    printf 'Run the live repair now? Type YES to proceed: '
    read -r approval
    if [ "$approval" != "YES" ]; then
        printf '\nLive repair cancelled. The dry run made no changes.\n'
        write_audit_log "INFO" "OneDrive Sync Repair" "Live repair cancelled after dry run"
        wait_for_key
        return
    fi

    write_audit_log "INFO" "OneDrive Sync Repair" "Live repair approved after dry run"
    printf '\nRunning the live repair...\n\n'
    "$ONEDRIVE_TOOL"
    status=$?
    if [ "$status" -eq 0 ]; then
        printf '\nOneDrive repair completed. Review the repair transcript shown above.\n'
        write_audit_log "SUCCESS" "OneDrive Sync Repair" "Live repair completed successfully"
    else
        printf '\nOneDrive repair exited with code %s. Review its transcript and master audit log.\n' "$status"
        write_audit_log "ERROR" "OneDrive Sync Repair" "Live repair exited with code $status"
    fi
    wait_for_key
}

run_toolkit_update() {
    write_audit_log "INFO" "Menu Selection" "Option 2: Check GitHub for Toolkit Updates"
    clear
    printf '\n=== Check GitHub for Toolkit Updates ===\n\n'
    printf 'This performs a Git fast-forward update only when you choose this option.\n'
    printf 'Local uncommitted changes are protected and will not be overwritten.\n\n'

    if [ ! -f "$BOOTSTRAP_TOOL" ]; then
        printf 'Error: macOS Git bootstrapper not found.\n'
        printf 'Expected: %s\n' "$BOOTSTRAP_TOOL"
        write_audit_log "ERROR" "Toolkit Update" "Bootstrapper not found: $BOOTSTRAP_TOOL"
        wait_for_key
        return
    fi

    if [ ! -x "$BOOTSTRAP_TOOL" ]; then
        if ! chmod +x "$BOOTSTRAP_TOOL"; then
            printf 'Error: Could not set executable permission on the Git bootstrapper.\n'
            write_audit_log "ERROR" "Toolkit Update" "Could not set executable permission on $BOOTSTRAP_TOOL"
            wait_for_key
            return
        fi
    fi

    write_audit_log "INFO" "Toolkit Update" "Starting user-initiated Git update"
    exec "$BOOTSTRAP_TOOL"
}

if [ "$(uname -s)" != "Darwin" ]; then
    printf '%s supports macOS only.\n' "$SCRIPT_NAME" >&2
    exit 2
fi

if [ "$(id -u)" -eq 0 ]; then
    printf 'Do not run %s with sudo. Run it as the signed-in macOS user.\n' "$SCRIPT_NAME" >&2
    exit 3
fi

mkdir -p "$LOG_DIR" || {
    printf 'Unable to create the audit log directory: %s\n' "$LOG_DIR" >&2
    exit 1
}
write_audit_log "INFO" "macOS Troubleshooter Terminal" "Terminal opened; toolkit version $TOOLKIT_VERSION"

while true; do
    show_menu
    printf '  Select an option (1-2 or Q): '
    choice=""
    read -r choice || choice="Q"

    case "$choice" in
        1)
            run_onedrive_repair
            ;;
        2)
            run_toolkit_update
            ;;
        Q|q)
            write_audit_log "INFO" "macOS Troubleshooter Terminal" "User selected Quit"
            printf '\nExiting macOS Troubleshooter Terminal...\n'
            exit 0
            ;;
        *)
            printf '\nInvalid selection. Please choose 1-2 or Q.\n'
            write_audit_log "WARN" "Invalid Menu Selection" "User entered: $choice"
            sleep 2
            ;;
    esac
done
