<#
.SYNOPSIS
FTP Troubleshooter Tool - Interactive file uploader for Superior Network's off-site FTP server

.DESCRIPTION
Name: ftp_troubleshooter_tool.ps1
Version: 1.0.0
Purpose: Manual FTP file upload tool used when the Image Manager fails to transfer files.
         This is a troubleshooting utility for transferring files to Superior Network's 
         off-site FTP server when the primary image manager consistently has issues 
         transferring particular files.
Path: /scripts/ftp_troubleshooter_tool.ps1
Copyright: 2025 Superior Networks LLC

Key Features:
- Interactive GUI file picker for selecting multiple files
- Hard-coded default FTP server with option to override
- Secure credential prompting
- Progress bar for upload tracking
- Robust error handling and resource management
- 1MB buffer for efficient large file transfers

Input: 
- User-selected files via GUI dialog
- FTP server address (default: ftp.sndayton.com)
- FTP username and password via secure prompt

Output:
- Files uploaded to FTP server
- Console progress and status messages
- Error messages for failed uploads

Dependencies:
- Windows PowerShell 5.1 or higher
- .NET Framework (System.Windows.Forms)
- Network access to FTP server

Change Log:
2025-11-21 v1.0.0 - Initial release (Dwain Henderson Jr)

.NOTES
Author: Dwain Henderson Jr.
Company: Superior Networks LLC
Address: 703 Jefferson St. Dayton Ohio, 45342
Phone: (937) 985-2480
#>

Add-Type -AssemblyName System.Windows.Forms

# --- Configuration ---
# Set your default FTP server address here.
$defaultFtpServer = "ftp.sndayton.com"

function Select-Files {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Multiselect = $true
    $dialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    $dialog.Title = "Select files to upload via FTP"
    if ($dialog.ShowDialog() -eq 'OK') {
        return $dialog.FileNames
    }
    else {
        Write-Warning "No files selected. Exiting."
        exit 1
    }
}

function Prompt-For-FtpDetails {
    param (
        [string]$defaultServer
    )

    # Prompt for FTP server, showing the default. The user can press Enter to accept it.
    $ftpServerInput = Read-Host "Enter FTP server address (default: $defaultServer)"
    $ftpServer = if ([string]::IsNullOrWhiteSpace($ftpServerInput)) { $defaultServer } else { $ftpServerInput }

    Write-Host "Connecting to FTP server: $ftpServer"

    $ftpUser = Read-Host "Enter FTP username"
    if ([string]::IsNullOrWhiteSpace($ftpUser)) {
        Write-Error "FTP username cannot be empty."
        exit 1
    }

    Write-Warning "The password will be temporarily converted to plain text in memory for the connection."
    $ftppass = Read-Host "Enter FTP password" -AsSecureString
    
    # Convert SecureString to plain text for NetworkCredential
    $plainpass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ftppass))

    return @{Server=$ftpServer; User=$ftpUser; Pass=$plainpass}
}

function Upload-FileToFTP {
    param (
        [string]$filePath,
        [string]$ftpServer,
        [string]$ftpUser,
        [string]$ftpPass
    )

    $fileStream = $null
    $ftpStream = $null

    try {
        $filename = [System.IO.Path]::GetFileName($filePath)
        $uri = "ftp://$ftpServer/$filename"
        $request = [System.Net.FtpWebRequest]::Create($uri)
        $request.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
        $request.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
        $request.UseBinary = $true
        $request.UsePassive = $true
        $request.KeepAlive = $false

        Write-Host "Uploading $filename to $ftpServer..."
        $fileStream = [System.IO.File]::OpenRead($filePath)
        $ftpStream = $request.GetRequestStream()

        $buffer = New-Object byte[] 1048576  # 1MB buffer
        $totalBytes = $fileStream.Length
        $sentBytes = 0

        while (($readBytes = $fileStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $ftpStream.Write($buffer, 0, $readBytes)
            $sentBytes += $readBytes
            Write-Progress -Activity "Uploading $filename" -Status "$sentBytes of $totalBytes bytes" -PercentComplete (($sentBytes / $totalBytes) * 100)
        }

        Write-Host "$filename upload complete.`n"
    }
    catch {
        Write-Error "Error uploading $filePath: $_"
    }
    finally {
        # Ensure streams are closed even if an error occurs
        if ($ftpStream -ne $null) { $ftpStream.Close() }
        if ($fileStream -ne $null) { $fileStream.Close() }
    }
}

# --- Main script logic ---
Write-Host "=== FTP Troubleshooter Tool ===" -ForegroundColor Cyan
Write-Host "Superior Networks LLC - Image Manager Failover Utility`n" -ForegroundColor Cyan

Write-Host "Use the dialog to select one or more files for FTP transfer."
$selectedFiles = Select-Files
$ftpDetails = Prompt-For-FtpDetails -defaultServer $defaultFtpServer

foreach ($file in $selectedFiles) {
    Upload-FileToFTP -filePath $file -ftpServer $ftpDetails.Server -ftpUser $ftpDetails.User -ftpPass $ftpDetails.Pass
}

# Clear the plaintext password from memory as soon as it's no longer needed
Clear-Variable -Name 'ftpDetails'
[GC]::Collect()

Write-Host "`nAll selected files processed. Check logs for details." -ForegroundColor Green
