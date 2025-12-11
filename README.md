# IT Troubleshooting Toolkit

![Superior Networks Logo](logo.png)

**Version:** 3.5.0  
**Copyright:** 2025  
**Developed by:** Superior Networks LLC

---

## Overview

The **IT Troubleshooting Toolkit** is a comprehensive PowerShell-based solution designed for IT professionals and Managed Service Providers (MSPs) managing **StorageCraft ShadowProtect** backup environments. This toolkit provides powerful automation tools for backup management, FTP synchronization, ImageManager integration, and service diagnostics.

### Key Capabilities

- **StorageCraft Backup Management** - Complete toolset for managing ShadowProtect backups
- **FTP Synchronization** - Multiple methods to sync backups to offsite FTP servers
- **ImageManager Integration** - Query replication queue and manage backup jobs
- **Service Management** - Control ImageManager service (start/stop/restart/status)
- **Automated Deployment** - One-command installation and auto-update system
- **Comprehensive Logging** - Track all operations with detailed audit trails

---

## Quick Start

### One-Command Installation & Launch

Run this command in PowerShell (as Administrator):

```powershell
PowerShell.exe -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/bootstrap.ps1 | iex"
```

**What this does:**
- Automatically installs the toolkit to `C:\ITTools\Scripts` (if not present)
- Checks for updates and auto-updates if available
- Launches the main menu
- Can be run from anywhere - handles everything automatically

### After Installation

The toolkit creates a launcher at: `C:\ITTools\Scripts\launcher.bat`

**To launch the toolkit:**
- Double-click `launcher.bat`, or
- Create a desktop shortcut to `launcher.bat`, or
- Run the bootstrap command again (it will detect existing installation)

---

## Main Menu Structure

```
SUPERIOR NETWORKS LLC
IT Troubleshooting Toolkit - v3.5.0

Toolkit Management:
  1. Download and Install Latest Version
  2. Toolkit Logs

Troubleshooting Tools:
  3. StorageCraft Troubleshooter

Windows/Office Activation:
  4. Run MassGrave Activation Scripts (MAS)

  Q. Quit
```

---

## StorageCraft Troubleshooter

The **StorageCraft Troubleshooter** submenu (option #3) provides comprehensive backup management tools:

```
SUPERIOR NETWORKS LLC
StorageCraft Troubleshooter - v1.7.0

Manual Tools:
  1. Upload Single File (PowerShell FTP)
  2. Sync Local Backups to FTP (WinSCP)
  3. Upload ImageManager Queue (WinSCP)

ImageManager Service Management:
  4. Start ImageManager Service
  5. Stop ImageManager Service
  6. Restart ImageManager Service
  7. Check ImageManager Service Status

Logs and Diagnostics:
  8. View FTP Upload Logs

Utilities:
  9. Download/Install WinSCP
  10. Install Access Database Engine

  B. Back to Main Menu
```

---

## Feature Details

### 1. Upload Single File (PowerShell FTP)

**Purpose:** Manual file selection and FTP upload when ImageManager replication fails

**Features:**
- Browse and select `.spi` backup files from local directory
- Multi-file selection support
- Upload to FTP server with progress tracking
- Pre-configured for ftp.sndayton.com
- Comprehensive logging to `ftp_upload_log.txt`
- Error handling and retry logic

**Use Case:** When ImageManager FTP replication is stuck or failing, manually upload critical backup files

**File:** `ftp_troubleshooter_tool.ps1`

---

### 2. Sync Local Backups to FTP (WinSCP)

**Purpose:** Compare local backup directory with FTP server to identify missing files

**Features:**
- Scans local directory for `-cd.spi` files (incremental backups)
- Connects to FTP server using **WinSCP** (professional FTP client)
- Compares files by name and size
- Displays detailed sync report showing files on local but not on FTP
- Bulk upload missing files using WinSCP engine
- Automatic WinSCP portable download (first run only)
- Export report to text file
- Comprehensive logging to `ftp_sync_log.txt`

**Technology:**
- Uses **WinSCP 6.5.5 Portable** (open-source, trusted by millions)
- Auto-downloads from winscp.net on first run (~8 MB)
- Installs to `C:\ITTools\WinSCP`
- No installation required - fully portable

**Use Case:** Monitor backup sync status and identify which incremental backups need uploading

**File:** `ftp_sync_tool.ps1`

---

### 3. Upload ImageManager Queue (WinSCP) ⭐

**Purpose:** Query ImageManager database for replication queue and upload queued files via FTP

**Features:**
- **Queries ImageManager.mdb database** directly
- Automatic database schema discovery
- Finds replication-related tables (ReplicationQueue, Jobs, Tasks, etc.)
- Extracts file paths from queue data
- Displays all files waiting to replicate
- Shows source table and column for each file
- Upload queued files via WinSCP
- Pre-configured for ftp.sndayton.com
- Comprehensive logging to `ftp_sync_imagemanager_log.txt`

**Technology:**
- Uses **Microsoft ACE OLE DB Provider** to query .mdb database
- Connection: `Provider=Microsoft.ACE.OLEDB.12.0`
- Auto-detects if ACE provider is missing and offers to install
- Smart table discovery algorithm
- Searches for `.spi` files in database fields

**Requirements:**
- Microsoft Access Database Engine (ACE) OLE DB Provider
- Automatically prompts to install if missing (menu option #10)
- Free Microsoft component (~25 MB download)
- Works on all Windows versions (Server 2008 R2+, Windows 7+)

**Database Location:** `C:\Program Files (x86)\StorageCraft\ImageManager\ImageManager.mdb`

**Why This Is Better:**
- ✅ Reads directly from ImageManager's queue
- ✅ Shows only files ImageManager has queued for replication
- ✅ More accurate than directory comparison
- ✅ Reflects ImageManager's actual state
- ✅ Helps troubleshoot why files aren't replicating

**Use Case:** Upload files that ImageManager has queued but hasn't replicated yet. Perfect for troubleshooting replication issues.

**Files:** 
- `ftp_sync_imagemanager.ps1` - Main tool
- `imagemanager_db_module.ps1` - Database query utility module

---

### 4-7. ImageManager Service Management

**Purpose:** Control the StorageCraft ImageManager Windows service

**Features:**
- **Start Service** - Start ImageManager service
- **Stop Service** - Stop ImageManager service
- **Restart Service** - Restart ImageManager service
- **Check Status** - Display detailed service information

**Requirements:** Administrator privileges

**Service Name:** `StorageCraft ImageManager`

**Use Case:** Quickly manage ImageManager service without opening Services console

---

### 9. Download/Install WinSCP

**Purpose:** Install WinSCP portable for FTP sync operations

**Features:**
- Downloads WinSCP 6.5.5 installer from GitHub repository
- Extracts portable version to `C:\ITTools\WinSCP`
- Detects existing installation
- Shows version information
- Silent installation (no user interaction)
- TLS 1.2 support for older systems

**Use Case:** Required for FTP Sync tools (options #2 and #3)

---

### 10. Install Access Database Engine ⭐ NEW

**Purpose:** Install Microsoft Access Database Engine for ImageManager database access

**Features:**
- **Triple detection method** - Registry, OLE DB providers, and DLL files
- **Auto-detects system architecture** - 64-bit vs 32-bit
- **Works on all Windows versions** - Server 2008 R2 through Server 2022, Windows 7-11
- **Verbose troubleshooting** - Detailed on-screen output and logging
- **Comprehensive logging** - All operations logged to toolkit logs
- **Always asks confirmation** - User control before installation
- **Silent installation** - No user interaction during install
- **Post-installation verification** - Tests provider availability
- **Error handling** - Retry option and manual instructions
- **Disk space validation** - Ensures 200 MB free space
- **Administrator check** - Validates privileges before proceeding

**What It Installs:**
- Microsoft Access Database Engine (ACE) OLE DB Provider
- Size: ~25 MB download, ~50 MB installed
- Official Microsoft component
- Does NOT install Microsoft Access application
- Only installs database drivers and OLE DB providers

**Detection Methods:**
1. **Registry Check** - Searches Office registry paths for ACE installation
2. **OLE DB Provider Test** - Tests if ACE providers are available (12.0, 14.0, 15.0, 16.0)
3. **DLL File Check** - Looks for ACEOLEDB.DLL in Common Files

**Installation Process:**
1. Detects if already installed (skips if present)
2. Checks Windows version and architecture
3. Validates disk space (200 MB required)
4. Asks user confirmation
5. Downloads installer from Microsoft (~25 MB)
6. Runs silent installation
7. Verifies installation success
8. Offers retry or manual instructions if failed

**Use Case:** Required for option #3 (Upload ImageManager Queue). The tool will auto-prompt to install if missing.

**Hybrid Approach:**
- **Menu Option #10** - Install manually anytime
- **Auto-Prompt** - When using option #3, automatically detects and offers to install

**File:** `install_access_engine.ps1`

---

### 8. View FTP Upload Logs

**Purpose:** View and analyze FTP operation logs

**Features:**
- Opens log file in Notepad
- Shows log file size and last modified date
- Handles missing log files gracefully
- Color-coded log entries (ERROR, WARN, SUCCESS)

**Log Locations:**
- FTP Upload Log: `C:\ITTools\Scripts\Logs\ftp_upload_log.txt`
- FTP Sync Log: `C:\ITTools\Scripts\Logs\ftp_sync_log.txt`
- FTP Sync (ImageManager) Log: `C:\ITTools\Scripts\Logs\ftp_sync_imagemanager_log.txt`
- Master Audit Log: `C:\ITTools\Scripts\Logs\master_audit_log.txt`

---

### Toolkit Logs Menu

**Purpose:** Centralized log viewer for all toolkit operations

**Features:**
- View Master Audit Log
- View FTP Upload Log
- View FTP Sync Log
- Opens logs in Notepad
- Shows file size and last modified date
- Handles missing logs gracefully

**Use Case:** Troubleshoot toolkit operations and track historical activity

---

### Windows/Office Activation (MAS)

**Purpose:** Activate Windows and Office using MassGrave Activation Scripts

**Features:**
- Launches official MassGrave Activation Scripts (MAS)
- Direct download from GitHub
- Supports Windows and Office activation
- Industry-standard activation tool

**Source:** https://github.com/massgravel/Microsoft-Activation-Scripts

---

## Installation Details

### Directory Structure

```
C:\ITTools\
├── Scripts\                    # Main installation directory
│   ├── launch_menu.ps1        # Main launcher
│   ├── storagecraft_troubleshooter.ps1
│   ├── ftp_troubleshooter_tool.ps1
│   ├── ftp_sync_tool.ps1
│   ├── ftp_sync_imagemanager.ps1
│   ├── imagemanager_db_module.ps1
│   ├── bootstrap.ps1
│   ├── launcher.bat           # Quick launcher
│   ├── README.md
│   └── Logs\                  # Log directory
│       ├── master_audit_log.txt
│       ├── ftp_upload_log.txt
│       ├── ftp_sync_log.txt
│       └── ftp_sync_imagemanager_log.txt
├── WinSCP\                    # WinSCP portable installation
│   ├── WinSCP.com
│   ├── WinSCP.exe
│   └── ...
└── Temp\                      # Temporary files
```

### System Requirements

- **Operating System:** Windows 7 or later
- **PowerShell:** 5.1 or higher (pre-installed on Windows 10/11)
- **Permissions:** Administrator privileges (for service management)
- **Internet Access:** Required for initial download and updates
- **Disk Space:** ~20 MB (including WinSCP)

### Optional Requirements

**For ImageManager Integration:**
- StorageCraft ImageManager installed
- ImageManager.mdb database present
- Microsoft Access Database Engine (ACE) OLE DB Provider
  - Usually pre-installed on Windows
  - If not: Download from Microsoft (free)

---

## Update System

### Automatic Updates

The toolkit includes a smart auto-update system:

1. **Version Detection** - Compares installed version with GitHub
2. **Automatic Download** - Downloads new version if available
3. **Staged Update** - Safely replaces files while avoiding locks
4. **Automatic Restart** - Restarts toolkit with new version
5. **Changelog Display** - Shows what's new after update

### Manual Update Check

Select **"1. Download and Install Latest Version"** from main menu

### Bootstrap Installer

The `bootstrap.ps1` script handles:
- Initial installation (if toolkit not present)
- Update checking and installation
- Version comparison
- Launching from correct location
- Error handling and user feedback

---

## FTP Server Configuration

### Default FTP Server

The toolkit is pre-configured for: **ftp.sndayton.com**

### Changing FTP Server

You can enter a different FTP server when prompted by any FTP tool.

### FTP Credentials

All FTP tools prompt for:
- FTP Server (default: ftp.sndayton.com)
- FTP Username
- FTP Password

Credentials are **not stored** - you must enter them each time for security.

---

## Logging and Auditing

### Master Audit Log

**Location:** `C:\ITTools\Scripts\Logs\master_audit_log.txt`

**Purpose:** Tracks all toolkit operations

**Contents:**
- Toolkit launches
- Menu selections
- Tool executions
- Service operations
- Errors and warnings

### FTP Operation Logs

**FTP Upload Log:** `C:\ITTools\Scripts\Logs\ftp_upload_log.txt`
- Manual FTP tool operations
- File uploads
- FTP connection details
- Errors and retries

**FTP Sync Log:** `C:\ITTools\Scripts\Logs\ftp_sync_log.txt`
- Directory comparison operations
- File sync reports
- WinSCP operations
- Missing file lists

**FTP Sync (ImageManager) Log:** `C:\ITTools\Scripts\Logs\ftp_sync_imagemanager_log.txt`
- Database query operations
- Queue file extraction
- Upload operations
- Database errors

### Log Format

```
[2025-12-10 14:30:15] [INFO] FTP Sync Tool started
[2025-12-10 14:30:20] [SUCCESS] Connected to ftp.sndayton.com
[2025-12-10 14:30:25] [WARN] File not found on FTP: backup-001.spi
[2025-12-10 14:30:30] [ERROR] Upload failed: Connection timeout
```

---

## Troubleshooting

### Common Issues

**Issue:** "ImageManager database NOT found"
- **Solution:** Ensure StorageCraft ImageManager is installed
- **Path:** `C:\Program Files (x86)\StorageCraft\ImageManager\ImageManager.mdb`

**Issue:** "WinSCP download failed"
- **Solution:** Download manually from https://winscp.net/
- **Extract to:** `C:\ITTools\WinSCP`

**Issue:** "Administrator privileges required"
- **Solution:** Right-click PowerShell and select "Run as Administrator"

**Issue:** "Service not found: StorageCraft ImageManager"
- **Solution:** Install StorageCraft ImageManager

### Getting Help

**Check Logs:**
1. Select "2. Toolkit Logs" from main menu
2. View relevant log file
3. Look for ERROR or WARN entries

**GitHub Issues:**
- https://github.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/issues

---

## Security Considerations

### Execution Policy

The toolkit requires `ExecutionPolicy Bypass` to run PowerShell scripts.

**Bootstrap command includes:** `-ExecutionPolicy Bypass`

This is safe when running trusted scripts from Superior Networks.

### FTP Credentials

- **Not stored** - You must enter credentials each time
- **Not logged** - Passwords are never written to log files
- **Secure input** - Password prompts use `-AsSecureString` when possible

### Administrator Privileges

Required only for:
- Service management (start/stop/restart ImageManager)
- Some system-level operations

Not required for:
- FTP operations
- Log viewing
- Database queries

---

## License and Disclaimer

**Copyright © 2025 Superior Networks LLC**

This software is provided as-is without warranty of any kind.

**Use at your own risk.** Always test in a non-production environment first.

**StorageCraft, ShadowProtect, and ImageManager** are trademarks of StorageCraft Technology Corporation (now Arcserve).

**WinSCP** is open-source software licensed under GNU GPL.

---

## Credits

**Developed by:** Superior Networks LLC

**Third-Party Components:**
- **WinSCP** - https://winscp.net/ (GNU GPL)
- **MassGrave Activation Scripts** - https://github.com/massgravel/Microsoft-Activation-Scripts (GNU GPL)

---

## Support

For support, feature requests, or bug reports:

**GitHub Issues:** https://github.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/issues

**Website:** https://help.manus.im

---

## Change Log

### Version 3.5.0 (2025-12-11) ⭐ NEW
- **Major Feature**: Access Database Engine Auto-Installer
  - New menu option #10: "Install Access Database Engine"
  - Hybrid approach: Manual installation via menu + auto-prompt when needed
  - Required for option #3 (Upload ImageManager Queue) to read ImageManager.mdb
  - Triple detection method: Registry, OLE DB providers, and DLL files
  - Auto-detects 64-bit vs 32-bit systems
  - Works on all Windows versions (Server 2008 R2+, Windows 7-11)
  - Verbose troubleshooting output on-screen
  - Comprehensive logging to toolkit logs
  - Always asks for user confirmation before installing
  - Silent installation with progress tracking
  - Post-installation verification
  - Retry option and manual instructions if installation fails
  - Disk space validation (200 MB required)
  - Administrator privilege check
- **Auto-Detection Integration**:
  - Option #3 (Upload ImageManager Queue) now auto-detects missing ACE
  - Prompts user to install if not found
  - Seamless integration - no manual steps required
  - Can also install manually via menu option #10 anytime
- **What It Installs**:
  - Microsoft Access Database Engine (ACE) OLE DB Provider
  - Size: ~25 MB download, ~50 MB installed
  - Official Microsoft component (not third-party)
  - Only installs database drivers (not Access application)
  - Safe for all Windows Server versions
- **Files Added**:
  - `install_access_engine.ps1` (v1.0.0) - ACE installer with verbose logging
- **Files Updated**:
  - `storagecraft_troubleshooter.ps1` (v1.6.0 → v1.7.0) - Added menu option #10
  - `ftp_sync_imagemanager.ps1` (v1.0.0 → v1.1.0) - Added ACE auto-detection
  - `launch_menu.ps1` (v3.4.0 → v3.5.0)
  - `README.md` - Added comprehensive ACE installer documentation

**Use Case**: Users on fresh Windows installations or systems without Office can now easily install the required Access Database Engine to use the ImageManager Queue tool. The tool automatically detects and offers to install if missing.

### Version 3.4.0 (2025-12-10)
- **Improved UX**: Clearer Menu Names for FTP Tools
  - Renamed confusing menu options for better clarity
  - Each name now describes what the tool does and which technology it uses
- **Menu Changes**:
  - "Manual FTP Tool" → **"Upload Single File (PowerShell FTP)"**
  - "FTP Sync" → **"Sync Local Backups to FTP (WinSCP)"**
  - "FTP Sync (ImageManager Queue)" → **"Upload ImageManager Queue (WinSCP)"**
- **Benefits**:
  - Immediately understand what each tool does
  - Know which technology is used (PowerShell vs WinSCP)
  - No more confusion between two "FTP Sync" options
  - Action-focused naming (Upload, Sync)
- **Files Updated**:
  - `storagecraft_troubleshooter.ps1` (v1.5.0 → v1.6.0)
  - `launch_menu.ps1` (v3.3.0 → v3.4.0)
  - `README.md` - Updated all documentation

**Use Case**: Users can now quickly identify which tool to use based on clear, descriptive names instead of generic "FTP Sync" labels.

### Version 3.3.0 (2025-12-10)
- **Major Improvement**: WinSCP Now Downloaded from GitHub Repository
  - Uploaded WinSCP 6.5.5 installer to GitHub repository (11.11 MB)
  - All download functions now use GitHub-hosted installer
  - Much more reliable than downloading from winscp.net
  - No more SSL/TLS connection errors on Server 2012 R2
  - Uses silent installer extraction instead of ZIP files
- **Benefits**:
  - Single source of truth (your own repository)
  - Faster downloads (GitHub CDN)
  - No dependency on external websites
  - Works perfectly on PowerShell 4.0 (Server 2012 R2)
  - Consistent download experience across all systems
- **Files Updated**:
  - `storagecraft_troubleshooter.ps1` (v1.4.0 → v1.5.0)
  - `ftp_sync_tool.ps1` - Updated download URL and method
  - `ftp_sync_imagemanager.ps1` - Updated download URL and method
  - `launch_menu.ps1` (v3.2.0 → v3.3.0)
- **New File**:
  - `WinSCP-6.5.5-Setup.exe` - Hosted in repository

**Use Case**: WinSCP downloads are now 100% reliable on all Windows versions, including Server 2012 R2. No more external download failures.

### Version 3.2.0 (2025-12-10)
- **New Feature**: WinSCP Download Menu Option
  - Added option #9 in StorageCraft Troubleshooter: "Download/Install WinSCP"
  - Manual WinSCP download/installation from menu
  - Automatic detection of existing WinSCP installation
  - Version display if already installed
  - Prevents re-downloading if already present
- **Improved Download Reliability**:
  - All WinSCP download functions now auto-enable TLS 1.2
  - Changed from `Invoke-WebRequest` to `WebClient` for PowerShell 4.0 compatibility
  - Works on Windows Server 2012 R2 (PowerShell 4.0)
  - No more "Unable to connect to remote server" errors on older systems
- **Files Updated**:
  - `storagecraft_troubleshooter.ps1` (v1.3.0 → v1.4.0)
  - `ftp_sync_tool.ps1` - Improved download function
  - `ftp_sync_imagemanager.ps1` - Improved download function
  - `launch_menu.ps1` (v3.1.0 → v3.2.0)

**Use Case**: Users on Windows Server 2012 R2 can now download WinSCP automatically without SSL/TLS errors. Menu option allows manual retry if automatic download fails during FTP Sync tool launch.

### Version 3.1.0 (2025-12-10)
- **New Feature**: FTP Sync with ImageManager Integration
  - Query ImageManager.mdb database for replication queue
  - Display files waiting to replicate from ImageManager queue
  - Upload queued files directly via FTP using WinSCP
  - Automatic database schema discovery
  - Pre-configured for ftp.sndayton.com
  - New menu option: "FTP Sync (ImageManager Queue)"
- **New Files**:
  - `ftp_sync_imagemanager.ps1` - ImageManager-integrated FTP sync tool
  - `imagemanager_db_module.ps1` - Database query module (utility)
- **Updated Files**:
  - `storagecraft_troubleshooter.ps1` (v1.2.0 → v1.3.0)
    - Added option 3: FTP Sync (ImageManager Queue)
    - Renumbered all subsequent menu options (4-8)
  - `launch_menu.ps1` (v3.0.3 → v3.1.0)

**Use Case**: Administrators can now upload files directly from ImageManager's replication queue, ensuring only files that ImageManager has queued for replication are uploaded via FTP. This is more accurate than directory comparison.

### Version 3.0.3 (2025-12-08)
- **Bug Fix**: Fixed WinSCP download URL (404 error)
  - Changed from GitHub releases URL to official winscp.net download
  - Updated to WinSCP 6.5.5 (latest version)
  - URL: https://winscp.net/download/WinSCP-6.5.5-Portable.zip
  - This URL is more reliable and directly from WinSCP official site
  - Download should now work correctly

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

---

**For complete version history, see the full changelog in the repository.**
