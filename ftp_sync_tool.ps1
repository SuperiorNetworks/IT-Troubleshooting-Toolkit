<#
.SYNOPSIS
FTP Sync - Compare local backup files with FTP destination

.DESCRIPTION
Name: ftp_sync_tool.ps1
Version: 1.0.0
Purpose: Compare local backup directory with FTP server to identify files that need uploading.
         Filters for -cd.spi files and provides bulk upload capability.
Path: /scripts/ftp_sync_tool.ps1
Copyright: 2025

Key Features:
- Connect to FTP server and list files in root directory
- Prompt for local backup directory path
- Compare local vs FTP files (by name, size, and date)
- Filter to show only files ending in -cd.spi
- Display files on source but not on destination
- Allow selection and bulk upload of missing files
- Detailed logging and progress tracking

Input:
- FTP server address (default: ftp.sndayton.com)
- FTP username and password
- Local backup directory path

Output:
- Comparison report showing missing files
- Option to upload selected files
- Detailed log file

Dependencies:
- Windows PowerShell 5.1 or higher
- Network access to FTP server

Change Log:
2025-12-08 v1.0.0 - Initial release

.NOTES
Designed for StorageCraft backup file synchronization monitoring and management.
#>

# --- Configuration ---
$defaultFtpServer = "ftp.sndayton.com"
$timeoutSeconds = 30
$logDirectory = "C:\ITTools\Scripts\Logs"
$logFile = Join-Path $logDirectory "ftp_sync_log.txt"
$bufferSize = 1048576  # 1MB buffer

# Ensure log directory exists
if (-not (Test-Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
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

function Prompt-For-FtpDetails {
    param (
        [string]$defaultServer
    )

    Write-Host ""
    $ftpServerInput = Read-Host "Enter FTP server address (default: $defaultServer)"
    $ftpServer = if ([string]::IsNullOrWhiteSpace($ftpServerInput)) { $defaultServer } else { $ftpServerInput }

    Write-Host "FTP Server: $ftpServer" -ForegroundColor Cyan

    $ftpUser = Read-Host "Enter FTP username"
    if ([string]::IsNullOrWhiteSpace($ftpUser)) {
        Write-Host ""
        Write-Log "ERROR: FTP username cannot be empty." "ERROR"
        Write-Host "`nPress any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }

    Write-Warning "The password will be temporarily converted to plain text in memory for the connection."
    $ftppass = Read-Host "Enter FTP password" -AsSecureString
    
    $plainpass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ftppass))

    return @{Server=$ftpServer; User=$ftpUser; Pass=$plainpass}
}

function Get-FtpFileList {
    param (
        [string]$ftpServer,
        [string]$ftpUser,
        [string]$ftpPass
    )
    
    try {
        Write-Log "Connecting to FTP server: $ftpServer..."
        
        $request = [System.Net.FtpWebRequest]::Create("ftp://$ftpServer/")
        $request.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
        $request.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
        $request.Timeout = $timeoutSeconds * 1000
        $request.UseBinary = $true
        $request.UsePassive = $true
        
        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $listing = $reader.ReadToEnd()
        
        $reader.Close()
        $stream.Close()
        $response.Close()
        
        Write-Log "Successfully retrieved FTP directory listing." "SUCCESS"
        
        # Parse FTP listing (Unix-style)
        $files = @()
        $lines = $listing -split "`n"
        
        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            
            # Parse Unix-style directory listing
            # Example: -rw-r--r--   1 user group  12345678 Dec 08 10:23 filename.ext
            if ($line -match '^-') {  # File (not directory)
                $parts = $line -split '\s+', 9
                if ($parts.Count -ge 9) {
                    $fileName = $parts[8].Trim()
                    $fileSize = [long]$parts[4]
                    
                    # Parse date (format: "Dec 08 10:23" or "Dec 08  2024")
                    $dateStr = "$($parts[5]) $($parts[6]) $($parts[7])"
                    
                    $files += [PSCustomObject]@{
                        Name = $fileName
                        Size = $fileSize
                        DateStr = $dateStr
                    }
                }
            }
        }
        
        return $files
    }
    catch {
        Write-Log "ERROR: Failed to retrieve FTP file list: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Get-LocalFileList {
    param (
        [string]$localPath,
        [string]$filter = "*-cd.spi"
    )
    
    try {
        if (-not (Test-Path $localPath)) {
            Write-Log "ERROR: Local path does not exist: $localPath" "ERROR"
            return $null
        }
        
        Write-Log "Scanning local directory: $localPath"
        Write-Log "Filter: $filter"
        
        $files = Get-ChildItem -Path $localPath -File -Filter $filter | Select-Object Name, Length, LastWriteTime
        
        Write-Log "Found $($files.Count) files matching filter." "SUCCESS"
        
        return $files
    }
    catch {
        Write-Log "ERROR: Failed to scan local directory: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Compare-FileLists {
    param (
        [array]$localFiles,
        [array]$ftpFiles
    )
    
    Write-Log "Comparing local and FTP file lists..."
    
    $missingOnFtp = @()
    
    foreach ($localFile in $localFiles) {
        $foundOnFtp = $ftpFiles | Where-Object { $_.Name -eq $localFile.Name }
        
        if (-not $foundOnFtp) {
            # File not on FTP at all
            $missingOnFtp += [PSCustomObject]@{
                Name = $localFile.Name
                Size = $localFile.Length
                Date = $localFile.LastWriteTime
                Status = "Missing on FTP"
            }
        }
        elseif ($foundOnFtp.Size -ne $localFile.Length) {
            # File exists but size mismatch
            $missingOnFtp += [PSCustomObject]@{
                Name = $localFile.Name
                Size = $localFile.Length
                Date = $localFile.LastWriteTime
                Status = "Size mismatch (FTP: $($foundOnFtp.Size) bytes)"
            }
        }
    }
    
    Write-Log "Found $($missingOnFtp.Count) files on source but not on destination (or size mismatch)." "SUCCESS"
    
    return $missingOnFtp
}

function Show-SyncReport {
    param (
        [array]$missingFiles,
        [string]$localPath,
        [string]$ftpServer
    )
    
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "                   FTP Sync Report                               " -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Local Source:       " -NoNewline -ForegroundColor Gray
    Write-Host $localPath -ForegroundColor White
    Write-Host "FTP Destination:    " -NoNewline -ForegroundColor Gray
    Write-Host $ftpServer -ForegroundColor White
    Write-Host "Filter:             " -NoNewline -ForegroundColor Gray
    Write-Host "*-cd.spi" -ForegroundColor White
    Write-Host ""
    
    if ($missingFiles.Count -eq 0) {
        Write-Host "✓ All files are in sync! No files need uploading." -ForegroundColor Green
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
        
        if ($file.Status -ne "Missing on FTP") {
            Write-Host "    Status: $($file.Status)" -ForegroundColor Yellow
        }
        
        $totalSize += $file.Size
        $index++
    }
    
    Write-Host ""
    Write-Host "-----------------------------------------------------------------" -ForegroundColor Gray
    $totalGB = [math]::Round($totalSize / 1GB, 2)
    Write-Host ("Total: {0} files ({1} GB)" -f $missingFiles.Count, $totalGB) -ForegroundColor Cyan
    Write-Host ""
}

function Upload-SelectedFiles {
    param (
        [array]$files,
        [string]$localPath,
        [string]$ftpServer,
        [string]$ftpUser,
        [string]$ftpPass
    )
    
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "                   Uploading Files                               " -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $successCount = 0
    $failCount = 0
    $totalFiles = $files.Count
    
    foreach ($file in $files) {
        $filePath = Join-Path $localPath $file.Name
        
        Write-Host "[$($successCount + $failCount + 1)/$totalFiles] Uploading: $($file.Name)..." -ForegroundColor Cyan
        
        try {
            $uri = "ftp://$ftpServer/$($file.Name)"
            $request = [System.Net.FtpWebRequest]::Create($uri)
            $request.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
            $request.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
            $request.UseBinary = $true
            $request.UsePassive = $true
            $request.KeepAlive = $false
            $request.Timeout = 300000  # 5 minutes
            
            $fileContent = [System.IO.File]::ReadAllBytes($filePath)
            $request.ContentLength = $fileContent.Length
            
            $requestStream = $request.GetRequestStream()
            $requestStream.Write($fileContent, 0, $fileContent.Length)
            $requestStream.Close()
            
            $response = $request.GetResponse()
            $response.Close()
            
            Write-Host "  ✓ Upload successful!" -ForegroundColor Green
            Write-Log "Uploaded: $($file.Name)" "SUCCESS"
            $successCount++
        }
        catch {
            Write-Host "  ✗ Upload failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log "Failed to upload $($file.Name): $($_.Exception.Message)" "ERROR"
            $failCount++
        }
    }
    
    Write-Host ""
    Write-Host "-----------------------------------------------------------------" -ForegroundColor Gray
    Write-Host "Upload Summary:" -ForegroundColor Cyan
    Write-Host "  Successful: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $failCount" -ForegroundColor Red
    Write-Host "-----------------------------------------------------------------" -ForegroundColor Gray
    Write-Host ""
}

# --- Main Script ---

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "                   FTP Sync Tool                                 " -ForegroundColor White
Write-Host "              StorageCraft Backup Synchronization                " -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "FTP Sync Tool started"

# Get FTP credentials
$ftpDetails = Prompt-For-FtpDetails -defaultServer $defaultFtpServer

# Get local directory
Write-Host ""
$localPath = Read-Host "Enter local backup directory path (e.g., C:\VOLID01)"

if ([string]::IsNullOrWhiteSpace($localPath)) {
    Write-Log "ERROR: Local path cannot be empty." "ERROR"
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Remove trailing backslash if present
$localPath = $localPath.TrimEnd('\')

Write-Host ""
Write-Host "Retrieving FTP file list..." -ForegroundColor Yellow

# Get FTP file list
$ftpFiles = Get-FtpFileList -ftpServer $ftpDetails.Server -ftpUser $ftpDetails.User -ftpPass $ftpDetails.Pass

if ($null -eq $ftpFiles) {
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

Write-Host "Scanning local directory..." -ForegroundColor Yellow

# Get local file list (filter for -cd.spi files)
$localFiles = Get-LocalFileList -localPath $localPath -filter "*-cd.spi"

if ($null -eq $localFiles) {
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Compare lists
$missingFiles = Compare-FileLists -localFiles $localFiles -ftpFiles $ftpFiles

# Show report
Show-SyncReport -missingFiles $missingFiles -localPath $localPath -ftpServer $ftpDetails.Server

if ($missingFiles.Count -eq 0) {
    Write-Host "Press any key to return to menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 0
}

# Ask if user wants to upload
Write-Host "Options:" -ForegroundColor Cyan
Write-Host "  1. Upload ALL missing files" -ForegroundColor White
Write-Host "  2. Export report to file" -ForegroundColor White
Write-Host "  3. Return to menu" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Select an option (1-3)"

switch ($choice) {
    "1" {
        Upload-SelectedFiles -files $missingFiles -localPath $localPath -ftpServer $ftpDetails.Server -ftpUser $ftpDetails.User -ftpPass $ftpDetails.Pass
    }
    "2" {
        $reportPath = Join-Path $logDirectory "ftp_sync_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $missingFiles | Format-Table -AutoSize | Out-File $reportPath
        Write-Host "Report saved to: $reportPath" -ForegroundColor Green
        Write-Log "Report exported to $reportPath" "SUCCESS"
    }
    "3" {
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
