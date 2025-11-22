# FTP Troubleshooter Tool

**Version:** 1.1.0  
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
   cd C:\Scripts
   ```
3. Execute the script:
   ```powershell
   .\ftp_troubleshooter_tool.ps1
   ```

### Method 3: Bypass Execution Policy (One-Time)

If you encounter execution policy errors:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\ftp_troubleshooter_tool.ps1
```

### Interactive Workflow

Once the script starts, follow these prompts:

1. **File Selection**: A GUI dialog appears—select one or more files to upload
2. **FTP Server**: Press Enter to use the default or type a new address
3. **Username**: Enter your FTP username
4. **Password**: Enter your FTP password (input will be hidden)
5. **Upload Progress**: Watch the progress bar as files upload
6. **Completion**: Review the summary message when all files are processed

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
