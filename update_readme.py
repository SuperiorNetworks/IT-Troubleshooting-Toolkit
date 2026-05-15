import re

with open('README.md', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update the Support link
content = content.replace('**Website:** https://help.manus.im', '**Website:** https://github.com/SuperiorNetworks/IT-Troubleshooting-Toolkit')

# 2. Update the main version at the top
content = re.sub(r'\*\*Version:\*\* 3\.7\.10', '**Version:** 3.7.11', content)

# 3. Update the menu version display in the README
content = re.sub(r'IT Troubleshooting Toolkit - v3\.7\.10', 'IT Troubleshooting Toolkit - v3.7.11', content)

# 4. Build the new changelog section
new_changelog = """## Change Log

### Version 3.7.11 (2026-05-15) ⭐ NEW
- **Dynamic Version Banners**: All scripts now dynamically read the master toolkit version from `launch_menu.ps1` at runtime.
- **Unified Branding**: Added "SUPERIOR NETWORKS LLC" branding to all tool headers.
- **Simplified Updates**: Bumping the master version in `launch_menu.ps1` now automatically updates the version displayed across the entire toolkit.

### Version 3.7.10 (2026-05-15) 🐛 BUG FIXES
- **Large File Transfer Fix**: Replaced invalid `option keepuptodate` with correct WinSCP `-rawsettings FtpPingType=1 FtpPingInterval=10` to prevent script breakage while maintaining NAT state.
- **StorageCraft File Filter**: Updated `ftp_sync_tool.ps1` to only sync base images (`*.spf`) and daily consolidated images (`*-cd*.spi`). Excludes raw intra-daily incrementals and weekly/monthly/rolling consolidations.
- **Pre-upload Existence Check**: Added check to skip files not found on local disk instead of wasting retries.
- **Manual File List Upload**: Added option to paste a list of filenames to upload manually inside the FTP Sync Tool.
- **Per-module Version Checking**: Updater now checks each individual script's version against GitHub.
- **ASCII Compliance**: Purged all non-ASCII characters from all `.ps1` files to ensure strict PowerShell 4.0 / Server 2012 R2 compatibility.
- **ACE Provider Detection**: Fixed architecture detection in `install_access_engine.ps1` to use `Is64BitProcess` instead of `Is64BitOperatingSystem`.
- **FTP PS Checker**: Added pure PowerShell FTP connectivity tester (`ftp_ps_checker.ps1`) that doesn't require WinSCP.
- **DoH Fallback**: Added MAS Activation DoH Fallback (Option 4B) in `launch_menu.ps1`.

### Version 3.7.9 (2026-05-15)
- **Large File Verification Fix**: Replaced `Test-FtpFileExists` with `Test-FtpFileSizeMatch` in `ftp_sync_tool.ps1`.
- **Stall Recovery**: When a large file transfer stalls due to control channel timeout, the script now opens a fresh session and compares the remote file size against the local file size. If they match exactly, the transfer is marked as successful (`STALL-BUT-COMPLETE`) instead of deleting the file and restarting the upload.

### Version 3.7.8 (2026-04-15)"""

# Replace the old changelog start with the new one
content = re.sub(r'## Change Log\s+### Version 3\.7\.4 \(2026-04-14\) ⭐ NEW \+ BUG FIXES', new_changelog.replace('### Version 3.7.8 (2026-04-15)', '### Version 3.7.4 (2026-04-14) ⭐ NEW + BUG FIXES'), content)

# Remove the duplicate 3.7.8 entry at the bottom if it exists
content = re.sub(r'### Version 3\.7\.8 \(2026-04-15\).*?### Version 2\.8\.0', '### Version 2.8.0', content, flags=re.DOTALL)

with open('README.md', 'w', encoding='utf-8') as f:
    f.write(content)

print("README.md updated successfully.")
