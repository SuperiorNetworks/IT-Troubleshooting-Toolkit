# FTP Troubleshooter Tool

**Version:** 1.5.0  
**Copyright:** 2025

## Overview

The FTP Troubleshooter Tool is a PowerShell-based interactive file uploader designed for reliable manual file transfers to FTP servers. This utility provides a user-friendly GUI interface for selecting and uploading files with real-time progress tracking.

## Purpose

This tool serves as a reliable manual file transfer solution when automated systems experience issues or when ad-hoc file uploads are needed. It combines ease of use with robust error handling to ensure successful file transfers.

## Key Features

- **Interactive GUI File Picker**: Select single or multiple files using a familiar Windows dialog
- **Configurable Default FTP Server**: Pre-configured with a default server for quick access
- **Flexible Server Override**: Option to manually specify an alternative FTP server when needed
- **Secure Credential Handling**: Password input is masked and handled as a SecureString
- **Real-time Progress Tracking**: Visual progress bar shows upload status for each file
- **Robust Error Handling**: Comprehensive try-catch-finally blocks prevent resource leaks
- **Efficient Transfer**: 1MB buffer size optimized for large file transfers
- **Memory Security**: Automatic cleanup of plaintext credentials after use

## System Requirements

- **Operating System**: Windows 10/11 or Windows Server 2016+
- **PowerShell**: Version 5.1 or higher
- **.NET Framework**: 4.5 or higher (for System.Windows.Forms)
- **Network**: Access to the target FTP server
- **Permissions**: Ability to execute PowerShell scripts (see Setup section)

## Quick Start

### Option 1: Interactive Launcher Menu (Recommended)

Download and run the interactive launcher:

```powershell
# Download the launcher
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SuperiorNetworks/Ftp-Troubleshooter-Tool/master/launch_menu.ps1" -OutFile "$env:TEMP\launch_menu.ps1"

# Run the launcher
PowerShell.exe -ExecutionPolicy Bypass -File "$env:TEMP\launch_menu.ps1"
```

The launcher menu provides:
- **Option 1**: Download and install latest version to `C:\ITTools\FTPFIX`
- **Option 2**: Run the FTP troubleshooter tool
- **Option 3**: Start StorageCraft ImageManager service
- **Option 4**: Stop StorageCraft ImageManager service
- **Option 5**: Restart StorageCraft ImageManager service
- **Option 6**: Check ImageManager service status

### Option 2: One-Line Install and Run

Download, extract, and run in one command:

```powershell
# Create directory, download, extract, and run
$installPath = "C:\ITTools\FTPFIX"; New-Item -ItemType Directory -Path $installPath -Force | Out-Null; Invoke-WebRequest -Uri "https://github.com/SuperiorNetworks/Ftp-Troubleshooter-Tool/archive/refs/heads/master.zip" -OutFile "$env:TEMP\ftp-tool.zip"; Expand-Archive -Path "$env:TEMP\ftp-tool.zip" -DestinationPath "$env:TEMP\ftp-extract" -Force; Copy-Item -Path "$env:TEMP\ftp-extract\Ftp-Troubleshooter-Tool-master\*" -Destination $installPath -Recurse -Force; PowerShell.exe -ExecutionPolicy Bypass -File "$installPath\ftp_troubleshooter_tool.ps1"
```

### Option 3: Manual Installation

1. Download the repository as a ZIP file from GitHub
2. Extract to `C:\ITTools\FTPFIX` (or your preferred location)
3. Run `ftp_troubleshooter_tool.ps1`

## Installation

### Automated Installation via PowerShell

To download and install to the default location (`C:\ITTools\FTPFIX`):

```powershell
# Create installation directory
$installPath = "C:\ITTools\FTPFIX"
New-Item -ItemType Directory -Path $installPath -Force

# Download latest version
$zipUrl = "https://github.com/SuperiorNetworks/Ftp-Troubleshooter-Tool/archive/refs/heads/master.zip"
$zipFile = "$env:TEMP\ftp-troubleshooter.zip"
Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile

# Extract files
$extractPath = "$env:TEMP\ftp-troubleshooter-extract"
Expand-Archive -Path $zipFile -DestinationPath $extractPath -Force

# Copy to installation directory
Copy-Item -Path "$extractPath\Ftp-Troubleshooter-Tool-master\*" -Destination $installPath -Recurse -Force

Write-Host "Installation complete! Files are in: $installPath"
```

### Manual Installation

1. Download the `ftp_troubleshooter_tool.ps1` file from this repository
2. Save it to a convenient location (e.g., `C:\ITTools\FTPFIX` or your Desktop)
3. No additional installation required—the script is self-contained

## Setup

### First-Time PowerShell Script Execution

If you've never run PowerShell scripts before, you'll need to adjust the execution policy:

1. Open **PowerShell as Administrator**
2. Run the following command:
   ```powershell
   Set-ExecutionPolicy RemoteSigned
   ```
3. Type `Y` and press Enter to confirm

This setting allows you to run locally-created scripts while maintaining security for downloaded scripts.

## Configuration

### Setting Your Default FTP Server

Before first use, edit line 38 in the script to set your default FTP server:

```powershell
$defaultFtpServer = "ftp.sndayton.com"
```

Replace `ftp.sndayton.com` with your preferred FTP server address. This default can still be overridden at runtime.

## Usage

### Method 1: Right-Click Execution (Easiest)

1. Navigate to the script file in File Explorer
2. Right-click on `ftp_troubleshooter_tool.ps1`
3. Select **"Run with PowerShell"**

### Method 2: PowerShell Console (Recommended)

1. Open PowerShell (no admin rights needed)
2. Navigate to the script directory:
   ```powershell
   cd C:\ITTools\FTPFIX
   ```
3. Execute the script:
   ```powershell
   .\ftp_troubleshooter_tool.ps1
   ```

### Method 3: Direct Run from Installation Path

Run directly without changing directories:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File "C:\ITTools\FTPFIX\ftp_troubleshooter_tool.ps1"
```

### Method 4: Using the Interactive Launcher

If you installed using the launcher menu, run:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File "C:\ITTools\FTPFIX\launch_menu.ps1"
```

### Interactive Workflow

Once the script starts, follow these prompts:

1. **File Selection**: A GUI dialog appears—select one or more files to upload
2. **FTP Server**: Press Enter to use the default or type a new address
3. **Username**: Enter your FTP username
4. **Password**: Enter your FTP password (input will be hidden)
5. **Upload Progress**: Watch the progress bar as files upload
6. **Completion**: Review the summary message when all files are processed

## StorageCraft ImageManager Service Management

The launcher menu includes options to manage the StorageCraft ImageManager service. **Administrator privileges are required** for service management operations.

### Starting the Service

```powershell
# Start the service (requires Administrator)
Start-Service -Name "StorageCraft ImageManager"
```

### Stopping the Service

```powershell
# Stop the service (requires Administrator)
Stop-Service -Name "StorageCraft ImageManager" -Force
```

### Restarting the Service

```powershell
# Restart the service (requires Administrator)
Restart-Service -Name "StorageCraft ImageManager" -Force
```

### Checking Service Status

```powershell
# Check current status
Get-Service -Name "StorageCraft ImageManager" | Select-Object Name, Status, StartType
```

### Using the Launcher Menu

The interactive launcher menu (options 3-6) provides a user-friendly interface for service management:

1. Run the launcher as Administrator:
   ```powershell
   # Right-click PowerShell and select "Run as Administrator", then:
   PowerShell.exe -ExecutionPolicy Bypass -File "C:\ITTools\FTPFIX\launch_menu.ps1"
   ```

2. Select from the menu:
   - **Option 3**: Start the service
   - **Option 4**: Stop the service
   - **Option 5**: Restart the service
   - **Option 6**: View detailed service status

### Common Service Management Scenarios

**When to Restart the Service:**
- After configuration changes
- When the Image Manager becomes unresponsive
- Before using the FTP troubleshooter as a failover
- After system updates

**Troubleshooting Service Issues:**
- If service won't start, check Windows Event Viewer for errors
- Verify StorageCraft is properly installed
- Ensure no other backup software is conflicting
- Check that the service account has proper permissions

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **"Execution policy" error** | Run `Set-ExecutionPolicy RemoteSigned` as Administrator |
| **"File is not digitally signed" error** | Use the bypass method: `PowerShell.exe -ExecutionPolicy Bypass -File .\ftp_troubleshooter_tool.ps1` |
| **"No files selected" message** | The file dialog was cancelled—restart the script |
| **FTP connection timeout** | Verify network connectivity and FTP server address |
| **Authentication failure** | Double-check username and password credentials |
| **Upload fails mid-transfer** | Check available disk space and network stability |

### Error Messages

The script provides detailed error messages for each failed upload. Common errors include:

- **"Error uploading [file]: The remote server returned an error: (530) Not logged in."**  
  *Solution:* Verify your FTP credentials are correct

- **"Error uploading [file]: Unable to connect to the remote server"**  
  *Solution:* Check your network connection and firewall settings

- **"Error uploading [file]: The remote server returned an error: (550) File unavailable"**  
  *Solution:* Check FTP server permissions and available disk space

## Security Considerations

- **Password Handling**: While the script uses `SecureString` for initial input, it must convert to plaintext for the FTP connection. The password is cleared from memory after use.
- **Credential Storage**: This tool does NOT store credentials—you must enter them each time.
- **FTP Protocol**: Standard FTP transmits credentials in plaintext. Consider using SFTP or FTPS for sensitive environments.
- **Network Security**: Ensure your FTP server is properly secured with firewalls and access controls.

## Technical Details

### Dependencies

- `System.Windows.Forms`: Provides the GUI file picker dialog
- `System.Net.FtpWebRequest`: Handles FTP protocol communication
- `System.IO.File`: Manages file stream operations

### Transfer Specifications

- **Buffer Size**: 1,048,576 bytes (1 MB)
- **Transfer Mode**: Binary
- **Connection Mode**: Passive FTP
- **Keep-Alive**: Disabled (new connection per file)

## Use Cases

This tool is ideal for:

1. **Manual File Transfers**: When automated systems are unavailable
2. **Ad-hoc Uploads**: Quick one-time file transfers
3. **Backup Operations**: Secondary upload method for critical files
4. **Testing**: Verifying FTP connectivity and credentials
5. **Troubleshooting**: Isolating whether transfer issues are system-specific or network-related

## Contributing

Contributions, issues, and feature requests are welcome. Feel free to check the issues page if you want to contribute.

## License

Copyright © 2025. All rights reserved.

This software is provided as-is without warranty of any kind.

---

## Change Log

### Version 1.5.0 (2025-11-21)
- Fixed file overwrite behavior during installation
- Installation now properly overwrites existing files
- Launcher menu always displays first (no auto-run)

### Version 1.4.0 (2025-11-21)
- Updated installation path from C:\\sndayton\\ftpfix to C:\\ITTools\\FTPFIX
- Updated all documentation and scripts with new path

### Version 1.3.0 (2025-11-21)
- Added StorageCraft ImageManager service management to launcher menu
- Added options to start, stop, and restart ImageManager service
- Added service status checking functionality
- Added administrator privilege detection
- Updated documentation with service management commands and scenarios
- Enhanced launcher menu with service status display

### Version 1.2.0 (2025-11-21)
- Added interactive launcher menu script (launch_menu.ps1)
- Added Quick Start section with multiple installation options
- Added one-line install and run command
- Updated documentation with PowerShell commands for download, unzip, and run
- Standardized installation path to C:\\ITTools\\FTPFIX

### Version 1.1.0 (2025-11-21)
- Sanitized for public release
- Removed personally identifiable information
- Generalized documentation for broader use cases
- Improved security documentation

### Version 1.0.1 (2025-11-21)
- Fixed syntax error in error handling block (line 133)
- Improved error message formatting for better readability
- Updated variable reference handling in catch block

### Version 1.0.0 (2025-11-21)
- Initial release
- Interactive file picker with multi-select support
- Hard-coded default FTP server with override option
- Secure credential prompting
- Progress tracking for uploads
- Comprehensive error handling
- Memory cleanup for security
