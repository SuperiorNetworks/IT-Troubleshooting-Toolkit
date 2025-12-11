# Bootstrap Installation Guide

This guide explains how to install the IT Troubleshooting Toolkit using the appropriate bootstrap script for your PowerShell version.

---

## Quick Start: Check Your PowerShell Version

Before choosing which bootstrap to use, check your PowerShell version:

```powershell
$PSVersionTable.PSVersion
```

**Example output:**
```
Major  Minor  Build  Revision
-----  -----  -----  --------
5      1      14393  5127
```

The **Major** number is your PowerShell version (e.g., 5 = PowerShell 5.x).

---

## Which Bootstrap Should I Use?

### PowerShell 5.0 or Higher (Recommended)

**Systems:**
- Windows 10
- Windows 11
- Windows Server 2016 or newer
- Windows 7/8.1/Server 2012 R2 with WMF 5.1 installed

**Use:** `bootstrap.ps1` (standard version)

**Command:**
```powershell
PowerShell.exe -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/bootstrap.ps1 | iex"
```

---

### PowerShell 4.0 or 4.5

**Systems:**
- Windows Server 2012 R2 (default)
- Windows 8.1 (default)
- Windows 7 with PowerShell 4.0 installed

**Use:** `bootstrap_ps4.ps1` (PowerShell 4.0+ compatible)

**Command:**
```powershell
PowerShell.exe -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/bootstrap_ps4.ps1 | iex"
```

**Note:** The TLS 1.2 setting is included in the command because older systems default to TLS 1.0, which GitHub doesn't support.

---

### PowerShell 3.0 or Earlier

**Systems:**
- Windows Server 2012 (default)
- Windows 7 (default)
- Windows 8 (default)

**Recommendation:** Upgrade to PowerShell 4.0 or higher, then use `bootstrap_ps4.ps1`.

**Alternative:** Manual installation (see below).

---

## Detailed Installation Instructions

### Option 1: One-Command Installation (Recommended)

**For PowerShell 5.0+:**
```powershell
PowerShell.exe -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/bootstrap.ps1 | iex"
```

**For PowerShell 4.0-4.5:**
```powershell
PowerShell.exe -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/bootstrap_ps4.ps1 | iex"
```

---

### Option 2: Download and Run Bootstrap

**Step 1:** Download the appropriate bootstrap script

**For PowerShell 5.0+:**
- URL: https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/bootstrap.ps1
- Save as: `bootstrap.ps1`

**For PowerShell 4.0-4.5:**
- URL: https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/bootstrap_ps4.ps1
- Save as: `bootstrap_ps4.ps1`

**Step 2:** Run the downloaded script

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File bootstrap.ps1
```

or

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File bootstrap_ps4.ps1
```

---

### Option 3: Manual Installation

If bootstrap scripts don't work, install manually:

**Step 1:** Download the toolkit ZIP

- Go to: https://github.com/SuperiorNetworks/IT-Troubleshooting-Toolkit
- Click the green "Code" button
- Click "Download ZIP"
- Save as: `IT-Troubleshooting-Toolkit-master.zip`

**Step 2:** Extract the ZIP

- Right-click the ZIP file
- Select "Extract All..."
- Extract to a temporary location

**Step 3:** Copy to installation directory

- Create folder: `C:\ITTools\`
- Copy the extracted folder to: `C:\ITTools\`
- Rename from `IT-Troubleshooting-Toolkit-master` to `Scripts`
- Final path: `C:\ITTools\Scripts\`

**Step 4:** Run the toolkit

```powershell
cd C:\ITTools\Scripts
.\launch_menu.ps1
```

---

## Troubleshooting

### Error: "Could not create SSL/TLS secure channel"

**Cause:** System is using TLS 1.0, but GitHub requires TLS 1.2.

**Solution:** Add TLS 1.2 to the command:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/bootstrap_ps4.ps1 | iex
```

---

### Error: "Expand-Archive is not recognized"

**Cause:** PowerShell 4.0 or earlier doesn't have the `Expand-Archive` cmdlet.

**Solution:** Use `bootstrap_ps4.ps1` instead of `bootstrap.ps1`.

---

### Error: "Cannot find path"

**Cause:** Files weren't extracted to the correct location.

**Solution:** 
1. Check if files exist: `Test-Path "C:\ITTools\Scripts\launch_menu.ps1"`
2. If False, manually extract and copy files to `C:\ITTools\Scripts\`

---

## PowerShell Version Reference

| Windows Version | Default PS Version | Recommended Bootstrap |
|---|---|---|
| Windows 11 | 5.1 | `bootstrap.ps1` |
| Windows 10 | 5.1 | `bootstrap.ps1` |
| Windows Server 2019/2022 | 5.1 | `bootstrap.ps1` |
| Windows Server 2016 | 5.1 | `bootstrap.ps1` |
| Windows 8.1 | 4.0 | `bootstrap_ps4.ps1` |
| Windows Server 2012 R2 | 4.0 | `bootstrap_ps4.ps1` |
| Windows 7 SP1 | 2.0 | Upgrade to PS 4.0+ |
| Windows Server 2012 | 3.0 | Upgrade to PS 4.0+ |
| Windows Server 2008 R2 | 2.0 | Upgrade to PS 4.0+ |

---

## Upgrading PowerShell

If you're on PowerShell 3.0 or earlier, consider upgrading to get the best experience.

### Install Windows Management Framework 5.1

**Download:** https://www.microsoft.com/en-us/download/details.aspx?id=54616

**Compatible with:**
- Windows 7 SP1
- Windows 8.1
- Windows Server 2008 R2 SP1
- Windows Server 2012
- Windows Server 2012 R2

**Prerequisites:**
- .NET Framework 4.5.2 or higher

**After installation:**
- Restart the computer
- Verify: `$PSVersionTable.PSVersion`
- Use `bootstrap.ps1` (standard version)

---

## Quick Reference Commands

### Check PowerShell Version
```powershell
$PSVersionTable.PSVersion
```

### Check .NET Framework Version
```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' | Select-Object -ExpandProperty Release
```

**Release numbers:**
- 378389 = .NET 4.5
- 378675 = .NET 4.5.1
- 379893 = .NET 4.5.2
- 393295 = .NET 4.6
- 394254 = .NET 4.6.1
- 394802 = .NET 4.6.2
- 460798 = .NET 4.7
- 461308 = .NET 4.7.1
- 461808 = .NET 4.7.2
- 528040 = .NET 4.8

### Enable TLS 1.2 (Temporary)
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

### Enable TLS 1.2 (Permanent - Requires Admin)
```powershell
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value 1
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value 1
```

Then restart PowerShell.

---

## Support

If you encounter issues not covered in this guide, please visit:
https://github.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/issues

---

**Last Updated:** December 2025  
**Toolkit Version:** 3.1.0+
