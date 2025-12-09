# IT Troubleshooting Toolkit Launcher

![Superior Networks Logo](logo.png)

**Version:** 3.0.2
**Copyright:** 2025  
**Developed by:** Superior Networks LLC

## Overview

The IT Troubleshooting Toolkit Launcher is a comprehensive PowerShell-based menu system that provides quick access to essential troubleshooting tools and utilities. Designed for IT professionals and MSPs, this launcher centralizes common troubleshooting tasks into a single, easy-to-use interface.

## Available Tools

The launcher provides access to the following tools:

### 1. Manual FTP Tool
Interactive file uploader with GUI file picker for manual FTP transfers. Ideal for backup operations when automated systems fail.

**Features:**
- GUI-based file selection (single or multiple files)
- Configurable FTP server with override option
- Secure credential handling
- Real-time progress tracking
- 1MB buffer for efficient large file transfers

### 2. StorageCraft ImageManager Service Management
Complete service control for StorageCraft ImageManager backup service.

**Features:**
- Start/Stop/Restart service operations
- Real-time service status monitoring
- Detailed service information display
- Administrator privilege detection
- **MassGrave Activation Scripts (MAS)**: Windows and Office activation utility

### 3. MassGrave Activation Scripts (MAS)
Open-source Windows and Office activation utility featuring multiple activation methods.

**Features:**
- HWID (Digital License) for permanent Windows 10-11 activation
- Ohook for permanent Office activation
- TSforge for Windows/ESU/Office activation
- Online KMS activation (180 days, renewable with task)
- Advanced activation troubleshooting
- Fully open source and based on batch scripts
- Source: [https://massgrave.dev/](https://massgrave.dev/)

## Purpose

This toolkit launcher serves as a centralized troubleshooting hub for IT professionals, providing:

- **Quick Access**: Launch multiple troubleshooting tools from a single menu
- **Service Management**: Control critical backup and system services
- **Failover Solutions**: Manual tools when automated systems fail
- **Ease of Use**: User-friendly menu interface with clear options
- **Self-Updating**: Download and install latest versions automatically

## Launcher Menu Features

- **Self-Contained Installation**: Automatic download and installation from GitHub
- **File Overwrite Protection**: Safely updates existing installations
- **Interactive Menu System**: Easy-to-navigate options with color-coded display
- **Real-Time Status**: Shows current service status in menu
- **Administrator Detection**: Automatically detects privilege level for service operations
- **Tool Integration**: Seamlessly launches individual troubleshooting tools
- **Persistent Menu**: Returns to menu after each operation for quick access

## System Requirements

- **Operating System**: Windows 10/11 or Windows Server 2016+
- **PowerShell**: Version 5.1 or higher
- **.NET Framework**: 4.5 or higher (for System.Windows.Forms)
- **Network**: Access to the target FTP server
- **Permissions**: Ability to execute PowerShell scripts (see Setup section)

## Quick Start

### Option 1: Launch the Toolkit Menu (Recommended)

Download and run the interactive launcher menu:

```powershell
# Download the launcher
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/launch_menu.ps1" -OutFile "$env:TEMP\launch_menu.ps1"

# Run the launcher menu
PowerShell.exe -ExecutionPolicy Bypass -File "$env:TEMP\launch_menu.ps1"
```

**The launcher menu provides access to:**

**Toolkit Management:**
- **Option 1**: Download and install latest toolkit version to `C:\ITTools\Scripts`

**Troubleshooting Tools:**
- **Option 2**: FTP Troubleshooter Tool (manual file upload)

**Service Management:**
- **Option 3**: Start StorageCraft ImageManager service
- **Option 4**: Stop StorageCraft ImageManager service
- **Option 5**: Restart StorageCraft ImageManager service
- **Option 6**: Check ImageManager service status

### Option 2: One-Line Install and Launch

Download, install, and launch the toolkit menu in one command:

```powershell
# Create directory, download, extract, and launch menu
$installPath = "C:\ITTools\Scripts"; New-Item -ItemType Directory -Path $installPath -Force | Out-Null; Invoke-WebRequest**URL:** https://github.com/SuperiorNetworks/IT-Troubleshooting-Toolkitt/archive/refs/heads/master.zip" -OutFile "$env:TEMP\ftp-tool.zip"; Expand-Archive -Path "$env:TEMP\ftp-tool.zip" -DestinationPath "$env:TEMP\ftp-extract" -Force; Copy-Item -Path "$env:TEMP\ftp-extract\IT-Troubleshooting-Toolkit-master\*" -Destination $installPath -Recurse -Force; PowerShell.exe -ExecutionPolicy Bypass -File "$installPath\launch_menu.ps1"
```

### Option 3: Manual Installation

1. Download the repository as a ZIP file from GitHub
2. Extract to `C:\ITTools\Scripts` (or your preferred location)
3. Run `launch_menu.ps1` to access the toolkit menu

## Installation

### Automated Installation via PowerShell

To download and install to the default location (`C:\ITTools\Scripts`):

```powershell
# Create installation directory
$installPath = "C:\ITTools\Scripts"
New-Item -ItemType Directory -Path $installPath -Force

# Download latest version
$zipUrl = "https://github.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/archive/refs/heads/master.zip"
$zipFile = "$env:TEMP\ftp-troubleshooter.zip"
Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile

# Extract files
$extractPath = "$env:TEMP\ftp-troubleshooter-extract"
Expand-Archive -Path $zipFile -DestinationPath $extractPath -Force

# Copy to installation directory
Copy-Item -Path "$extractPath\IT-Troubleshooting-Toolkit-master\*" -Destination $installPath -Recurse -Force

Write-Host "Installation complete! Files are in: $installPath"
```

### Manual Installation

1. Download the `ftp_troubleshooter_tool.ps1` file from this repository
2. Save it to a convenient location (e.g., `C:\ITTools\Scripts` or your Desktop)
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
2. Right-click on `launch_menu.ps1`
3. Select **"Run with PowerShell"**
4. The toolkit menu will appear with all available options

### Method 2: PowerShell Console (Recommended)

1. Open PowerShell (no admin rights needed for most options)
2. Navigate to the toolkit directory:
   ```powershell
   cd C:\ITTools\Scripts
   ```
3. Launch the toolkit menu:
   ```powershell
   .\launch_menu.ps1
   ```

### Method 3: Direct Launch from Any Location

Launch the toolkit menu directly without changing directories:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File "C:\ITTools\Scripts\launch_menu.ps1"
```

### Method 4: Launch as Administrator (For Service Management)

To access service management options, run as Administrator:

```powershell
# Right-click PowerShell and select "Run as Administrator", then:
PowerShell.exe -ExecutionPolicy Bypass -File "C:\ITTools\Scripts\launch_menu.ps1"
```

### Toolkit Menu Workflow

Once the launcher menu starts:

1. **View Available Options**: The menu displays all available tools and services
2. **Check Service Status**: Current ImageManager service status is shown (if installed)
3. **Select an Option**: Enter the number (1-6) or Q to quit
4. **Tool Execution**: Selected tool or service operation runs
5. **Return to Menu**: After completion, menu redisplays for next action

### Using the FTP Troubleshooter (Option 2)

When you select Option 2 from the menu:

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
   PowerShell.exe -ExecutionPolicy Bypass -File "C:\ITTools\Scripts\launch_menu.ps1"
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

This toolkit launcher is ideal for:

1. **IT Troubleshooting**: Quick access to multiple diagnostic and repair tools
2. **Backup Failover**: Manual file transfers when automated backup systems fail
3. **Service Management**: Restart unresponsive backup services without navigating Windows Services
4. **MSP Operations**: Standardized toolkit for technicians across multiple client sites
5. **Emergency Response**: Fast deployment and execution during system issues
6. **Training**: Easy-to-use interface for junior technicians

## Contributing

Contributions, issues, and feature requests are welcome. Feel free to check the issues page if you want to contribute.

## License

Copyright © 2025. All rights reserved.

This software is provided as-is without warranty of any kind.

---

## Change Log

### Version 3.0.2 (2025-12-08)
- **Version Bump**: Maintenance release
  - No functional changes
  - Version increment for deployment tracking

### Version 3.0.1 (2025-12-08)
- **Bug Fix**: Fixed WinSCP download and extraction error
  - Changed download URL to GitHub releases (more reliable)
  - Updated to WinSCP 6.3.5 (latest stable)
  - Replaced `Expand-Archive` with .NET `ZipFile.ExtractToDirectory` for better compatibility
  - Changed download method from `WebClient` to `Invoke-WebRequest` for reliability
  - Fixed "End of Central Directory record" extraction error
  - Better error messages with manual download instructions

### Version 3.0.0 (2025-12-08)
- **Major Rewrite: FTP Sync now uses WinSCP**: Professional-grade FTP synchronization
  - Completely rewrote FTP Sync tool to use WinSCP open-source FTP client
  - Eliminates all PowerShell parsing issues with custom FTP code
  - Automatic WinSCP portable download on first run (no installation needed)
  - Pre-configured for ftp.sndayton.com
  - WinSCP handles all FTP operations (listing, comparison, upload)
  - Much more reliable and battle-tested than custom code
  - Professional features: resume support, error handling, logging
- **Features**:
  - Auto-downloads WinSCP 5.21.7 Portable (only once)
  - Installs to C:\ITTools\WinSCP
  - Uses WinSCP scripting interface for automation
  - Comprehensive WinSCP logging to C:\ITTools\Scripts\Logs\winscp.log
  - Still filters for *-cd.spi files
  - Shows detailed sync report
  - Bulk upload with WinSCP engine
- **Why WinSCP**:
  - Open-source, trusted by millions
  - Handles all FTP edge cases and errors
  - No PowerShell string parsing issues
  - Professional-grade reliability
  - Active development and support

### Version 2.9.3 (2025-12-08)
- **Bug Fix**: FTP Sync syntax error fix (third attempt - using string concatenation)
  - Format operator still caused parser errors in PowerShell 5.1
  - Changed to simple string concatenation with intermediate variable
  - `$summaryText = "Total: " + $count + " files (" + $totalGB + " GB)"`
  - Then: `Write-Host $summaryText -ForegroundColor Cyan`
  - This completely avoids all string interpolation and format operator issues
  - Most reliable approach that works in all PowerShell versions
  - No complex parsing - just basic string concatenation

### Version 2.9.2 (2025-12-08)
- **Bug Fix**: Corrected FTP Sync syntax error fix (second attempt)
  - Previous fix using `${totalGB}` still caused parser errors in PowerShell 5.1
  - Changed to use format operator: `("{0} files ({1} GB)" -f $count, $totalGB)`
  - Format operator avoids string interpolation issues entirely
  - FTP Sync tool now loads correctly without parser errors
  - More reliable cross-version PowerShell compatibility

### Version 2.9.1 (2025-12-08)
- **Bug Fix**: Fixed PowerShell syntax error in FTP Sync tool
  - Corrected string interpolation issue on line 291
  - Changed `($totalGB GB)` to `(${totalGB} GB)` to prevent parser error
  - FTP Sync tool now loads and runs correctly
- **New Feature: Toolkit Logs Menu**: Added log viewer submenu to main launcher
  - New option #2 under "Toolkit Management" section
  - Opens dedicated submenu for viewing all toolkit logs
  - Renumbered existing menu options (StorageCraft now #3, MAS now #4)
- **Log Viewer Features**:
  - View Master Audit Log in Notepad
  - View FTP Upload Log in Notepad
  - View FTP Sync Log in Notepad
  - Shows log file size and last modified date
  - Handles missing log files gracefully
  - Returns to submenu after viewing

### Version 2.9.0 (2025-12-08)
- **New Feature: FTP Sync Tool**: Compare local backup files with FTP destination
  - Scans local directory for StorageCraft backup files ending in `-cd.spi`
  - Connects to FTP server and retrieves file listing
  - Compares files by name and size to identify sync status
  - Shows files on source (local) but not on destination (FTP)
  - Displays detailed report with file names, sizes, and dates
  - Allows bulk upload of missing files
  - Export report option for documentation
  - Comprehensive logging to `ftp_sync_log.txt`
- **Menu Enhancement**: Added FTP Sync to StorageCraft Troubleshooter submenu
  - New option #2 under "Manual Tools" section
  - Renumbered existing menu options for consistency
  - Updated StorageCraft Troubleshooter to v1.2.0
- **Use Case**: Identify which backup files need to be uploaded to FTP for replication
  - Perfect for monitoring backup sync status
  - Quick identification of missing incremental backups
  - Streamlines manual backup replication workflows

### Version 2.8.0 (2025-12-08)
- **Bootstrap Installer**: Smart one-command installer and launcher
  - Automatically installs toolkit if not present
  - Checks for updates and auto-updates if available
  - Launches toolkit from correct location (`C:\ITTools\Scripts`)
  - Can be run from anywhere - handles everything automatically
  - Perfect for technicians - single command to run
  - Can be bookmarked or added to shortcuts
- **Usage Options**:
  - **Option 1**: Direct from GitHub (no download needed):
    ```powershell
    PowerShell.exe -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/bootstrap.ps1 | iex"
    ```
  - **Option 2**: Download bootstrap.ps1 and run:
    ```powershell
    PowerShell.exe -ExecutionPolicy Bypass -File bootstrap.ps1
    ```
  - **Option 3**: Use launcher.bat (after installation):
    - Located at: `C:\ITTools\Scripts\launcher.bat`
- **Smart Features**:
  - Version detection and comparison
  - Automatic installation to `C:\ITTools\Scripts`
  - Update checking against GitHub
  - Clean error handling and user feedback
  - Professional installation experience

### Version 2.7.2 (2025-12-08)
- **Added launcher.bat**: Proper toolkit launcher included in repository
  - Ensures toolkit always runs from `C:\ITTools\Scripts`
  - Prevents running from wrong location (e.g., TEMP folder)
  - Automatically installed with toolkit
  - Error handling if toolkit not found
  - Professional launch experience
- **Usage**: Double-click `launcher.bat` to start the toolkit
  - Located at: `C:\ITTools\Scripts\launcher.bat`
  - Can create desktop shortcut to this file
  - Always runs the correct installed version

### Version 2.7.1 (2025-12-08)
- **Dynamic Version Display**: Version now reads dynamically from script header
  - No more hardcoded version strings
  - Menu always shows correct version
  - Prevents version display mismatches
  - Automatically updates when script updates
- **Bug Fix**: Fixed version display showing old version after update
  - Menu now reflects actual installed version
  - Reads version from `Version:` field in script header
  - Single source of truth for version number

### Version 2.7.0 (2025-12-08)
- **Proper Self-Update Mechanism**: Fixed file replacement during updates
  - Implements staged update with batch file
  - Avoids Windows file locking issues
  - PowerShell exits, batch file copies new files, then restarts toolkit
  - Industry-standard approach for self-updating applications
- **Automatic Restart**: Toolkit automatically restarts after update
  - No manual intervention needed
  - Seamless update experience
  - Shows "Applying Update" progress screen
- **Update Flow**:
  1. Downloads new version to temp
  2. Stages files in temporary location
  3. Creates update batch script
  4. Exits PowerShell (releases file locks)
  5. Batch script copies staged files
  6. Batch script restarts toolkit with new version
  7. Self-cleans batch file

### Version 2.6.1 (2025-12-08)
- **Testing Version**: Verify changelog display functionality
  - Same features as v2.6.0
  - Allows testing update from v2.6.0 → v2.6.1
  - Confirms changelog extraction and display works correctly
  - User can verify color-coded formatting

### Version 2.6.0 (2025-12-08)
- **Fixed Changelog Display**: Changelog now displays properly after updates
  - Changed to read README.md from installed location (C:\ITTools\Scripts\README.md) instead of temp extraction folder
  - Eliminates path issues with temp directory changes
  - Simpler, more reliable approach
  - Works regardless of temp folder location
- **Improved File Organization**: All toolkit files now in C:\ITTools
  - Installation: C:\ITTools\Scripts
  - Logs: C:\ITTools\Scripts\Logs
  - Temp files: C:\ITTools\Temp
- **Code Cleanup**: Removed all debug logging code
  - Cleaner, production-ready code
  - Faster execution
  - Better user experience
- **Enhanced Changelog Formatting**: Color-coded changelog display
  - Main features in green
  - Sub-bullets in gray
  - Professional presentation

### Version 2.5.5 (2025-12-08)
- **Enhanced Debug Output**: Added complete extraction folder tree view
  - Shows all directories and files in extraction folder
  - Displays full recursive file listing
  - Helps identify if README.md is missing from GitHub ZIP
  - Shows total item count in source folder

### Version 2.5.4 (2025-12-08)
- **Improved File Management**: Changed temp directory from C:\WINDOWS\TEMP to C:\ITTools\Temp
  - All toolkit files now stay within C:\ITTools directory structure
  - Temp files: C:\ITTools\Temp
  - Scripts: C:\ITTools\Scripts
  - Logs: C:\ITTools\Scripts\Logs
- **Enhanced README Detection**: Added fallback search for README.md
  - If not found in expected location, recursively searches extraction folder
  - More robust changelog extraction
  - Better error messages showing where files are actually located

### Version 2.5.3 (2025-12-08)
- **Testing Version**: Continued diagnosis of changelog extraction
  - Same debug features as v2.5.2
  - Allows testing update from v2.5.2 → v2.5.3
  - Will show extraction folder contents and README path

### Version 2.5.2 (2025-12-08)
- **Enhanced Debug Logging**: Added extraction folder contents listing
  - Shows sourceFolder path during installation
  - Lists all files in extraction directory
  - Verifies README.md existence before reading
  - Helps diagnose path construction issues

### Version 2.5.1 (2025-12-08)
- **Debug Enhancement**: Added comprehensive debug logging to changelog extraction
  - Shows detailed debug messages when changelog fails to display
  - Helps troubleshoot README.md path issues
  - Displays pattern matching diagnostics
  - Identifies file read errors
- Internal testing version to diagnose changelog display issues

### Version 2.5.0 (2025-12-08)
- **Master Audit Logging System**: Comprehensive logging for troubleshooting and support
  - Logs all user actions, menu selections, and errors to `C:\ITTools\Scripts\Logs\master_audit_log.txt`
  - Captures diagnostic information: username, computer name, admin status, PowerShell version, OS version, timestamps
  - Structured log format with severity levels (INFO, WARN, ERROR)
  - Complete error messages with stack traces for debugging
  - Silent failure on logging errors (doesn't disrupt user experience)
- **UI Improvement**: Removed persistent ImageManager status from main menu for cleaner interface
- **Enhanced Changelog Display**: Now shows detailed changelog from README.md after updates (instead of brief embedded notes)
- Status information still available in StorageCraft Troubleshooter submenu when needed

### Version 2.4.0 (2025-12-08)
- **Enhanced Installer**: Added intelligent version detection to Download and Install function
  - Automatically detects currently installed version
  - Compares with latest version from GitHub
  - Displays appropriate message: "New Install", "Update Complete", or "Already Up-to-Date"
  - Shows embedded release notes for new installs and updates
  - Improved user feedback with formatted status messages
- Updated Manual FTP Tool to v2.0.1 (confirmed pause before exit already present)
- Enhanced user experience with clear version upgrade path

### Version 2.3.0 (2025-11-22)
- **Major Enhancement**: Manual FTP Tool v2.0.0 with enterprise-grade reliability
  - Added persistent connection with auto-retry (10 attempts)
  - Implemented resume support for interrupted uploads
  - Added 60-second timeout detection
  - Enhanced status reporting with real-time connection monitoring
  - Comprehensive logging to `C:\ITTools\Scripts\Logs\ftp_upload_log.txt`
  - Exponential backoff between retry attempts
  - Speed and time remaining estimates
  - Automatic skip of failed files with detailed summary report
- Added FTP Upload Log Viewer to StorageCraft Troubleshooter menu (Option 6)
- Enhanced error handling and recovery for large file transfers

### Version 2.2.0 (2025-11-22)
- **Major Update**: Created separate StorageCraft Troubleshooter script with dedicated submenu
- Moved Manual FTP Tool and all ImageManager service controls to StorageCraft submenu
- Simplified main launcher menu (now 3 options instead of 7)
- Improved organization with modular script architecture
- Enhanced user experience with focused troubleshooting submenus

### Version 2.1.0 (2025-11-22)
- Reorganized menu structure for better tool grouping
- Created "StorageCraft Troubleshooter" section combining FTP and ImageManager tools
- Renamed "Run FTP Troubleshooter Tool" to "Manual FTP Tool"
- Improved menu clarity and logical organization

### Version 2.0.0 (2025-11-22)
- **Major Update**: Renamed repository to IT-Troubleshooting-Toolkit
- **New Feature**: Integrated MassGrave PowerShell Utilities (MAS) for Windows/Office activation
- Added Option 7: Run MassGrave Activation Scripts
- Updated all documentation and URLs for new repository name
- Enhanced toolkit with activation capabilities

### Version 1.9.0 (2025-11-22)
- Fixed PowerShell encoding issues with ASCII art branding
- Simplified header to use standard ASCII characters for compatibility
- Maintained Superior Networks branding with clean, professional layout
- Resolved parser errors in Windows PowerShell

### Version 1.8.0 (2025-11-22)
- Integrated Superior Networks branding and logo
- Added branded header to launcher menu
- Updated color scheme to match company branding (Cyan/White)
- Added logo to repository and README

### Version 1.7.0 (2025-11-21)
- Updated installation path to C:\\ITTools\\Scripts for better organization
- Removed all references to old FTPFIX path
- Updated toolkit structure documentation

### Version 1.6.0 (2025-11-21)
- Rebranded as IT Troubleshooting Toolkit Launcher
- Updated documentation to emphasize toolkit launcher concept
- Listed all available tools in documentation
- Updated Quick Start to launch menu instead of FTP tool directly
- Reorganized documentation for better clarity

### Version 1.5.0 (2025-11-21)
- Fixed file overwrite behavior during installation
- Installation now properly overwrites existing files
- Launcher menu always displays first (no auto-run)

### Version 1.4.0 (2025-11-21)
- Updated installation path from C:\\sndayton\\ftpfix to C:\\ITTools\\Scripts
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
- Standardized installation path to C:\\ITTools\\Scripts

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
