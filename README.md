# FTP Troubleshooter Tool

**Version:** 1.0.1  
**Copyright:** 2025 Superior Networks LLC  
**Author:** Dwain Henderson Jr.

## Overview

The FTP Troubleshooter Tool is a PowerShell-based interactive file uploader designed specifically for Superior Networks' operational needs. This tool serves as a critical failover solution when the primary Image Manager system experiences persistent issues transferring files to the off-site FTP server.

## Purpose

This utility was created to address a specific operational challenge: when the Image Manager consistently fails to transfer particular files, this tool provides a reliable manual alternative to ensure business continuity and data transfer completion.

## Key Features

- **Interactive GUI File Picker**: Select single or multiple files using a familiar Windows dialog
- **Hard-coded Default FTP Server**: Pre-configured with `ftp.sndayton.com` for quick access
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

## Installation

1. Download the `ftp_troubleshooter_tool.ps1` file from this repository
2. Save it to a convenient location (e.g., `C:\Scripts\` or your Desktop)
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

## Usage

### Method 1: Right-Click Execution (Easiest)

1. Navigate to the script file in File Explorer
2. Right-click on `ftp_troubleshooter_tool.ps1`
3. Select **"Run with PowerShell"**

### Method 2: PowerShell Console (Recommended)

1. Open PowerShell (no admin rights needed)
2. Navigate to the script directory:
   ```powershell
   cd C:\Scripts
   ```
3. Execute the script:
   ```powershell
   .\ftp_troubleshooter_tool.ps1
   ```

### Interactive Workflow

Once the script starts, follow these prompts:

1. **File Selection**: A GUI dialog appears—select one or more files to upload
2. **FTP Server**: Press Enter to use the default (`ftp.sndayton.com`) or type a new address
3. **Username**: Enter your FTP username
4. **Password**: Enter your FTP password (input will be hidden)
5. **Upload Progress**: Watch the progress bar as files upload
6. **Completion**: Review the summary message when all files are processed

## Configuration

### Changing the Default FTP Server

To permanently change the default FTP server, edit line 50 in the script:

```powershell
$defaultFtpServer = "ftp.sndayton.com"
```

Replace `ftp.sndayton.com` with your preferred default server address.

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **"Execution policy" error** | Run `Set-ExecutionPolicy RemoteSigned` as Administrator |
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

## Security Considerations

- **Password Handling**: While the script uses `SecureString` for initial input, it must convert to plaintext for the FTP connection. The password is cleared from memory after use.
- **Private Repository**: This repository is private to protect configuration details and operational procedures.
- **Credential Storage**: This tool does NOT store credentials—you must enter them each time.

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

This tool is specifically designed for:

1. **Image Manager Failures**: When the primary system cannot transfer specific files
2. **Manual Verification**: Testing FTP connectivity and credentials
3. **Emergency Transfers**: Quick file uploads when automated systems are down
4. **Troubleshooting**: Isolating whether transfer issues are system-specific or network-related

## Support

For issues, questions, or enhancement requests related to this tool:

**Superior Networks LLC**  
703 Jefferson St.  
Dayton, Ohio 45342  
Phone: (937) 985-2480

## License

Copyright © 2025 Superior Networks LLC. All rights reserved.

This tool is proprietary software developed for internal use by Superior Networks LLC.

---

## Change Log

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
