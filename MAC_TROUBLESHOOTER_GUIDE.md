# macOS Troubleshooter Terminal

**Current version:** v3.12.0
**Help Guide last updated:** 2026-09-16

The **macOS Troubleshooter Terminal** is the macOS companion to the IT Troubleshooting Toolkit. It is designed to be run locally by the signed-in macOS user and currently includes a guided repair workflow for OneDrive synchronization failures after an operating-system update. The terminal uses the Superior Networks visual language: clean neutral panels, high-contrast labels, prominent instruction cards, explicit status indicators, a visible version footer, and an in-terminal Help Guide.

> **Safety model:** The OneDrive repair always runs a dry-run preview before the terminal offers the live repair. The live repair does not delete any content within a OneDrive sync folder. It backs up affected OneDrive preference files before removal and preserves a timestamped transcript for ticket records.

## Requirements

The terminal supports **macOS 12 or later** and uses the system-provided Bash 3.2 environment. It must be run by the signed-in user, not through `sudo`, because the affected OneDrive Keychain credentials and preference files are user-specific. OneDrive should be installed in `/Applications/OneDrive.app` for the relaunch step to work.

The supported installation method requires **Git** and `curl`. macOS normally installs Git with the Apple Command Line Tools. If the installer reports that Git is unavailable, run `xcode-select --install`, finish the Apple prompt, then run the bootstrap command again.

## One-Command Git Installation

Run this in **Terminal** as the signed-in user:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/bootstrap_macos.sh)"
```

The bootstrapper clones the complete version-controlled repository to `~/ITTools/Scripts`, preserves its `.git` directory, confirms the installed master version, displays the applicable release notes, and launches the macOS terminal menu. It never uses PowerShell.

If a previous Git-managed installation is present, run the same command again. The bootstrapper checks `origin/master` and performs a **fast-forward-only** update. If the installed toolkit is already current, it explicitly reports that no changes were made. If it updates, it reports the newly installed version and prints that version's release notes. Local uncommitted changes are never overwritten; instead, the installer stops and displays the Git status.

## Quick Start

After the one-command installation, launch the terminal later with:

```bash
~/ITTools/Scripts/mac_troubleshooter_terminal.sh
```

Choose **Option 1 - OneDrive Sync Repair**. The terminal first executes the equivalent of:

```bash
./Fix-OneDriveSync-macOS.sh --dry-run
```

After reviewing the preview, type `YES` only if the reported actions are appropriate. The terminal then runs:

```bash
./Fix-OneDriveSync-macOS.sh
```

To use the repair script directly without the menu, run:

```bash
cd ~/ITTools/Scripts
chmod +x Fix-OneDriveSync-macOS.sh
./Fix-OneDriveSync-macOS.sh --dry-run
./Fix-OneDriveSync-macOS.sh
```

## Menu Structure

```text
SUPERIOR NETWORKS LLC
macOS Troubleshooter Terminal - Toolkit v[master version]

START HERE
  Choose a task below. Every repair explains its impact before it makes a change.

TROUBLESHOOTING
  [ 1 ]  OneDrive Sync Repair
         Dry-run preview first. No OneDrive folder data is deleted.

TOOLKIT MANAGEMENT
  [ 2 ]  Check GitHub for Toolkit Updates
         User-initiated only. Git history and local changes are protected.

SUPPORT
  [ H ]  Help Guide
         Workflow, safeguards, log locations, and operating limits.
  [ Q ]  Quit

Footer: Help Guide: Select [ H ] in this terminal | Superior Networks macOS Toolkit v[master version]
```

The terminal reads the master toolkit version from `launch_menu.ps1` when it is in the same directory. If it is deployed on a Mac without the PowerShell files, it attempts to read the current master version from the GitHub `master` branch. This preserves the toolkit's one-version convention across platforms.

## Git Version Control and Updates

The native macOS deployment is intentionally implemented in **Bash**, not PowerShell. Bash is already available on supported macOS versions, works directly with Git and the macOS user environment, and avoids adding a PowerShell dependency solely for the launcher. PowerShell can still be installed for cross-platform administrative scripts, but it is not required for the macOS troubleshooting terminal.

Use **Option 2 - Check GitHub for Toolkit Updates** only when an update is desired. The terminal invokes `bootstrap_macos.sh`, which fetches the `master` branch from GitHub and applies a Git `pull --ff-only` only when there is a newer commit. This design means the tool never silently changes itself during startup. It also retains standard Git history and enables diagnostics with:

```bash
cd ~/ITTools/Scripts
git status
git log --oneline -10
git remote -v
```

For a managed deployment, the bootstrapper supports environment overrides for `SUPERIOR_NETWORKS_INSTALL_DIR`, `SUPERIOR_NETWORKS_REPO_URL`, and `SUPERIOR_NETWORKS_BRANCH`. These are optional and should normally remain at their secure defaults.

## Interface and Built-In Help Guide

The terminal is designed for use on the macOS Terminal app, iTerm2, and comparable ANSI-capable terminals. The **Start Here** card identifies the safe path into the tool. Each action uses a concise card instead of a dense instruction paragraph: **What This Repair Does** explains scope, **Step 1 of 3** identifies the dry run, **Preview Complete - Action Required** identifies the technician approval point, and **Repair Complete** highlights the next operational steps.

Terminal status labels use clear language rather than decorative color alone: `[ NEXT ]` marks the next operation, `[ READ ]` marks an instruction that requires attention, `[ DONE ]` confirms a completed or safely cancelled action, and `[ STOP ]` identifies a blocked operation. The terminal remains usable with color disabled because every visual status has a text label.

Select **H** at any time from the main menu to open the in-terminal **Help Guide**. It summarizes the OneDrive repair, Git update policy, local-change protection, log locations, and the operating limit that OneDrive folder data is never deleted. The footer on each terminal screen displays both the current toolkit version and the Help Guide entry point.

The canonical Superior Networks logo is included locally at `assets/superior-networks-logo.png`. Standard macOS Terminal does not display inline images, so the terminal preserves an accessible text-based brand header. iTerm2 users with `imgcat` installed receive an optional inline-logo enhancement.

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

- `bootstrap_macos.sh` - One-command Git installer and user-initiated updater.
- `mac_terminal_ui.sh` - Shared Superior Networks terminal visual design system.
- `mac_troubleshooter_terminal.sh` - Interactive macOS terminal menu and built-in Help Guide.
- `Fix-OneDriveSync-macOS.sh` - OneDrive synchronization repair script.
- `MAC_TROUBLESHOOTER_GUIDE.md` - Deployment, update, workflow, and verification guide.
