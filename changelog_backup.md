## Change Log

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
