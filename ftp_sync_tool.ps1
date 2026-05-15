<#
.SYNOPSIS
FTP Sync - WinSCP-based backup synchronization tool

.DESCRIPTION
Name: ftp_sync_tool.ps1
Version: 3.7.13
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
- Stall detection: 120-second timeout per file; auto-deletes partial and retries once
- Failed file list displayed at end of upload session
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

2026-05-15 v3.7.13 - Fixed 'Retrieved 0 backup file(s)': WinSCP scripting mode
                    does not support 'ls -R'. Replaced with multi-pass ls that
                    lists root, then each L1 subfolder, then L2 (Incrementals),
                    then L3 - up to 3 levels deep. Temp files now written to
                    C:\ITTools\Scripts\Logs instead of $env:TEMP.
2026-05-15 v3.7.12 - Unified versioning: removed individual script version
                    numbers across all toolkit scripts. All scripts now use
                    the single master toolkit version from launch_menu.ps1.
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
2026-04-15 v2.1.4 - Added per-file stall detection (120s timeout); on stall/error, deletes
                    partial file on FTP and retries once; failed files listed at end
2026-04-15 v2.1.5 - Fixed PowerShell parse error caused by UTF-8 em-dash characters;
                    replaced with ASCII hyphens for full PS 4.0 compatibility
2026-04-15 v2.1.6 - Fixed 'call mkdir' and 'call rm' sending raw FTP commands that FileZilla
                    rejects with 500; replaced with WinSCP native mkdir/rm commands;
                    tightened error detection to avoid false positives from mkdir/rm 550 noise
2026-04-15 v2.1.7 - Fixed false 'NO CONFIRMATION' warnings: replaced unreliable output text
                    parsing with WinSCP exit code detection (0=success, 1=error)
2026-04-15 v2.1.8 - Fixed false ERROR/RETRY loop: exit code is poisoned by 550 MKD response
                    even when upload succeeds; replaced with post-upload FTP stat check
                    to confirm file actually exists before deciding to retry
2026-04-15 v2.1.9 - Added pre-upload local file existence check to prevent WinSCP errors
                    when attempting to upload files that were deleted or moved locally
2026-04-15 v2.2.0 - Updated file filter to match ImageManager replication behavior:
                    Only syncs base (.spf) and unconsolidated .spi files that do NOT
                    have -i#### suffix (raw incrementals). Excludes consolidated
                    -cd (daily), -cw (weekly), -cm (monthly), -cr (rolling) files
                    which ImageManager at the remote site creates independently.
2026-05-15 v2.3.1 - Fixed Test-FtpFileSizeMatch called on every file (not just stalls);
                    removed unreliable exit-code check; added raw stat output logging;
                    stat parse failure now treated as UNKNOWN (success assumed) not FAILED
2026-05-15 v2.3.0 - Fixed false STALL/RETRY loop on large files (18GB+): FTP control
                    channel is dropped by NAT firewall during long data transfer, causing
                    WinSCP to timeout AFTER the file has fully arrived on the server.
                    Replaced Test-FtpFileExists (exit-code only) with
                    Test-FtpFileSizeMatch which opens a FRESH WinSCP session, runs
                    'stat' on the remote file, and compares the remote byte count
                    against the local file size. A size match = SUCCESS, preventing
                    the script from deleting a complete file and re-uploading 18GB.
                    Added WinSCP rawsettings SendBuf=0 SshSimple=0 to all open
                    commands to prevent WinSCP internal buffer timeouts.
2026-05-15 v2.3.1 - Fixed Test-FtpFileSizeMatch being called on EVERY file instead
                    of only on stalled/errored files. This was causing 2x WinSCP
                    sessions per file (2464 connections for 1232 files) and since
                    the stat parse failed, every file was flagged INCOMPLETE and
                    retried then skipped. Fix: only call size-match on stall/error;
                    removed unreliable exit-code check; log raw stat output for
                    diagnostics; treat parse failure as unknown (not incomplete)
                    so normal uploads are not blocked.

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

function Get-FtpFileList {
    param (
        [hashtable]$ftpCreds
    )

    # ------------------------------------------------------------------
    # WinSCP scripting mode does NOT support 'ls -R'.  Instead we use a
    # helper that lists one directory at a time and recurses into every
    # subfolder it finds - up to 3 levels deep (root / L1 / L2).
    # This covers the structure:
    #   /SERVER-02/file.spi
    #   /SERVER-02/Incrementals/file.spi
    #   /VSN-SERVER22/file.spi  etc.
    # ------------------------------------------------------------------

    $logDir   = "C:\ITTools\Scripts\Logs"
    $allFiles = @()

    # Inner helper: run a single 'ls <dir>' via WinSCP and return raw lines
    function Invoke-WinScpLs {
        param ([string]$remoteDir, [hashtable]$creds)
        $tmpScript = "$logDir\winscp_ls_tmp.txt"
        $script = @"
option batch abort
option confirm off
open ftp://$($creds.User):$($creds.Pass)@$($creds.Server)/ -rawsettings FtpPingType=1 FtpPingInterval=10 SendBuf=0 SshSimple=0
ls $remoteDir
exit
"@
        $script | Out-File -FilePath $tmpScript -Encoding ASCII
        $out = & $winscpExe /script=$tmpScript 2>&1
        Remove-Item $tmpScript -Force -ErrorAction SilentlyContinue
        return $out
    }

    # Parse WinSCP ls output: return hashtable with 'files' and 'dirs' arrays
    function Parse-LsOutput {
        param ([array]$lines, [string]$parentDir)
        $result = @{ files = @(); dirs = @() }
        foreach ($line in $lines) {
            $s = $line.ToString()
            if ($s -match '^([d-][rwx-]{9})') {
                $parts = $s -split '\s+'
                $name  = $parts[-1]
                if ($name -eq '.' -or $name -eq '..') { continue }
                $isDir = ($s[0] -eq 'd')
                $fullPath = $parentDir.TrimEnd('/') + '/' + $name
                if ($isDir) {
                    $result.dirs  += $fullPath
                } else {
                    $result.files += $fullPath
                }
            }
        }
        return $result
    }

    Write-Log "Connecting to FTP server: $($ftpCreds.Server)..."
    Write-Log "Scanning FTP server recursively (multi-pass ls, up to 3 levels)..."

    # --- Level 0: list root ---
    Write-Log "  Listing FTP root /..."
    $rootOut    = Invoke-WinScpLs -remoteDir '/' -creds $ftpCreds
    $rootParsed = Parse-LsOutput -lines $rootOut -parentDir '/'

    # Collect any backup files sitting directly in root (unusual but handle it)
    foreach ($f in $rootParsed.files) {
        $fname = $f.Split('/')[-1]
        if ($fname -match '\.(spi|spf)$' -and $fname -notmatch '-i\d+\.spi$') {
            $allFiles += [PSCustomObject]@{ Name = $fname; RelativePath = $f }
        }
    }

    # --- Level 1: list each top-level subfolder (SERVER-02, VSN-*, SQL, etc.) ---
    foreach ($l1Dir in $rootParsed.dirs) {
        $l1Name = $l1Dir.TrimStart('/')
        Write-Log "  Listing $l1Dir ..."
        $l1Out    = Invoke-WinScpLs -remoteDir $l1Dir -creds $ftpCreds
        $l1Parsed = Parse-LsOutput -lines $l1Out -parentDir $l1Dir

        foreach ($f in $l1Parsed.files) {
            $fname = $f.Split('/')[-1]
            if ($fname -match '\.(spi|spf)$' -and $fname -notmatch '-i\d+\.spi$') {
                $allFiles += [PSCustomObject]@{ Name = $fname; RelativePath = $f }
            }
        }

        # --- Level 2: list subfolders inside L1 (e.g. Incrementals) ---
        foreach ($l2Dir in $l1Parsed.dirs) {
            Write-Log "  Listing $l2Dir ..."
            $l2Out    = Invoke-WinScpLs -remoteDir $l2Dir -creds $ftpCreds
            $l2Parsed = Parse-LsOutput -lines $l2Out -parentDir $l2Dir

            foreach ($f in $l2Parsed.files) {
                $fname = $f.Split('/')[-1]
                if ($fname -match '\.(spi|spf)$' -and $fname -notmatch '-i\d+\.spi$') {
                    $allFiles += [PSCustomObject]@{ Name = $fname; RelativePath = $f }
                }
            }

            # --- Level 3: one more level deep just in case ---
            foreach ($l3Dir in $l2Parsed.dirs) {
                Write-Log "  Listing $l3Dir ..."
                $l3Out    = Invoke-WinScpLs -remoteDir $l3Dir -creds $ftpCreds
                $l3Parsed = Parse-LsOutput -lines $l3Out -parentDir $l3Dir
                foreach ($f in $l3Parsed.files) {
                    $fname = $f.Split('/')[-1]
                    if ($fname -match '\.(spi|spf)$' -and $fname -notmatch '-i\d+\.spi$') {
                        $allFiles += [PSCustomObject]@{ Name = $fname; RelativePath = $f }
                    }
                }
            }
        }
    }

    Write-Log "Retrieved $($allFiles.Count) backup file(s) from FTP server (all folders)." "SUCCESS"
    return $allFiles
}

function Compare-Files {
    param (
        [string]$localPath,
        [array]$ftpFiles
    )
    
    Write-Log "Scanning local directory recursively for StorageCraft backup files (.spi, .spf)..."
    
    # PowerShell 4.0 compatible recursive scan
    $localFiles = Get-ChildItem -Path $localPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Extension -match '\.(spi|spf)$' -and $_.Name -notmatch '.*-i\d+\.spi$'
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
    Write-Host "*.spi, *.spf (excluding unconsolidated intra-daily incrementals)" -ForegroundColor White
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

# Helper: run a single WinSCP script file and return raw output lines
function Invoke-WinSCP {
    param ([string]$scriptPath)
    $output = & $winscpExe /script=$scriptPath /log="$logDirectory\winscp.log" 2>&1
    return $output
}

# Helper: verify a file on FTP matches the local file size.
# Opens a FRESH WinSCP session (never reuses the potentially dead upload session).
# Parses the 'stat' output for the remote file size and compares it to the local
# file size in bytes.  Returns $true only when sizes match exactly.
# This correctly handles the large-file FTP stall scenario where the data channel
# completes successfully but the control channel is dropped by a NAT firewall
# before the 226 reply reaches WinSCP - the file is fully on the server even
# though WinSCP reported a timeout.
function Test-FtpFileSizeMatch {
    param (
        [hashtable]$ftpCreds,
        [string]$ftpFullPath,
        [long]$localSizeBytes
    )

    $statScript = Join-Path $env:TEMP "winscp_stat.txt"
    $statContent = @"
option batch abort
option confirm off
open ftp://$($ftpCreds.User):$($ftpCreds.Pass)@$($ftpCreds.Server)/ -rawsettings FtpPingType=1 FtpPingInterval=10 SendBuf=0 SshSimple=0
stat "$ftpFullPath"
exit
"@
    $statContent | Out-File -FilePath $statScript -Encoding ASCII
    $statOutput = & $winscpExe /script=$statScript /log="$logDirectory\winscp_stat.log" 2>&1
    Remove-Item $statScript -Force -ErrorAction SilentlyContinue

    # Log raw stat output for diagnostics (helps identify correct format)
    Write-Log "  STAT RAW OUTPUT:"
    foreach ($line in $statOutput) {
        $lineStr = $line.ToString().Trim()
        if ($lineStr -ne "") { Write-Log "    $lineStr" }
    }

    # NOTE: Do NOT check $LASTEXITCODE here. WinSCP returns exit code 1 for
    # many non-fatal conditions (e.g. a warning during connect). The only
    # reliable signal is whether we can parse a size from the output.

    # Parse the size from WinSCP stat output.
    # WinSCP scripting mode prints a block like:
    #   /path/to/file.spi
    #     Type:       Regular file
    #     Size:       18989239512
    # Match any line containing 'Size:' followed by digits.
    $sizeLine = $statOutput | Where-Object { $_.ToString() -match 'Size:\s+(\d+)' } | Select-Object -First 1
    if ($sizeLine -match 'Size:\s+(\d+)') {
        $remoteSizeBytes = [long]$Matches[1]
        if ($remoteSizeBytes -eq $localSizeBytes) {
            Write-Log "  STAT: Remote size $remoteSizeBytes bytes matches local - transfer complete" "SUCCESS"
            return $true
        } else {
            Write-Log "  STAT: Size mismatch - remote $remoteSizeBytes bytes vs local $localSizeBytes bytes" "WARN"
            return $false
        }
    }

    # Size line not found - could not verify. Treat as UNKNOWN (not failed).
    # Return $null to signal the caller that verification was inconclusive.
    Write-Log "  STAT: Could not parse remote file size from WinSCP output - treating as unknown" "WARN"
    return $null
}

# Helper: build a WinSCP script that uploads ONE file, with stall timeout,
# optional pre-delete of any partial on FTP, and returns the script path
function New-UploadScript {
    param (
        [hashtable]$ftpCreds,
        [string]$localFullPath,
        [string]$ftpDestDir,      # e.g. /SN-RLS08  (empty string = root)
        [string]$ftpDestPath,     # full FTP path e.g. /SN-RLS08/backup.spi
        [bool]$deleteFirst = $false
    )

    $scriptPath = Join-Path $env:TEMP "winscp_upload_single.txt"

    $scriptContent = @"
option batch continue
option confirm off
option transfer binary
option transfer stall 120
open ftp://$($ftpCreds.User):$($ftpCreds.Pass)@$($ftpCreds.Server)/ -rawsettings FtpPingType=1 FtpPingInterval=10 SendBuf=0 SshSimple=0
"@

    # Ensure subfolder exists (silently ignore if already present)
    # WinSCP 'mkdir' is the correct command; 'call mkdir' sends raw FTP which FileZilla rejects
    if ($ftpDestDir -ne "") {
        $scriptContent += "`nmkdir $ftpDestDir"
    }

    # Delete any leftover partial file before uploading
    # WinSCP 'rm' is the correct command; 'call rm' sends raw FTP which FileZilla rejects
    if ($deleteFirst) {
        $scriptContent += "`nrm `"$ftpDestPath`""
    }

    # Upload the file
    if ($ftpDestDir -ne "") {
        $scriptContent += "`nput `"$localFullPath`" `"$ftpDestDir/`""
    } else {
        $scriptContent += "`nput `"$localFullPath`""
    }

    $scriptContent += "`nexit"
    $scriptContent | Out-File -FilePath $scriptPath -Encoding ASCII
    return $scriptPath
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

    Write-Log "Starting upload of $($files.Count) files (stall timeout: 120s, auto-retry on stall)..."

    $successCount  = 0
    $retryCount    = 0
    $failCount     = 0
    $failedFiles   = @()
    $createdDirs   = @{}

    $fileIndex = 0
    foreach ($file in $files) {
        $fileIndex++
        $relPath  = $file.RelativePath   # e.g. SN-RLS08/backup.spi
        $slashIdx = $relPath.LastIndexOf('/')

        if ($slashIdx -gt 0) {
            $ftpSubDir  = "/" + $relPath.Substring(0, $slashIdx)   # /SN-RLS08
            $ftpDest    = $ftpSubDir
        } else {
            $ftpSubDir  = ""
            $ftpDest    = ""
        }
        $ftpFullPath = "/" + $relPath.TrimStart('/')   # /SN-RLS08/backup.spi

        # --- Pre-upload existence check ---
        if (-not (Test-Path $file.FullPath)) {
            Write-Log "[$fileIndex/$($files.Count)] ERROR: Local file not found: $relPath" "ERROR"
            Write-Log "  Skipping upload for this file." "WARN"
            $failCount++
            $failedFiles += "$relPath (Not found on disk)"
            continue
        }

        Write-Log "[$fileIndex/$($files.Count)] Uploading: $relPath"

        # Get local file size once - used for size-match verification after upload
        $localSizeBytes = (Get-Item $file.FullPath).Length

        # --- Attempt 1: normal upload ---
        $scriptPath = New-UploadScript -ftpCreds $ftpCreds `
            -localFullPath $file.FullPath `
            -ftpDestDir $ftpDest `
            -ftpDestPath $ftpFullPath `
            -deleteFirst $false

        $output1 = Invoke-WinSCP -scriptPath $scriptPath
        Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue

        # Check stall or error in output (exit code is unreliable when batch continue absorbs MKD 550)
        $attempt1Stall  = $output1 | Where-Object { $_.ToString() -match 'Timeout|Stall|timed out|no data' }
        $attempt1Error  = $output1 | Where-Object { $_.ToString() -match 'Error|Cannot|failed|refused' }
        $attempt1Problem = $attempt1Stall -or $attempt1Error

        if (-not $attempt1Problem) {
            # Clean upload - no stall or error detected. Mark as success without a stat call.
            Write-Log "  OK: $relPath" "SUCCESS"
            $successCount++
            continue
        }

        # --- Stall or error detected: open a FRESH session and compare remote size to local size.
        # This correctly handles the large-file NAT stall scenario: the 18GB file arrives on the
        # server but WinSCP times out waiting for the 226 reply over the dead control channel.
        # A size match means the transfer completed successfully regardless of the timeout.
        if ($attempt1Stall) {
            Write-Log "  STALL detected on: $relPath  -  verifying remote file size before deciding to retry..." "WARN"
        } else {
            Write-Log "  ERROR detected on: $relPath  -  verifying remote file size before deciding to retry..." "WARN"
        }

        $sizeMatch = Test-FtpFileSizeMatch -ftpCreds $ftpCreds -ftpFullPath $ftpFullPath -localSizeBytes $localSizeBytes

        if ($sizeMatch -eq $true) {
            Write-Log "  STALL-BUT-COMPLETE: $relPath  -  file arrived in full despite control channel timeout" "SUCCESS"
            $successCount++
            continue
        }

        if ($sizeMatch -eq $null) {
            # Stat was inconclusive - could not parse size. Treat as success to avoid
            # unnecessary re-upload. Check winscp_stat.log manually if concerned.
            Write-Log "  STAT-UNKNOWN: $relPath  -  could not verify size; assuming complete" "WARN"
            $successCount++
            continue
        }

        # --- Confirmed size mismatch - file is partial or missing; delete and retry once ---
        $retryCount++
        Write-Log "  INCOMPLETE: $relPath  -  deleting partial and retrying..." "WARN"

        # Attempt 2: delete partial first, then re-upload
        $scriptPath2 = New-UploadScript -ftpCreds $ftpCreds `
            -localFullPath $file.FullPath `
            -ftpDestDir $ftpDest `
            -ftpDestPath $ftpFullPath `
            -deleteFirst $true

        $output2 = Invoke-WinSCP -scriptPath $scriptPath2
        Remove-Item $scriptPath2 -Force -ErrorAction SilentlyContinue

        # Verify retry with size match
        $sizeMatchAfterRetry = Test-FtpFileSizeMatch -ftpCreds $ftpCreds -ftpFullPath $ftpFullPath -localSizeBytes $localSizeBytes

        if ($sizeMatchAfterRetry -eq $true) {
            Write-Log "  RETRY OK: $relPath" "SUCCESS"
            $successCount++
        } elseif ($sizeMatchAfterRetry -eq $null) {
            Write-Log "  RETRY STAT-UNKNOWN: $relPath  -  could not verify; assuming complete" "WARN"
            $successCount++
        } else {
            Write-Log "  RETRY FAILED: $relPath  -  skipping, added to failed list" "ERROR"
            $failCount++
            $failedFiles += $relPath
        }
    }

    # --- Summary ---
    Write-Host ""
    Write-Host "-----------------------------------------------------------------" -ForegroundColor Gray
    Write-Host "Upload Summary:" -ForegroundColor Cyan
    Write-Host "  Total Files:  $($files.Count)" -ForegroundColor White
    Write-Host "  Successful:   $successCount" -ForegroundColor Green
    Write-Host "  Auto-Retried: $retryCount" -ForegroundColor Yellow
    Write-Host "  Failed:       $failCount" -ForegroundColor $(if ($failCount -gt 0) { 'Red' } else { 'Green' })

    if ($failedFiles.Count -gt 0) {
        Write-Host ""
        Write-Host "Files that could not be uploaded after retry:" -ForegroundColor Red
        foreach ($f in $failedFiles) {
            Write-Host "  $f" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "Check log for details: $logDirectory\winscp.log" -ForegroundColor Yellow
    }

    Write-Host "-----------------------------------------------------------------" -ForegroundColor Gray
    Write-Host ""

    Write-Log "Upload complete: $successCount succeeded, $retryCount retried, $failCount failed" "SUCCESS"
}

# --- Main Script ---

# Read master toolkit version dynamically from launch_menu.ps1
$toolkitVersion = "Unknown"
$launcherPath = "C:\ITTools\Scripts\launch_menu.ps1"
if (Test-Path $launcherPath) {
    $launcherContent = Get-Content $launcherPath -Raw
    if ($launcherContent -match 'Version:\s*(\d+\.\d+\.\d+)') {
        $toolkitVersion = $matches[1]
    }
}
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "                   FTP Sync Tool (WinSCP)                        " -ForegroundColor White
Write-Host "         StorageCraft Backup Synchronization - Toolkit v$toolkitVersion  " -ForegroundColor Cyan
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
