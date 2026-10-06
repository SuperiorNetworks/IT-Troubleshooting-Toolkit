# IT Troubleshooting Toolkit: notes for Claude

Superior Networks' field toolkit: PowerShell menus for StorageCraft/ImageManager, FTP sync,
ConnectWise RMM/ScreenConnect, HP M404dn printers, plus Bash tools for macOS (OneDrive repair).
Repo: https://github.com/SuperiorNetworks/IT-Troubleshooting-Toolkit
Local clone: `~/projects/it-troubleshooting-toolkit` on sn-claude1026 (Linux; scripts can't run here,
so testing happens on a Windows or Mac box).

## `master` is production

Every client machine installs and updates from `master`, with no release step:

- `bootstrap.ps1` / `bootstrap_ps4.ps1` download `archive/refs/heads/master.zip` and compare the
  `Version:` in `master/launch_menu.ps1` against the installed copy in `C:\ITTools\Scripts`.
- `launch_menu.ps1` has its own "update" option, which also pulls `master.zip`.
- `bootstrap_macos.sh` defaults to `master` (it can be overridden with `SUPERIOR_NETWORKS_BRANCH`).
- The macOS scripts read the toolkit version from `master/launch_menu.ps1` on raw.githubusercontent.

So a push to `master` reaches every machine the next time someone runs the toolkit there.

Rules:
1. Do all work on the `dev` branch (or a feature branch off `dev`). Never commit straight to `master`.
2. Merge `dev` into `master` only after Dwain has tested the change on a real Windows box
   (and a Mac for the macOS scripts), and only when Dwain says to.
3. Never force-push `master`.

### Testing a branch on a Windows test box

Run in PowerShell as admin on the test machine. It overwrites `C:\ITTools\Scripts` with the branch,
so use a test box, not a production client server. The bootstraps read `SUPERIOR_NETWORKS_BRANCH`
(default `master`); a non-master branch shows a yellow TEST BRANCH line and always reinstalls.

```powershell
$env:SUPERIOR_NETWORKS_BRANCH='dev';[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;irm https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/dev/bootstrap_ps4.ps1|iex
```

Use `$env:` (lasts only for that window), never `setx`. Close the window when done.

Don't choose the launcher's "update" option during a branch test; it reinstalls from `master`.

On a Mac, run `bootstrap_macos.sh` with `SUPERIOR_NETWORKS_BRANCH=dev` set.

## Versioning (one toolkit version)

There is a single toolkit version. The source of truth is the `Version:` header line in
`launch_menu.ps1`. The other scripts, the bootstraps and the macOS tools read it from there.

Any change to any script bumps the toolkit version (semver: patch for fixes, minor for new
tools/features). The bootstraps only update a machine when `master` has a **higher** version,
so a change merged without a bump never reaches installed machines.

On each bump, update all of these:
- `launch_menu.ps1`: `Version:` header, the Change Log line, the `$scriptVersion = "x.y.z"`
  fallback in `Show-Menu`, and the `Write-AuditLog ... Launcher vx.y.z` line near the end.
- Every `.ps1` that was changed: `Version:` header and a Change Log line.
- `install_access_engine.ps1` also has `$ScriptVersion = "x.y.z"`.
- `README.md`: `**Version:**` at the top, the sample menu banners (`- v3.x.x` / `Toolkit v3.x.x`),
  and a new `### Version x.y.z (YYYY-MM-DD) - TITLE` entry at the top of `## Change Log`.
- New scripts the installer must ship: add them to the required-file check in the bootstraps
  (see commit 0d9356e).

Check for leftovers with `grep -rn "<old version>" --exclude-dir=.git .`


## Script header standard

Every script starts with the Superior Networks header (the source of truth is
https://github.com/SuperiorNetworks/snap-platform-standards; if it changes, that version wins).
In `.ps1` files it goes inside the `<# .SYNOPSIS / .DESCRIPTION ... #>` block, as in the existing
scripts. In `.sh` files it goes in `#` comments.

```
Name: script_name.ps1
Version: <current toolkit version>
Purpose: [What it does]
Author: Dwain Henderson Jr. | Superior Networks LLC
Contact: (937) 985-2480 | dhenderson@superiornetworks.biz
Copyright: 2026, Superior Networks LLC
Path: C:\ITTools\Scripts\script_name.ps1

What This Script Does:
  - [bullet list]

Input:
  - [config/data sources]

Output:
  - [what it produces, including audit/log file paths]

Dependencies:
  - [PowerShell version, modules, installed software]

Change Log:
YYYY-MM-DD vX.Y.Z - Description (Dwain Henderson Jr)
```

The existing scripts use `Path:` for the install location instead of the standard's `Location:`.
Keep `Path:` here for consistency.

## Coding conventions in this repo

- **PowerShell 4.0 compatible** (Server 2012 R2). Don't use `Expand-Archive`, `-AsHashtable`,
  ternaries, `??`, or other PS5+/PS7-only features in the toolkit scripts unless a script is
  explicitly PS5+. Set TLS 1.2 before web requests.
- **ASCII only in `.ps1` files**: no smart quotes, em dashes, or emoji. Check with
  `grep -nP '[^\x00-\x7F]' *.ps1`.
- Install path `C:\ITTools\Scripts`; logs go to `C:\ITTools\Scripts\Logs\`. Log user actions and
  errors to `master_audit_log.txt` with `Write-AuditLog`. macOS logs go to
  `~/Library/Logs/SuperiorNetworks/`.
- Repair actions that change state get a dry-run or confirmation prompt first (see the macOS
  OneDrive tool and the RMM repair).
- Keep the "SUPERIOR NETWORKS LLC" branding header on tool screens.
- Document new tools in README.md (feature list, menu section, Change Log).
