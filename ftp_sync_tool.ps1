<#
.SYNOPSIS
FTP Sync - WinSCP-based backup synchronization tool

.DESCRIPTION
Name: ftp_sync_tool.ps1
Version: 2.1.3
Purpose: Compare local backup directory with FTP server using WinSCP.
         Automatically downloads WinSCP portable if not present.
         Pre-configured for ftp.sndayton.com with StorageCraft file filtering.
Path: C:\ITTools\Scripts\ftp_sync_tool.ps1
Copyright: 2026

Key Features:
- Automatic WinSCP portable download and setup
- Pre-configured for ftp.sndayton.com
- Recursive folder scanning on both local and FTP sides
- Compare local vs FTP files (filtered for .spi, .spf only) including subdirectories
- Mirrors local folder structure on FTP during upload
- Display files missing on FTP
- Bulk upload missing files using WinSCP (preserving subfolder paths)
- Manual file list upload option
- Professional WinSCP synchronization engine
- Comprehensive logging

Input:
- FTP username and password
- Local backup directory path

Output:
- Comparison report showing missing files (with relative paths)
- Option to upload selected files via WinSCP (preserving folder structure)
- Detailed log file

Dependencies:
- Windows PowerShell 4.0 or higher
- Internet access (for WinSCP download if needed)
- Network access to FTP server

Change Log:
2025-12-08 v2.0.0 - Rewritten to use WinSCP for reliability
2026-04-14 v2.0.1 - Updated filter to include all StorageCraft backup types (.spi, .spf, .spa)
2026-04-14 v2.0.2 - Added manual file list upload option
2026-04-14 v2.0.3 - Fixed early exit when FTP returns 0 files; added raw WinSCP output logging
2026-04-15 v2.1.0 - Added recursive folder scanning on both local and FTP sides;
                    upload now preserves subfolder structure on FTP destination
2026-04-15 v2.1.1 - Fixed comparison hang by using hash table for O(1) lookup instead of O(n^2) loop
2026-04-15 v2.1.2 - Fixed upload abort caused by '550 Directory already exists' on mkdir;
                    changed batch mode to 'continue' and deduplicated mkdir calls per subfolder
2026-04-15 v2.1.3 - Removed .spa from sync filter; only .spi and .spf files are synced

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
        
        if ($process.ExitCode -eq 0 -and (Test-Path $winscpExe)) {
            Write-Log "WinSCP installed successfully to: $winscpDirectory" "SUCCESS"
            Write-Host ""
            return $true
        } else {
            Write-Log "WinSCP installation failed or executable not found at $winscpExe" "ERROR"
            Write-Host ""
            return $false
        }
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

# Helper: recursively list all files on FTP by walking each subdirectory
function Get-FtpFileListRecursive {
    param (
        [hashtable]$ftpCreds,
        [string]$ftpFolder = "/"
    )

    $scriptPath = Join-Path $env:TEMP "winscp_list_recursive.txt"

    # Build a WinSCP script that lists the given folder
    $script = @"
option batch abort
option confirm off
open ftp://$($ftpCreds.User):$($ftpCreds.Pass)@$($ftpCreds.Server)/
ls $ftpFolder
exit
"@

    $script | Out-File -FilePath $scriptPath -Encoding ASCII

    $allFiles   = @()
    $subFolders = @()

    try {
        $output = & $winscpExe /script=$scriptPath 2>&1
        Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue

        # Log raw output only for root to avoid flooding the log
        if ($ftpFolder -eq "/") {
            Write-Log "--- RAW WINSCP OUTPUT START ---"
            foreach ($line in $output) { Write-Log $line.ToString() }
            Write-Log "--- RAW WINSCP OUTPUT END ---"
        }

        foreach ($line in $output) {
            $lineStr = $line.ToString()

            # Unix-style listing: permissions + size + date + name
            # e.g.  drwxr-xr-x   0 Apr 14 21:45:00 2026 SN-RLS08
            #       -rw-r--r-- 1234 Apr 14 21:45:00 2026 backup.spi
            if ($lineStr -match '^([d-])') {
                $isDir = ($Matches[1] -eq 'd')

                # Split on whitespace; name is the last token
                $parts = $lineStr -split '\s+'
                $name  = $parts[-1]

                # Skip . and .. entries
                if ($name -eq '.' -or $name -eq '..') { continue }

                # Normalise folder path
                $cleanFolder = $ftpFolder.TrimEnd('/')
                $fullPath    = "$cleanFolder/$name"

                if ($isDir) {
                    $subFolders += $fullPath
                } else {
                    # Only track backup files
                    if ($name -match '\.(spi|spf)$') {
                        $allFiles += [PSCustomObject]@{
                            Name         = $name
                            RelativePath = $fullPath   # e.g. /SN-RLS08/backup.spi
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-Log "ERROR listing FTP folder '$ftpFolder': $($_.Exception.Message)" "ERROR"
        Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
    }

    # Recurse into each discovered subdirectory
    foreach ($sub in $subFolders) {
        Write-Log "  Scanning FTP subfolder: $sub"
        $subFiles = Get-FtpFileListRecursive -ftpCreds $ftpCreds -ftpFolder $sub
        $allFiles += $subFiles
    }

    return $allFiles
}

function Get-FtpFileList {
    param (
        [hashtable]$ftpCreds
    )
    
    Write-Log "Connecting to FTP server: $($ftpCreds.Server)..."
    Write-Log "Scanning FTP server recursively (including all subfolders)..."

    $files = Get-FtpFileListRecursive -ftpCreds $ftpCreds -ftpFolder "/"

    Write-Log "Retrieved $($files.Count) backup file(s) from FTP server (all folders)." "SUCCESS"
    return $files
}

function Compare-Files {
    param (
        [string]$localPath,
        [array]$ftpFiles
    )
    
    Write-Log "Scanning local directory recursively for StorageCraft backup files (.spi, .spf)..."
    
    # PowerShell 4.0 compatible recursive scan
    $localFiles = Get-ChildItem -Path $localPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Extension -match '\.(spi|spf)$'
    }
    
    if (-not $localFiles) {
        Write-Log "No StorageCraft backup files found in local directory." "WARN"
        return @()
    }
    
    Write-Log "Found $($localFiles.Count) local backup file(s) (including subfolders)."
    
    # Build a hash table of FTP files for O(1) lookup
    Write-Log "Building hash table for fast comparison..."
    $ftpHashTable = @{}
    foreach ($ftpFile in $ftpFiles) {
        if ($ftpFile.RelativePath) {
            $key = $ftpFile.RelativePath.TrimStart('/')
            $ftpHashTable[$key] = $true
        }
    }
    
    $missingFiles = @()
    
    Write-Log "Comparing local files against FTP hash table..."
    foreach ($localFile in $localFiles) {
        # Build the relative path from the local root  (e.g. SN-RLS08\backup.spi)
        $relativePath = $localFile.FullName.Substring($localPath.Length).TrimStart('\').Replace('\', '/')

        # Check if this relative path exists on the FTP side using the hash table
        if (-not $ftpHashTable.ContainsKey($relativePath)) {
            $missingFiles += [PSCustomObject]@{
                Name         = $localFile.Name
                RelativePath = $relativePath          # e.g. SN-RLS08/backup.spi
                Size         = $localFile.Length
                Date         = $localFile.LastWriteTime
                FullPath     = $localFile.FullName
            }
        }
    }
    
    Write-Log "Found $($missingFiles.Count) file(s) on local but not on FTP."
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
    Write-Host "*.spi, *.spf (all subfolders)" -ForegroundColor White
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
        Write-Host "$($file.RelativePath)" -NoNewline -ForegroundColor White
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
    
    # Track which FTP subdirs we've already tried to create so we don't
    # issue redundant mkdir commands (one per unique subfolder is enough)
    $createdDirs = @{}

    $scriptContent = @"
option batch continue
option confirm off
open ftp://$($ftpCreds.User):$($ftpCreds.Pass)@$($ftpCreds.Server)/
"@
    
    foreach ($file in $files) {
        # Determine the FTP destination folder from the relative path
        $relPath   = $file.RelativePath   # e.g. SN-RLS08/backup.spi  or  backup.spi
        $slashIdx  = $relPath.LastIndexOf('/')

        if ($slashIdx -gt 0) {
            # File is inside a subfolder — ensure the folder exists then upload there
            $ftpSubDir = "/" + $relPath.Substring(0, $slashIdx)   # e.g. /SN-RLS08

            # Only emit mkdir once per unique subfolder to reduce noise
            if (-not $createdDirs.ContainsKey($ftpSubDir)) {
                # Use -ignoreerrors so '550 Directory already exists' does not abort the session
                $scriptContent += "`ncall mkdir $ftpSubDir"
                $createdDirs[$ftpSubDir] = $true
            }

            $scriptContent += "`nput `"$($file.FullPath)`" `"$ftpSubDir/`""
        } else {
            # File is in the root
            $scriptContent += "`nput `"$($file.FullPath)`""
        }
    }
    
    $scriptContent += "`nexit"
    
    $scriptContent | Out-File -FilePath $scriptPath -Encoding ASCII
    
    try {
        Write-Log "Starting upload of $($files.Count) files (preserving folder structure)..."
        
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
Write-Host "Retrieving FTP file list (scanning all subfolders)..." -ForegroundColor Yellow

# Get FTP files (recursive)
$ftpFiles = Get-FtpFileList -ftpCreds $ftpCreds

if ($null -eq $ftpFiles) {
    $ftpFiles = @() # Ensure it's an array even if null is returned
}

# Compare files
$missingFiles = Compare-Files -localPath $localPath -ftpFiles $ftpFiles

# Show report
Show-SyncReport -missingFiles $missingFiles -localPath $localPath

# Ask if user wants to upload
Write-Host "Options:" -ForegroundColor Cyan

if ($missingFiles.Count -gt 0) {
    Write-Host "  1. Upload ALL missing files (using WinSCP)" -ForegroundColor White
} else {
    Write-Host "  1. Upload ALL missing files (using WinSCP) - [DISABLED: No missing files]" -ForegroundColor DarkGray
}

Write-Host "  2. Manual Upload: Paste a list of filenames to upload" -ForegroundColor White
Write-Host "  3. Return to menu" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Select an option (1-3)"

switch ($choice) {
    "1" {
        if ($missingFiles.Count -gt 0) {
            Upload-FilesWithWinSCP -files $missingFiles -ftpCreds $ftpCreds
        } else {
            Write-Host "No missing files to upload. Returning to menu..." -ForegroundColor Yellow
        }
    }
    "2" {
        Write-Host ""
        Write-Host "Manual File Upload" -ForegroundColor Cyan
        Write-Host "Paste a space-separated list of filenames (e.g., file1.spi file2.spi)" -ForegroundColor Gray
        Write-Host "Files must exist in the local directory: $localPath" -ForegroundColor Gray
        Write-Host ""
        
        $manualInput = Read-Host "Enter filenames"
        
        if (-not [string]::IsNullOrWhiteSpace($manualInput)) {
            # Split by spaces, commas, or semicolons and remove empty entries
            $fileNames = $manualInput -split '[\s,;]+' | Where-Object { $_ -ne '' }
            
            $manualFiles = @()
            $notFoundCount = 0
            
            foreach ($name in $fileNames) {
                # Search recursively for the filename
                $found = Get-ChildItem -Path $localPath -Recurse -File -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) {
                    $relPath = $found.FullName.Substring($localPath.Length).TrimStart('\').Replace('\', '/')
                    $manualFiles += [PSCustomObject]@{
                        Name         = $name
                        RelativePath = $relPath
                        FullPath     = $found.FullName
                    }
                } else {
                    Write-Host "File not found locally: $name" -ForegroundColor Red
                    $notFoundCount++
                }
            }
            
            if ($manualFiles.Count -gt 0) {
                Write-Host ""
                Write-Host "Found $($manualFiles.Count) valid files to upload." -ForegroundColor Green
                if ($notFoundCount -gt 0) {
                    Write-Host "Skipped $notFoundCount invalid files." -ForegroundColor Yellow
                }
                
                $confirm = Read-Host "Proceed with upload? (Y/N)"
                if ($confirm -match '^[Yy]') {
                    Upload-FilesWithWinSCP -files $manualFiles -ftpCreds $ftpCreds
                } else {
                    Write-Host "Upload cancelled." -ForegroundColor Yellow
                }
            } else {
                Write-Host "No valid files found to upload." -ForegroundColor Red
            }
        } else {
            Write-Host "No input provided." -ForegroundColor Yellow
        }
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
