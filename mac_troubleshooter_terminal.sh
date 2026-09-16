#!/bin/bash
# ==============================================================================
# Name: mac_troubleshooter_terminal.sh
# Version: Master toolkit version dynamically read from launch_menu.ps1
# Purpose: Provides a branded, accessible macOS troubleshooting terminal for
#          Superior Networks LLC with guided repair, update, and help workflows.
# Author: Dwain Henderson Jr. | Superior Networks LLC
# Contact: (937) 985-2480 | dhenderson@superiornetworks.biz
# Copyright: 2026, Superior Networks LLC
# Location: ~/ITTools/Scripts/mac_troubleshooter_terminal.sh
#
# What This Script Does:
#   - Presents a graphical ANSI terminal dashboard for macOS troubleshooting
#   - Guides the user through a dry-run-first OneDrive sync repair workflow
#   - Performs user-initiated GitHub updates through the Git bootstrapper
#   - Displays an in-terminal Help Guide and persistent release-version footer
#   - Records selections, approvals, outcomes, and errors in the master audit log
#
# Input:
#   - Interactive menu selections, optional OneDrive repair confirmation, and
#     terminal capabilities for graphical ANSI rendering
#
# Output:
#   - Branded terminal dashboard, instructions, and status cards
#   - Audit: ~/Library/Logs/SuperiorNetworks/master_audit_log.txt
#
# Dependencies:
#   - macOS 12 or later, Bash 3.2+, mac_terminal_ui.sh,
#     Fix-OneDriveSync-macOS.sh, bootstrap_macos.sh, and terminal access
#   - assets/superior-networks-logo.png is used as an optional iTerm2 enhancement
#
# Change Log:
#   2026-09-16 v3.12.0 - Added branded graphical dashboard, instruction cards,
#                        footer versioning, and built-in Help Guide (Dwain Henderson Jr.)
# ==============================================================================

set -u

SCRIPT_NAME="mac_troubleshooter_terminal.sh"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
UI_TOOL="$SCRIPT_DIR/mac_terminal_ui.sh"
ONEDRIVE_TOOL="$SCRIPT_DIR/Fix-OneDriveSync-macOS.sh"
BOOTSTRAP_TOOL="$SCRIPT_DIR/bootstrap_macos.sh"
HELP_GUIDE="$SCRIPT_DIR/MAC_TROUBLESHOOTER_GUIDE.md"
LOG_DIR="$HOME/Library/Logs/SuperiorNetworks"
MASTER_AUDIT_LOG="$LOG_DIR/master_audit_log.txt"

if [ ! -r "$UI_TOOL" ]; then
    printf 'Required terminal design component is missing: %s\n' "$UI_TOOL" >&2
    exit 1
fi
# shellcheck source=mac_terminal_ui.sh
. "$UI_TOOL"
sn_ui_initialize

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

show_menu() {
    sn_ui_show_brand "macOS Troubleshooter Terminal" "Toolkit v$TOOLKIT_VERSION | Guided repair and safe updates"
    sn_ui_show_optional_logo
    sn_ui_instruction_card "START HERE" \
        "Choose a task below. Every repair explains its impact before it makes a change." \
        "Use Help Guide for the workflow, safeguards, and log locations."

    sn_ui_section_label "TROUBLESHOOTING"
    sn_ui_menu_card "1" "OneDrive Sync Repair" "Dry-run previews only. Live repair closes, verifies, then reopens OneDrive."

    sn_ui_section_label "TOOLKIT MANAGEMENT"
    sn_ui_menu_card "2" "Check GitHub for Toolkit Updates" "On-demand only. Git history and local changes are protected."

    sn_ui_section_label "SUPPORT"
    sn_ui_menu_card "H" "Help Guide" "OneDrive workflow, update policy, logs, and recovery details."
    sn_ui_menu_card "Q" "Quit" "Close the macOS Troubleshooter Terminal."

    sn_ui_footer "$TOOLKIT_VERSION" "Select [ H ] in this terminal"
}

show_help_guide() {
    write_audit_log "INFO" "Menu Selection" "Help Guide opened"
    sn_ui_show_brand "Help Guide" "Toolkit v$TOOLKIT_VERSION | Everyday operating guidance"
    sn_ui_show_optional_logo

    sn_ui_section_label "ONE DRIVE REPAIR"
    sn_ui_instruction_card "SAFE, GUIDED WORKFLOW" \
        "Option 1 always runs a dry-run preview before it offers a live repair." \
        "Dry-run never closes or reopens OneDrive. Live repair closes, verifies, then reopens it." \
        "Type YES only after reviewing the preview and confirming recent work is synced."

    sn_ui_section_label "GITHUB UPDATES"
    sn_ui_instruction_card "YOU CONTROL WHEN UPDATES RUN" \
        "Option 2 checks GitHub only when you select it. The terminal never updates itself at startup." \
        "A Git fast-forward update keeps version history. Local uncommitted changes are never overwritten." \
        "You will see either NO CHANGES or the new version with its release notes."

    sn_ui_section_label "SUPPORT RECORDS"
    sn_ui_instruction_card "WHERE TO FIND DETAILS" \
        "Master audit log: ~/Library/Logs/SuperiorNetworks/master_audit_log.txt" \
        "Repair transcript: ~/Library/Logs/SuperiorNetworks/Fix-OneDriveSync-<timestamp>.log" \
        "Full guide: $HELP_GUIDE"

    sn_ui_footer "$TOOLKIT_VERSION" "$HELP_GUIDE"
    sn_ui_wait
}

run_onedrive_repair() {
    local status=0
    local approval=""

    write_audit_log "INFO" "Menu Selection" "Option 1: OneDrive Sync Repair"
    sn_ui_show_brand "OneDrive Sync Repair" "Toolkit v$TOOLKIT_VERSION | Post-update sync recovery"
    sn_ui_show_optional_logo
    sn_ui_status "warning" "Read this screen before running the repair."
    sn_ui_instruction_card "WHAT THIS REPAIR DOES" \
        "Dry-run reports the repair sequence only. It never closes or reopens OneDrive." \
        "Live repair closes OneDrive and its Sync Service first, verifies they are stopped," \
        "then reopens OneDrive. Each completed run opens its timestamped transcript in TextEdit."
    sn_ui_footer "$TOOLKIT_VERSION" "$HELP_GUIDE"

    if [ ! -f "$ONEDRIVE_TOOL" ]; then
        sn_ui_status "danger" "OneDrive repair script not found: $ONEDRIVE_TOOL"
        write_audit_log "ERROR" "OneDrive Sync Repair" "Required script not found: $ONEDRIVE_TOOL"
        sn_ui_wait
        return
    fi

    if [ ! -x "$ONEDRIVE_TOOL" ]; then
        sn_ui_status "action" "Preparing the OneDrive repair script for use..."
        if chmod +x "$ONEDRIVE_TOOL"; then
            write_audit_log "INFO" "OneDrive Sync Repair" "Set executable permission on Fix-OneDriveSync-macOS.sh"
        else
            sn_ui_status "danger" "Could not set executable permission on the OneDrive repair script."
            write_audit_log "ERROR" "OneDrive Sync Repair" "Could not set executable permission on $ONEDRIVE_TOOL"
            sn_ui_wait
            return
        fi
    fi

    sn_ui_step "1" "3" "Safety Preview"
    sn_ui_status "action" "Running a dry-run. It reports actions only; OneDrive stays open and unchanged."
    "$ONEDRIVE_TOOL" --dry-run
    status=$?
    if [ "$status" -ne 0 ]; then
        sn_ui_status "danger" "Dry run stopped with exit code $status. No repair was performed."
        write_audit_log "ERROR" "OneDrive Sync Repair" "Dry run exited with code $status"
        sn_ui_wait
        return
    fi

    sn_ui_step "2" "3" "Your Approval"
    sn_ui_instruction_card "PREVIEW COMPLETE - ACTION REQUIRED" \
        "Review the dry-run results above before choosing. The live repair will affect only" \
        "OneDrive processes, cached credentials, and backed-up preference files. It closes OneDrive" \
        "before the repair, verifies it stopped, then reopens OneDrive. Type YES to proceed."
    printf '\n%sType YES to run the live repair: %s' "$SN_UI_BOLD" "$SN_UI_RESET"
    read -r approval
    if [ "$approval" != "YES" ]; then
        sn_ui_status "success" "Live repair cancelled. The dry run made no changes."
        write_audit_log "INFO" "OneDrive Sync Repair" "Live repair cancelled after dry run"
        sn_ui_wait
        return
    fi

    write_audit_log "INFO" "OneDrive Sync Repair" "Live repair approved after dry run"
    sn_ui_step "3" "3" "Live Repair"
    sn_ui_status "action" "Closing and verifying OneDrive before repair; it will reopen when the repair completes."
    "$ONEDRIVE_TOOL"
    status=$?
    if [ "$status" -eq 0 ]; then
        sn_ui_instruction_card "REPAIR COMPLETE" \
            "OneDrive was reopened. Sign in to OneDrive with the work account when prompted." \
            "Keep the EXISTING OneDrive folder location. Do not select a new sync folder." \
            "The repair transcript opened automatically in TextEdit for the ticket record."
        sn_ui_status "success" "OneDrive repair completed successfully."
        write_audit_log "SUCCESS" "OneDrive Sync Repair" "Live repair completed successfully"
    else
        sn_ui_status "danger" "OneDrive repair exited with code $status. Review the transcript and audit log."
        write_audit_log "ERROR" "OneDrive Sync Repair" "Live repair exited with code $status"
    fi
    sn_ui_footer "$TOOLKIT_VERSION" "$HELP_GUIDE"
    sn_ui_wait
}

run_toolkit_update() {
    write_audit_log "INFO" "Menu Selection" "Option 2: Check GitHub for Toolkit Updates"
    sn_ui_show_brand "GitHub Toolkit Updates" "Toolkit v$TOOLKIT_VERSION | User-initiated Git version control"
    sn_ui_show_optional_logo
    sn_ui_instruction_card "WHAT HAPPENS NEXT" \
        "The updater checks GitHub only because you selected this option. It never updates at startup." \
        "If current, it reports NO CHANGES. If newer code exists, it uses a Git fast-forward update" \
        "and displays the newly installed version and its release notes."
    sn_ui_instruction_card "YOUR LOCAL WORK IS PROTECTED" \
        "Uncommitted local changes are never overwritten. The updater stops and shows Git status instead." \
        "Git history remains available in ~/ITTools/Scripts/.git for support and rollback diagnostics."
    sn_ui_footer "$TOOLKIT_VERSION" "$HELP_GUIDE"

    if [ ! -f "$BOOTSTRAP_TOOL" ]; then
        sn_ui_status "danger" "Git bootstrapper not found: $BOOTSTRAP_TOOL"
        write_audit_log "ERROR" "Toolkit Update" "Bootstrapper not found: $BOOTSTRAP_TOOL"
        sn_ui_wait
        return
    fi

    if [ ! -x "$BOOTSTRAP_TOOL" ] && ! chmod +x "$BOOTSTRAP_TOOL"; then
        sn_ui_status "danger" "Could not set executable permission on the Git bootstrapper."
        write_audit_log "ERROR" "Toolkit Update" "Could not set executable permission on $BOOTSTRAP_TOOL"
        sn_ui_wait
        return
    fi

    sn_ui_status "action" "Opening the Git update workflow..."
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
    printf '%sSelect an option [ 1 | 2 | H | Q ]: %s' "$SN_UI_BOLD" "$SN_UI_RESET"
    choice=""
    read -r choice || choice="Q"

    case "$choice" in
        1)
            run_onedrive_repair
            ;;
        2)
            run_toolkit_update
            ;;
        H|h)
            show_help_guide
            ;;
        Q|q)
            write_audit_log "INFO" "macOS Troubleshooter Terminal" "User selected Quit"
            sn_ui_status "success" "Exiting macOS Troubleshooter Terminal."
            exit 0
            ;;
        *)
            sn_ui_status "danger" "Invalid selection. Choose 1, 2, H, or Q."
            write_audit_log "WARN" "Invalid Menu Selection" "User entered: $choice"
            sleep 2
            ;;
    esac
done
