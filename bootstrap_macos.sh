#!/bin/bash
# ==============================================================================
# Script Name : bootstrap_macos.sh
# Version     : Master toolkit version dynamically read from launch_menu.ps1
# Purpose     : Install or update the Superior Networks macOS Troubleshooter from
#               GitHub with Git version control, then launch its terminal menu.
# Author      : Dwain Henderson Jr., Superior Networks LLC
# Copyright   : (c) 2026 Superior Networks LLC. All rights reserved.
#
# Key Features:
#   - Clones the IT Troubleshooting Toolkit from GitHub into ~/ITTools/Scripts
#   - Retains the repository .git directory for status checks and safe updates
#   - Uses fast-forward-only Git updates and preserves local changes without
#     overwriting them
#   - Detects missing Apple Command Line Tools before any Git clone is attempted
#   - Shows whether no change was needed or which toolkit version was installed
#   - Displays the matching release notes whenever an update is installed
#   - Launches the native macOS Troubleshooter Terminal after install or update
#   - Writes verbose progress and outcomes to the macOS master audit log
#
# Inputs      : Optional environment variables for managed deployments
#                 SUPERIOR_NETWORKS_INSTALL_DIR  Installation directory override
#                 SUPERIOR_NETWORKS_REPO_URL     Repository URL override
#                 SUPERIOR_NETWORKS_BRANCH       Branch override
#                 SUPERIOR_NETWORKS_XCODE_SELECT_BIN  Test-only xcode-select override
# Outputs     : Console status output
#               Install: ~/ITTools/Scripts (default)
#               Audit  : ~/Library/Logs/SuperiorNetworks/master_audit_log.txt
# Dependencies: macOS 12 or later, bash 3.2+, Git, curl, and internet access.
#               Git is normally supplied by Xcode Command Line Tools.
# Notes       : Run as the signed-in macOS user, NOT with sudo. This tool does
#               not use PowerShell and does not remove an existing non-Git folder.
#
# Change Log:
#   2026-09-16 v3.16.0 - Detect missing Apple Command Line Tools before Git clone
#                        and provide guided installation/re-run instructions (Dwain Henderson Jr.)
# ==============================================================================

set -u

SCRIPT_NAME="bootstrap_macos.sh"
REPO_URL="${SUPERIOR_NETWORKS_REPO_URL:-https://github.com/SuperiorNetworks/IT-Troubleshooting-Toolkit.git}"
BRANCH="${SUPERIOR_NETWORKS_BRANCH:-master}"
INSTALL_DIR="${SUPERIOR_NETWORKS_INSTALL_DIR:-$HOME/ITTools/Scripts}"
XCODE_SELECT_BIN="${SUPERIOR_NETWORKS_XCODE_SELECT_BIN:-/usr/bin/xcode-select}"
LOG_DIR="$HOME/Library/Logs/SuperiorNetworks"
MASTER_AUDIT_LOG="$LOG_DIR/master_audit_log.txt"

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

fail() {
    printf '\nERROR: %s\n' "$1" >&2
    write_audit_log "ERROR" "macOS Git Bootstrap" "$1"
    exit 1
}

get_version_from_file() {
    local file_path="$1"
    local version

    version="$(awk '/^Version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+/ { print $2; exit }' "$file_path" 2>/dev/null)"
    if [ -n "$version" ]; then
        printf '%s\n' "$version"
    else
        printf '%s\n' "Unknown"
    fi
}

get_version_from_ref() {
    local git_ref="$1"
    local version

    version="$(git -C "$INSTALL_DIR" show "$git_ref:launch_menu.ps1" 2>/dev/null | awk '/^Version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+/ { print $2; exit }')"
    if [ -n "$version" ]; then
        printf '%s\n' "$version"
    else
        printf '%s\n' "Unknown"
    fi
}

show_release_notes() {
    local git_ref="$1"
    local version="$2"
    local notes

    notes="$(git -C "$INSTALL_DIR" show "$git_ref:README.md" 2>/dev/null | awk -v wanted="$version" '
        $0 ~ "^### Version " wanted " " { found=1; next }
        found && /^### Version / { exit }
        found && /^## / { exit }
        found { print }
    ')"

    if [ -n "$notes" ]; then
        printf '\nRelease notes for v%s:\n%s\n' "$version" "$notes"
    else
        printf '\nRelease notes for v%s are not available in README.md.\n' "$version"
    fi
}

ensure_git_is_available() {
    if [ ! -x "$XCODE_SELECT_BIN" ] || ! "$XCODE_SELECT_BIN" -p >/dev/null 2>&1; then
        printf '\n=== Apple Command Line Tools Required ===\n\n'
        printf 'macOS provides a Git launcher, but the Apple Command Line Tools are not installed yet.\n'
        printf 'The toolkit was NOT downloaded and no partial installation was created.\n\n'
        printf 'A macOS installation dialog will now open. Select Install, wait for it to finish,\n'
        printf 'then run this same bootstrap command again from Terminal.\n\n'

        if [ -x "$XCODE_SELECT_BIN" ] && "$XCODE_SELECT_BIN" --install >/dev/null 2>&1; then
            printf 'Apple Command Line Tools installation was requested.\n'
        else
            printf 'If no installation dialog appears, run this command manually:\n'
            printf '  xcode-select --install\n'
        fi

        write_audit_log "ERROR" "macOS Git Bootstrap" "Apple Command Line Tools are not installed; clone was intentionally skipped"
        exit 4
    fi

    if command -v git >/dev/null 2>&1 && git --version >/dev/null 2>&1; then
        return 0
    fi

    printf '\n=== Git Is Not Available ===\n\n'
    printf 'Apple Command Line Tools appear to be installed, but Git could not run.\n'
    printf 'Restart Terminal and run this command again. If the issue continues, run:\n'
    printf '  xcode-select --install\n'
    write_audit_log "ERROR" "macOS Git Bootstrap" "Command Line Tools were detected but Git could not run"
    exit 5
}

update_existing_installation() {
    local local_commit
    local remote_commit
    local local_version
    local remote_version

    if [ ! -d "$INSTALL_DIR/.git" ]; then
        fail "The existing installation folder is not a Git repository: $INSTALL_DIR. It was not modified."
    fi

    if [ -n "$(git -C "$INSTALL_DIR" status --porcelain)" ]; then
        printf '\nLocal changes were detected. No update was applied to protect them:\n'
        git -C "$INSTALL_DIR" status --short
        printf '\nCommit, stash, or discard those changes, then run this installer again.\n'
        write_audit_log "WARN" "macOS Git Bootstrap" "Update skipped because local Git changes were detected"
        return 0
    fi

    printf 'Checking GitHub for updates...\n'
    if ! GIT_TERMINAL_PROMPT=0 git -C "$INSTALL_DIR" fetch origin "$BRANCH"; then
        fail "Could not contact GitHub or fetch origin/$BRANCH. The existing installation was not changed."
    fi

    local_commit="$(git -C "$INSTALL_DIR" rev-parse HEAD)"
    remote_commit="$(git -C "$INSTALL_DIR" rev-parse "origin/$BRANCH")"
    local_version="$(get_version_from_file "$INSTALL_DIR/launch_menu.ps1")"
    remote_version="$(get_version_from_ref "origin/$BRANCH")"

    if [ "$local_commit" = "$remote_commit" ]; then
        printf '\nNo changes were made. Toolkit v%s is already the latest version.\n' "$local_version"
        write_audit_log "INFO" "macOS Git Bootstrap" "No update required; toolkit v$local_version is current"
        return 0
    fi

    printf '\nUpdate available: v%s -> v%s\n' "$local_version" "$remote_version"
    printf 'Downloading and installing the update...\n'
    if ! GIT_TERMINAL_PROMPT=0 git -C "$INSTALL_DIR" pull --ff-only origin "$BRANCH"; then
        fail "Git could not fast-forward the update. The existing version remains installed."
    fi

    chmod +x "$INSTALL_DIR/bootstrap_macos.sh" "$INSTALL_DIR/mac_troubleshooter_terminal.sh" "$INSTALL_DIR/Fix-OneDriveSync-macOS.sh" 2>/dev/null || true
    printf '\nUpdate complete. Toolkit v%s is now installed.\n' "$remote_version"
    show_release_notes "HEAD" "$remote_version"
    write_audit_log "SUCCESS" "macOS Git Bootstrap" "Updated toolkit from v$local_version to v$remote_version"
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

ensure_git_is_available
write_audit_log "INFO" "macOS Git Bootstrap" "Started; repository=$REPO_URL; branch=$BRANCH; install=$INSTALL_DIR"
printf '\n=== Superior Networks macOS Troubleshooter Installer ===\n\n'
printf 'Repository: %s\n' "$REPO_URL"
printf 'Install path: %s\n\n' "$INSTALL_DIR"

if [ ! -e "$INSTALL_DIR" ]; then
    mkdir -p "$(dirname "$INSTALL_DIR")" || fail "Could not create the installation parent directory."
    printf 'Downloading the toolkit from GitHub with Git version control...\n'
    if ! GIT_TERMINAL_PROMPT=0 git clone --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"; then
        fail "Git clone failed. No partial installation was used."
    fi

    chmod +x "$INSTALL_DIR/bootstrap_macos.sh" "$INSTALL_DIR/mac_troubleshooter_terminal.sh" "$INSTALL_DIR/Fix-OneDriveSync-macOS.sh" 2>/dev/null || true
    installed_version="$(get_version_from_file "$INSTALL_DIR/launch_menu.ps1")"
    printf '\nInstallation complete. Toolkit v%s is installed and managed by Git.\n' "$installed_version"
    show_release_notes "HEAD" "$installed_version"
    write_audit_log "SUCCESS" "macOS Git Bootstrap" "Initial installation completed; toolkit v$installed_version"
else
    update_existing_installation
fi

if [ ! -x "$INSTALL_DIR/mac_troubleshooter_terminal.sh" ]; then
    fail "The macOS terminal menu is missing or not executable: $INSTALL_DIR/mac_troubleshooter_terminal.sh"
fi

printf '\nLaunching the macOS Troubleshooter Terminal...\n'
write_audit_log "INFO" "macOS Git Bootstrap" "Launching macOS Troubleshooter Terminal"
exec "$INSTALL_DIR/mac_troubleshooter_terminal.sh"
