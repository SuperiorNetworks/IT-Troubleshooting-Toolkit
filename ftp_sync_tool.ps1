<#
.SYNOPSIS
FTP Sync - WinSCP-based backup synchronization tool

.DESCRIPTION
Name: ftp_sync_tool.ps1
Version: 2.0.0
Purpose: Compare local backup directory with FTP server using WinSCP.
         Automatically downloads WinSCP portable if not present.
         Pre-configured for ftp.sndayton.com with -cd.spi file filtering.
Path: /scripts/ftp_sync_tool.ps1
Copyright: 2025

Key Features:
- Automatic WinSCP portable download and setup
- Pre-configured for ftp.sndayton.com
- Compare local vs FTP files (filtered for -cd.spi)
- Display files missing on FTP
- Bulk upload missing files using WinSCP
- Professional WinSCP synchronization engine
- Comprehensive logging

Input:
- FTP username and password
- Local backup directory path

Output:
- Comparison report showing missing files
- Option to upload selected files via WinSCP
- Detailed log file

Dependencies:
- Windows PowerShell 5.1 or higher
- Internet access (for WinSCP download if needed)
- Network access to FTP server

Change Log:
2025-12-08 v2.0.0 - Rewritten to use WinSCP for reliability

.NOTES
Uses WinSCP open-source FTP client for professional-grade synchronization.
WinSCP: https://winscp.net/
#>

# --- Configuration ---
$defaultFtpServer = "ftp.sndayton.com"
$logDirectory = "C:\ITTools\Scripts\Logs"
$logFile = Join-Path $logDirectory "ftp_sync_log.txt"
$winscpDirectory = "C:\ITTools\WinSCP"
$winscpExe = Join-Path $winscpDirectory "WinSCP.com"
$winscpUrl = "https://github.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/releases/download/v3.5.1-assets/WinSCP-6.5.5-Setup.exe"

# Ensure directories exist
if (-not (Test-Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
}

if (-not (Test-Path $winscpDirectory)) {
    New-Item -ItemType Directory -Path $winscpDirectory -Force | Out-Null
}

function Write-Log {
    param (
        [string]$message,
        [string]$level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$level] $message"
    
    # Write to log file
    Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
    
    # Write to console with color
    $color = switch ($level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    
    Write-Host $message -ForegroundColor $color
}

function Test-WinSCP {
    if (Test-Path $winscpExe) {
        Write-Log "WinSCP found at: $winscpExe" "SUCCESS"
        return $true
    }
    return $false
}

function Download-WinSCP {
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "                 Downloading WinSCP Portable                     " -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Log "WinSCP not found. Downloading from GitHub repository..."
    Write-Host "This only needs to happen once." -ForegroundColor Yellow
    Write-Host "Download source: GitHub Repository" -ForegroundColor Gray
    Write-Host ""
    
    $installerPath = Join-Path $env:TEMP "WinSCP-Setup.exe"
    
    try {
        # Enable TLS 1.2 for older systems
        Write-Host "Configuring secure connection..." -ForegroundColor Gray
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host ""
        
        Write-Host "Downloading WinSCP installer... Please wait..." -ForegroundColor Yellow
        
        # Use WebClient for better compatibility with PowerShell 4.0
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($winscpUrl, $installerPath)
        
        Write-Log "Download complete!" "SUCCESS"
        Write-Host "Extracting portable files..." -ForegroundColor Yellow
        
        # Run installer in silent mode to extract files
        $extractArgs = "/VERYSILENT /DIR=`"$winscpDirectory`" /NOCANCEL /NORESTART"
        $process = Start-Process -FilePath $installerPath -ArgumentList $extractArgs -Wait -PassThru
        
        # Clean up
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        
        Write-Log "WinSCP installed successfully to: $winscpDirectory" "SUCCESS"
        Write-Host ""
        return $true
    }
    catch {
        Write-Log "Failed to download WinSCP: $($_.Exception.Message)" "ERROR"
        Write-Host ""
        Write-Host "Please download WinSCP manually from: https://winscp.net/" -ForegroundColor Yellow
        Write-Host "Extract to: $winscpDirectory" -ForegroundColor Yellow
        return $false
    }
}

function Get-FtpCredentials {
    Write-Host ""
    Write-Host "FTP Server: $defaultFtpServer" -ForegroundColor Cyan
    Write-Host ""
    
    $ftpUser = Read-Host "Enter FTP username"
    if ([string]::IsNullOrWhiteSpace($ftpUser)) {
        Write-Log "ERROR: FTP username cannot be empty." "ERROR"
        Write-Host "`nPress any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
    
    $ftpPass = Read-Host "Enter FTP password" -AsSecureString
    $plainPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ftpPass))
    
    return @{
        Server = $defaultFtpServer
        User = $ftpUser
        Pass = $plainPass
    }
}

function Get-LocalPath {
    Write-Host ""
    $localPath = Read-Host "Enter local backup directory path (e.g., C:\VOLID01)"
    
    if ([string]::IsNullOrWhiteSpace($localPath)) {
        Write-Log "ERROR: Local path cannot be empty." "ERROR"
        Write-Host "`nPress any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
    
    $localPath = $localPath.TrimEnd('\')
    
    if (-not (Test-Path $localPath)) {
        Write-Log "ERROR: Local path does not exist: $localPath" "ERROR"
        Write-Host "`nPress any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
    
    return $localPath
}

function Get-FtpFileList {
    param (
        [hashtable]$ftpCreds
    )
    
    Write-Log "Connecting to FTP server: $($ftpCreds.Server)..."
    
    # Create WinSCP script
    $scriptPath = Join-Path $env:TEMP "winscp_list.txt"
    
    $script = @"
option batch abort
option confirm off
open ftp://$($ftpCreds.User):$($ftpCreds.Pass)@$($ftpCreds.Server)/
ls
exit
"@
    
    $script | Out-File -FilePath $scriptPath -Encoding ASCII
    
    try {
        # Run WinSCP
        $output = & $winscpExe /script=$scriptPath 2>&1
        
        # Parse output for files
        $files = @()
        $inListing = $false
        
        foreach ($line in $output) {
            $lineStr = $line.ToString()
            
            # Look for file listings (start with date or permissions)
            if ($lineStr -match '^\d{2}-\d{2}-\d{2}' -or $lineStr -match '^-rw') {
                $inListing = $true
                
                # Extract filename (last part after spaces)
                $parts = $lineStr -split '\s+', 9
                if ($parts.Count -ge 9) {
                    $fileName = $parts[8]
                    $fileSize = 0
                    
                    # Try to get size (usually 5th column)
                    if ($parts.Count -ge 5) {
                        [long]::TryParse($parts[4], [ref]$fileSize) | Out-Null
                    }
                    
                    $files += [PSCustomObject]@{
                        Name = $fileName
                        Size = $fileSize
                    }
                }
            }
        }
        
        # Clean up
        Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
        
        Write-Log "Retrieved $($files.Count) files from FTP server." "SUCCESS"
        return $files
    }
    catch {
        Write-Log "ERROR: Failed to list FTP files: $($_.Exception.Message)" "ERROR"
        Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
        return $null
    }
}

function Compare-Files {
    param (
        [string]$localPath,
        [array]$ftpFiles
    )
    
    Write-Log "Scanning local directory for *-cd.spi files..."
    
    $localFiles = Get-ChildItem -Path $localPath -File -Filter "*-cd.spi" -ErrorAction SilentlyContinue
    
    if (-not $localFiles) {
        Write-Log "No *-cd.spi files found in local directory." "WARN"
        return @()
    }
    
    Write-Log "Found $($localFiles.Count) local *-cd.spi files."
    
    $missingFiles = @()
    
    foreach ($localFile in $localFiles) {
        $foundOnFtp = $ftpFiles | Where-Object { $_.Name -eq $localFile.Name }
        
        if (-not $foundOnFtp) {
            $missingFiles += [PSCustomObject]@{
                Name = $localFile.Name
                Size = $localFile.Length
                Date = $localFile.LastWriteTime
                FullPath = $localFile.FullName
            }
        }
    }
    
    Write-Log "Found $($missingFiles.Count) files on local but not on FTP."
    return $missingFiles
}

function Show-SyncReport {
    param (
        [array]$missingFiles,
        [string]$localPath
    )
    
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "                   FTP Sync Report                               " -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Local Source:       " -NoNewline -ForegroundColor Gray
    Write-Host $localPath -ForegroundColor White
    Write-Host "FTP Destination:    " -NoNewline -ForegroundColor Gray
    Write-Host $defaultFtpServer -ForegroundColor White
    Write-Host "Filter:             " -NoNewline -ForegroundColor Gray
    Write-Host "*-cd.spi" -ForegroundColor White
    Write-Host ""
    
    if ($missingFiles.Count -eq 0) {
        Write-Host "All files are in sync! No files need uploading." -ForegroundColor Green
        Write-Host ""
        return
    }
    
    Write-Host "Files on SOURCE but NOT on DESTINATION:" -ForegroundColor Yellow
    Write-Host "-----------------------------------------------------------------" -ForegroundColor Gray
    Write-Host ""
    
    $totalSize = 0
    $index = 1
    
    foreach ($file in $missingFiles) {
        $sizeMB = [math]::Round($file.Size / 1MB, 2)
        $sizeGB = [math]::Round($file.Size / 1GB, 2)
        $sizeStr = if ($sizeGB -ge 1) { "$sizeGB GB" } else { "$sizeMB MB" }
        
        $dateStr = $file.Date.ToString("yyyy-MM-dd HH:mm")
        
        Write-Host "[$index] " -NoNewline -ForegroundColor Cyan
        Write-Host "$($file.Name)" -NoNewline -ForegroundColor White
        Write-Host "  ($sizeStr)" -NoNewline -ForegroundColor Gray
        Write-Host "  $dateStr" -ForegroundColor DarkGray
        
        $totalSize += $file.Size
        $index++
    }
    
    Write-Host ""
    Write-Host "-----------------------------------------------------------------" -ForegroundColor Gray
    $totalGB = [math]::Round($totalSize / 1GB, 2)
    Write-Host "Total: $($missingFiles.Count) files ($totalGB GB)" -ForegroundColor Cyan
    Write-Host ""
}

function Upload-FilesWithWinSCP {
    param (
        [array]$files,
        [hashtable]$ftpCreds
    )
    
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "              Uploading Files with WinSCP                        " -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Create WinSCP script
    $scriptPath = Join-Path $env:TEMP "winscp_upload.txt"
    
    $scriptContent = @"
option batch abort
option confirm off
open ftp://$($ftpCreds.User):$($ftpCreds.Pass)@$($ftpCreds.Server)/
"@
    
    foreach ($file in $files) {
        $scriptContent += "`nput `"$($file.FullPath)`""
    }
    
    $scriptContent += "`nexit"
    
    $scriptContent | Out-File -FilePath $scriptPath -Encoding ASCII
    
    try {
        Write-Log "Starting upload of $($files.Count) files..."
        
        # Run WinSCP
        $output = & $winscpExe /script=$scriptPath /log="$logDirectory\winscp.log" 2>&1
        
        # Check for success
        $successCount = 0
        $failCount = 0
        
        foreach ($line in $output) {
            if ($line -match 'Upload of file.*finished') {
                $successCount++
            }
            elseif ($line -match 'Error|Failed') {
                $failCount++
            }
        }
        
        # Clean up
        Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
        
        Write-Host ""
        Write-Host "-----------------------------------------------------------------" -ForegroundColor Gray
        Write-Host "Upload Summary:" -ForegroundColor Cyan
        Write-Host "  Total Files: $($files.Count)" -ForegroundColor White
        Write-Host "  Successful: $successCount" -ForegroundColor Green
        
        if ($failCount -gt 0) {
            Write-Host "  Failed: $failCount" -ForegroundColor Red
            Write-Host ""
            Write-Host "Check log for details: $logDirectory\winscp.log" -ForegroundColor Yellow
        }
        
        Write-Host "-----------------------------------------------------------------" -ForegroundColor Gray
        Write-Host ""
        
        Write-Log "Upload complete: $successCount successful, $failCount failed" "SUCCESS"
    }
    catch {
        Write-Log "ERROR: Upload failed: $($_.Exception.Message)" "ERROR"
        Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
    }
}

# --- Main Script ---

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "                   FTP Sync Tool (WinSCP)                        " -ForegroundColor White
Write-Host "              StorageCraft Backup Synchronization                " -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "FTP Sync Tool started (WinSCP-based)"

# Check for WinSCP
if (-not (Test-WinSCP)) {
    if (-not (Download-WinSCP)) {
        Write-Host "`nPress any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

# Get credentials
$ftpCreds = Get-FtpCredentials

# Get local path
$localPath = Get-LocalPath

Write-Host ""
Write-Host "Retrieving FTP file list..." -ForegroundColor Yellow

# Get FTP files
$ftpFiles = Get-FtpFileList -ftpCreds $ftpCreds

if ($null -eq $ftpFiles) {
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Compare files
$missingFiles = Compare-Files -localPath $localPath -ftpFiles $ftpFiles

# Show report
Show-SyncReport -missingFiles $missingFiles -localPath $localPath

if ($missingFiles.Count -eq 0) {
    Write-Host "Press any key to return to menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 0
}

# Ask if user wants to upload
Write-Host "Options:" -ForegroundColor Cyan
Write-Host "  1. Upload ALL missing files (using WinSCP)" -ForegroundColor White
Write-Host "  2. Return to menu" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Select an option (1-2)"

switch ($choice) {
    "1" {
        Upload-FilesWithWinSCP -files $missingFiles -ftpCreds $ftpCreds
    }
    "2" {
        Write-Host "Returning to menu..." -ForegroundColor Yellow
    }
    default {
        Write-Host "Invalid option. Returning to menu..." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Press any key to return to menu..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Log "FTP Sync Tool completed"
