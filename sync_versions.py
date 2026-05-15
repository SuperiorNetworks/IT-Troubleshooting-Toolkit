"""
sync_versions.py
Updates all .ps1 script headers to use the single master toolkit version (3.7.12).
Removes individual script version numbers. Also adds changelog entry to README.
"""

import re
import os

NEW_VERSION = "3.7.12"
TODAY = "2026-05-15"

# Scripts whose header Version: field needs to be set to the master version
SCRIPTS = [
    "ftp_sync_tool.ps1",
    "ftp_sync_imagemanager.ps1",
    "ftp_troubleshooter_tool.ps1",
    "ftp_ps_checker.ps1",
    "storagecraft_troubleshooter.ps1",
    "diagnostic_imagemanager_db.ps1",
    "install_access_engine.ps1",
    "launch_menu.ps1",
]

def update_header_version(filepath, new_version):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # Replace the header Version: line (matches "Version: X.Y.Z" at start of line)
    updated = re.sub(r'^(Version:\s*)\d+\.\d+\.\d+', r'\g<1>' + new_version, content, count=1, flags=re.MULTILINE)

    if updated == content:
        print(f"  [SKIP] No Version: line found in {filepath}")
        return False

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(updated)
    print(f"  [OK]   {filepath} -> Version: {new_version}")
    return True

def update_install_access_engine_scriptversion(filepath, new_version):
    """install_access_engine.ps1 also has a $ScriptVersion variable that needs updating."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    updated = re.sub(r'\$ScriptVersion\s*=\s*"[\d\.]+"', '$ScriptVersion = "' + new_version + '"', content)
    if updated != content:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(updated)
        print(f"  [OK]   install_access_engine.ps1 $ScriptVersion -> {new_version}")

def add_ftp_sync_changelog_entry(filepath, new_version, today):
    """Add a v3.7.12 changelog entry to ftp_sync_tool.ps1 header."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    entry = (
        f"{today} v{new_version} - Unified versioning: removed individual script version\n"
        f"                    numbers across all toolkit scripts. All scripts now use\n"
        f"                    the single master toolkit version from launch_menu.ps1.\n"
    )
    # Insert before the first existing changelog entry line (starts with a date)
    updated = re.sub(r'(Change Log:\n)', r'\1' + entry, content, count=1)
    if updated != content:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(updated)
        print(f"  [OK]   Added v{new_version} changelog entry to {filepath}")

def update_readme(filepath, new_version, today):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    new_entry = f"""### Version {new_version} ({today}) - MAINTENANCE
- **Unified Versioning**: Removed all individual per-script version numbers. Every script in the toolkit now uses the single master toolkit version from `launch_menu.ps1`. One version number, one place to update.
- **Rule going forward**: Any change to any script = bump `launch_menu.ps1` version = all banners and headers update automatically.

"""
    # Insert after the "## Change Log" heading and before the first version entry
    updated = re.sub(r'(## Change Log\n\n)', r'\1' + new_entry, content, count=1)
    if updated != content:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(updated)
        print(f"  [OK]   README.md updated with v{new_version} entry")
    else:
        print(f"  [SKIP] Could not find insertion point in README.md")

print(f"\nSyncing all scripts to master version {NEW_VERSION}...\n")

for script in SCRIPTS:
    if os.path.exists(script):
        update_header_version(script, NEW_VERSION)
    else:
        print(f"  [MISS] {script} not found")

update_install_access_engine_scriptversion("install_access_engine.ps1", NEW_VERSION)
add_ftp_sync_changelog_entry("ftp_sync_tool.ps1", NEW_VERSION, TODAY)
update_readme("README.md", NEW_VERSION, TODAY)

print(f"\nDone. All scripts now report version {NEW_VERSION}.")
