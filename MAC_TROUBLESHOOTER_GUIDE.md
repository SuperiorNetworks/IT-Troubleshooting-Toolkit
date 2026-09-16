# macOS Troubleshooter Terminal

The **macOS Troubleshooter Terminal** is the macOS companion to the IT Troubleshooting Toolkit. It is designed to be run locally by the signed-in macOS user and currently includes a guided repair workflow for OneDrive synchronization failures after an operating-system update.

> **Safety model:** The OneDrive repair always runs a dry-run preview before the terminal offers the live repair. The live repair does not delete any content within a OneDrive sync folder. It backs up affected OneDrive preference files before removal and preserves a timestamped transcript for ticket records.

## Requirements

The terminal supports **macOS 12 or later** and uses the system-provided Bash 3.2 environment. It must be run by the signed-in user, not through `sudo`, because the affected OneDrive Keychain credentials and preference files are user-specific. OneDrive should be installed in `/Applications/OneDrive.app` for the relaunch step to work.

## Quick Start

Place both shell scripts in the same directory. For an installation cloned from this repository, open **Terminal** and run:

```bash
cd /path/to/IT-Troubleshooting-Toolkit
chmod +x mac_troubleshooter_terminal.sh Fix-OneDriveSync-macOS.sh
./mac_troubleshooter_terminal.sh
```

Choose **Option 1 - OneDrive Sync Repair**. The terminal will first execute the equivalent of:

```bash
./Fix-OneDriveSync-macOS.sh --dry-run
```

After reviewing the preview, type `YES` only if the reported actions are appropriate. The terminal will then run:

```bash
./Fix-OneDriveSync-macOS.sh
```

To use the repair script directly without the menu, use the same commands:

```bash
chmod +x Fix-OneDriveSync-macOS.sh
./Fix-OneDriveSync-macOS.sh --dry-run
./Fix-OneDriveSync-macOS.sh
```

## Menu Structure

```text
SUPERIOR NETWORKS LLC
macOS Troubleshooter Terminal - Toolkit v[master version]

Troubleshooting Tools:
  1. OneDrive Sync Repair (macOS post-update failures)
     Runs a dry-run preview first, then offers the safe repair.

Q. Quit
```

The terminal reads the master toolkit version from `launch_menu.ps1` when it is in the same directory. If it is deployed on a Mac without the PowerShell files, it attempts to read the current master version from the GitHub `master` branch. This preserves the toolkit's one-version convention across platforms.

## OneDrive Sync Repair Workflow

The repair tool executes the following stages and writes detailed on-screen information to its transcript log.

| Stage | Operation | Safeguard |
|---|---|---|
| 0. Pre-flight | Searches OneDrive folders for files modified in the prior 15 minutes | Requires typed `YES` if recent edits are found during a live repair |
| 1. Process stop | Quits OneDrive and Office integration processes, then only force-stops a process that will not close cleanly | Does not affect user OneDrive content |
| 2. Keychain cleanup | Removes stale OneDrive credentials by known Keychain labels | Applies only to the signed-in user's Keychain |
| 3. Preference repair | Backs up and removes the affected OneDrive sync plist files | Every targeted plist is copied to a timestamped Desktop backup folder before deletion |
| 4. Preference cache | Signals `cfprefsd` to ensure deleted settings are not restored from cache | Falls back to a restart advisory if macOS does not accept the signal |
| 5. Relaunch | Opens OneDrive and directs the user to sign in and retain the existing folder location | Can be skipped with `--no-relaunch` |

The terminal and repair script create two kinds of logs in `~/Library/Logs/SuperiorNetworks/`:

- `master_audit_log.txt` records terminal openings, menu selections, approvals, outcomes, and errors.
- `Fix-OneDriveSync-<timestamp>.log` records the full verbose repair transcript for the individual execution.

The backup directory is created only for a live repair at `~/Desktop/OneDrive-Plist-Backup-<timestamp>/`.

## Post-Repair Verification

After OneDrive starts, sign in with the user's work email address and **accept the existing OneDrive folder location**. Do not select a new sync folder. Approve any macOS file-access or system-extension prompt, then update OneDrive and Microsoft Office from the App Store if updates are available.

Verify two-way synchronization by creating `sync-test.txt` in the OneDrive folder, confirming that it appears at [Microsoft 365](https://www.office.com/), renaming it online, and confirming that the new name reaches the Mac. Delete the test file once both directions succeed.

## Troubleshooting

If the dry run exits with a nonzero code, the terminal will not offer the live repair. Review the on-screen error and `master_audit_log.txt`; typical causes are attempting to run the tool on a non-macOS host or with `sudo`.

If OneDrive is not installed at `/Applications/OneDrive.app`, the script completes its repair actions but reports that the app must be installed or opened manually. If OneDrive continues to have issues after this repair, preserve the transcript log and Desktop plist backup before taking additional reset actions.

## Files

- `mac_troubleshooter_terminal.sh` - Interactive macOS terminal menu.
- `Fix-OneDriveSync-macOS.sh` - OneDrive synchronization repair script.
- `MAC_TROUBLESHOOTER_GUIDE.md` - Deployment, workflow, and verification guide.
