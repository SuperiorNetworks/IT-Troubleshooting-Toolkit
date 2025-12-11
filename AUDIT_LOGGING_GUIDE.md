# Master Audit Logging System - User Guide

**Version:** 2.5.0  
**Feature Added:** December 8, 2025  
**Log Location:** `C:\ITTools\Scripts\Logs\master_audit_log.txt`

---

## Overview

The IT Troubleshooting Toolkit now includes a comprehensive master audit logging system that automatically captures all user interactions, menu selections, errors, and diagnostic information. This log is designed to help with troubleshooting and can be shared with support for faster issue resolution.

---

## What Gets Logged

### User Actions
- **Script Startup**: When the launcher is opened
- **Menu Selections**: Every option chosen (1, 2, 3, Q, or invalid entries)
- **Script Exit**: When the user quits the application

### Operations
- **Download and Install**: 
  - New installations
  - Updates (with version upgrade path)
  - Reinstalls
  - Success or failure status
- **StorageCraft Troubleshooter**: 
  - Launch attempts
  - Script not found errors
- **MassGrave Activation**: 
  - User confirmations or cancellations
  - Download and execution status
  - Errors during activation

### Errors
- **All Exceptions**: Full error messages with stack traces
- **Missing Files**: When expected scripts are not found
- **Network Errors**: Download failures, connection issues
- **Permission Errors**: Access denied, admin privilege issues

---

## Log Entry Format

Each log entry contains the following information:

```
[2025-12-08 14:23:15] [INFO] [Admin] dwain@DESKTOP-ABC123
  Action: Menu Selection
  Details: Option 1: Download and Install Latest Version
  Environment: PS 5.1.19041.5247 | Microsoft Windows NT 10.0.19045.0
  Path: C:\ITTools\Scripts
  ======================================================================
```

### Fields Explained

| Field | Description | Example |
|-------|-------------|---------|
| **Timestamp** | Date and time of action | `2025-12-08 14:23:15` |
| **Level** | Severity (INFO, WARN, ERROR) | `[INFO]` |
| **Admin Status** | User or Admin privileges | `[Admin]` or `[User]` |
| **User@Computer** | Username and computer name | `dwain@DESKTOP-ABC123` |
| **Action** | What operation was performed | `Menu Selection` |
| **Details** | Additional context | `Option 1: Download and Install...` |
| **Error** | Error message (if applicable) | `Failed to download: Connection timeout` |
| **Stack** | Stack trace (for errors only) | Full PowerShell stack trace |
| **Environment** | PowerShell and OS versions | `PS 5.1.19041.5247 \| Windows NT 10.0` |
| **Path** | Installation directory | `C:\ITTools\Scripts` |

---

## Log Examples

### Example 1: Successful Update

```
[2025-12-08 14:25:30] [INFO] [Admin] dwain@DESKTOP-ABC123
  Action: Download and Install
  Details: Update completed: v2.5.0
  Environment: PS 5.1.19041.5247 | Microsoft Windows NT 10.0.19045.0
  Path: C:\ITTools\Scripts
  ======================================================================
```

### Example 2: Error During Installation

```
[2025-12-08 14:30:45] [ERROR] [User] john@LAPTOP-XYZ789
  Action: Download and Install
  Details: 
  Error: Failed to download and install: Access to the path 'C:\ITTools\Scripts' is denied.
  Stack: at Download-And-Install, C:\ITTools\Scripts\launch_menu.ps1: line 250
  Environment: PS 5.1.19041.5247 | Microsoft Windows NT 10.0.19045.0
  Path: C:\ITTools\Scripts
  ======================================================================
```

### Example 3: Invalid Menu Selection

```
[2025-12-08 14:35:12] [WARN] [User] sarah@WORKSTATION-456
  Action: Invalid Menu Selection
  Details: User entered: 5
  Environment: PS 5.1.19041.5247 | Microsoft Windows NT 10.0.19045.0
  Path: C:\ITTools\Scripts
  ======================================================================
```

### Example 4: MassGrave Activation Cancelled

```
[2025-12-08 14:40:00] [INFO] [Admin] dwain@DESKTOP-ABC123
  Action: MassGrave Activation
  Details: User cancelled MAS launch
  Environment: PS 5.1.19041.5247 | Microsoft Windows NT 10.0.19045.0
  Path: C:\ITTools\Scripts
  ======================================================================
```

---

## How to Use the Audit Log for Troubleshooting

### For End Users

1. **Reproduce the Issue**: Use the toolkit normally until the error occurs
2. **Locate the Log**: Navigate to `C:\ITTools\Scripts\Logs\master_audit_log.txt`
3. **Share the Log**: 
   - Right-click the file → Send to → Compressed (zipped) folder
   - Upload the ZIP file to your support ticket or email it to support
   - Or copy the last 50-100 lines if the log is very large

### For Support/Developers

The audit log provides everything needed for troubleshooting:

1. **User Environment**: 
   - PowerShell version (compatibility issues)
   - Windows version (OS-specific bugs)
   - Admin vs User privileges (permission issues)

2. **Sequence of Events**: 
   - What the user clicked before the error
   - Previous successful operations
   - Timing of events

3. **Error Context**: 
   - Exact error message
   - Stack trace for debugging
   - System state at time of error

4. **Pattern Detection**: 
   - Repeated errors
   - Common failure points
   - Usage patterns

---

## Log File Management

### Location
- **Primary Log**: `C:\ITTools\Scripts\Logs\master_audit_log.txt`
- **FTP Upload Log**: `C:\ITTools\Scripts\Logs\ftp_upload_log.txt` (separate)

### File Size
- The log file grows continuously with each action
- No automatic rotation or cleanup (by design - preserves history)
- Typical size: 1-5 KB per day of normal use
- Can be manually deleted if it grows too large

### Manual Cleanup
If the log file becomes too large, you can safely delete it:

```powershell
# Delete the audit log (it will be recreated automatically)
Remove-Item "C:\ITTools\Scripts\Logs\master_audit_log.txt" -Force
```

Or archive it:

```powershell
# Archive old log and start fresh
$date = Get-Date -Format "yyyy-MM-dd"
Move-Item "C:\ITTools\Scripts\Logs\master_audit_log.txt" `
          "C:\ITTools\Scripts\Logs\master_audit_log_$date.txt"
```

---

## Privacy and Security

### What's Logged
- ✅ Username (Windows login name)
- ✅ Computer name
- ✅ Menu selections and actions
- ✅ Error messages
- ✅ File paths
- ✅ PowerShell and OS versions

### What's NOT Logged
- ❌ Passwords or credentials
- ❌ FTP server addresses (logged in separate FTP log)
- ❌ File contents
- ❌ Personal data beyond username/computer name
- ❌ Network traffic or packet data

### Security Considerations
- Log file is stored locally only (not transmitted anywhere)
- Standard Windows file permissions apply
- You control when/if to share the log with support
- Can be deleted at any time without affecting toolkit functionality

---

## Technical Details

### Functions

#### `Write-AuditLog`
Writes a structured log entry to the audit log file.

**Parameters:**
- `$action` (string): The action being logged (e.g., "Menu Selection")
- `$details` (string): Additional context or information
- `$level` (string): Severity level - "INFO", "WARN", or "ERROR"
- `$errorMessage` (string): Error message if applicable

**Example:**
```powershell
Write-AuditLog -action "Download and Install" -details "Update completed: v2.5.0" -level "INFO"
```

#### `Get-AuditLogSummary`
Returns statistics about the audit log file.

**Returns:**
- `TotalEntries`: Number of log entries
- `ErrorCount`: Number of ERROR entries
- `WarnCount`: Number of WARN entries
- `FileSizeKB`: Log file size in KB
- `LastModified`: Last modification timestamp

**Example:**
```powershell
$summary = Get-AuditLogSummary
Write-Host "Total log entries: $($summary.TotalEntries)"
Write-Host "Errors: $($summary.ErrorCount)"
```

### Error Handling
- Logging failures are **silently ignored** to prevent disrupting user experience
- If the log directory can't be created, the toolkit continues normally
- If the log file can't be written, no error is shown to the user

---

## Benefits for Troubleshooting

### Before Audit Logging
❌ User: "It didn't work"  
❌ Support: "What error did you see?"  
❌ User: "I don't remember, it flashed and closed"  
❌ Support: "Can you try again and screenshot it?"  
❌ **Result:** Multiple back-and-forth emails, slow resolution

### After Audit Logging
✅ User: "It didn't work, here's the log file"  
✅ Support: *Opens log, sees exact error, environment, and sequence*  
✅ Support: "I see the issue - you need admin rights. Right-click PowerShell and Run as Administrator"  
✅ **Result:** Issue resolved in one email

---

## Frequently Asked Questions

### Q: Will this slow down the toolkit?
**A:** No. Logging is asynchronous and adds less than 10ms per operation.

### Q: Can I disable logging?
**A:** Logging is built-in and cannot be disabled, but it's designed to be unobtrusive. You can delete the log file at any time.

### Q: What if the log file gets huge?
**A:** You can safely delete it. It will be recreated automatically on next use.

### Q: Is my data being sent anywhere?
**A:** No. The log is stored locally only. You decide when/if to share it.

### Q: Can I view the log in a nicer format?
**A:** Yes! Open it in Notepad++ or VS Code for syntax highlighting. Or use PowerShell:
```powershell
Get-Content "C:\ITTools\Scripts\Logs\master_audit_log.txt" | Select-Object -Last 20
```

### Q: What if I get an error about the log directory?
**A:** The toolkit automatically creates the directory. If you see an error, check that you have write permissions to `C:\ITTools\Scripts\Logs`.

---

## Example Troubleshooting Workflow

### Scenario: User reports "FTP tool won't launch"

1. **User reproduces issue** and sends audit log
2. **Support opens log** and searches for "FTP" or "StorageCraft"
3. **Log shows:**
   ```
   [2025-12-08 15:00:00] [ERROR] [User] john@LAPTOP-XYZ789
     Action: StorageCraft Troubleshooter
     Error: Script not found: C:\ITTools\Scripts\storagecraft_troubleshooter.ps1
   ```
4. **Support identifies issue**: Scripts not installed
5. **Support response**: "Please run Option 1 to download and install the toolkit first"
6. **Issue resolved** in minutes instead of hours

---

## Conclusion

The master audit logging system transforms troubleshooting from guesswork into data-driven problem solving. By capturing every action and error with full diagnostic context, it enables faster, more accurate support responses and helps identify patterns in toolkit usage.

**Remember:** The log is your friend. When something goes wrong, share it with support for the fastest resolution!

---

**Developed by:** Superior Networks LLC  
**Copyright:** 2025  
**Repository:** https://github.com/SuperiorNetworks/IT-Troubleshooting-Toolkit
