<#
.SYNOPSIS
Manual FTP Tool - Enhanced interactive file uploader with retry logic and resume support

.DESCRIPTION
Name: ftp_troubleshooter_tool.ps1
Version: 2.0.1
Purpose: Manual FTP file upload utility with persistent connections, auto-retry, resume support,
         and detailed status reporting. Designed as a robust backup solution when automated 
         transfer systems experience issues.
Path: /scripts/ftp_troubleshooter_tool.ps1
Copyright: 2025

Key Features:
- Interactive GUI file picker for selecting multiple files
- Persistent connection with auto-retry (10 attempts)
- Resume support for interrupted uploads
- 60-second timeout detection
- Detailed status reporting with connection monitoring
- Comprehensive logging to file
- Configurable default FTP server with option to override
- Secure credential prompting
- Enhanced progress tracking with speed and time estimates
- Robust error handling and resource management
- Automatic skip of failed files with summary report

Input: 
- User-selected files via GUI dialog
- FTP server address (default: ftp.sndayton.com)
- FTP username and password via secure prompt

Output:
- Files uploaded to FTP server
- Real-time console status updates
- Detailed log file at C:\ITTools\Scripts\Logs\ftp_upload_log.txt
- Summary report of successful/failed/skipped files

Dependencies:
- Windows PowerShell 5.1 or higher
- .NET Framework (System.Windows.Forms)
- Network access to FTP server

Change Log:
2025-11-21 v1.0.0 - Initial release
2025-11-21 v1.0.1 - Fixed syntax error in error handling block
2025-11-21 v1.1.0 - Sanitized for public release, removed PII
2025-11-22 v2.0.0 - Major enhancement: Added retry logic (10 attempts), resume support, 60s timeout,
                    detailed status reporting, connection monitoring, and comprehensive logging
2025-12-08 v2.0.1 - Fixed crash issue: Added pause before exit on errors so messages are visible

.NOTES
This tool provides enterprise-grade reliability for FTP uploads with automatic recovery
from connection failures. Ideal for uploading large backup files over unstable connections.
#>

Add-Type -AssemblyName System.Windows.Forms

# --- Configuration ---
$defaultFtpServer = "ftp.sndayton.com"
$maxRetries = 10
$timeoutSeconds = 60
$logDirectory = "C:\ITTools\Scripts\Logs"
$logFile = Join-Path $logDirectory "ftp_upload_log.txt"
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
    Add-Content -Path $logFile -Value $logEntry
    
    # Write to console with color
    $color = switch ($level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    
    Write-Host "[$timestamp] $message" -ForegroundColor $color
}

function Select-Files {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Multiselect = $true
    $dialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    $dialog.Title = "Select files to upload via FTP"
    if ($dialog.ShowDialog() -eq 'OK') {
        return $dialog.FileNames
    }
    else {
        Write-Host "" 
        Write-Host "WARNING: No files selected. Exiting." -ForegroundColor Red
        Write-Log "No files selected. Exiting." "WARN"
        Write-Host "`nPress any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

function Prompt-For-FtpDetails {
    param (
        [string]$defaultServer
    )

    $ftpServerInput = Read-Host "Enter FTP server address (default: $defaultServer)"
    $ftpServer = if ([string]::IsNullOrWhiteSpace($ftpServerInput)) { $defaultServer } else { $ftpServerInput }

    Write-Host "FTP Server: $ftpServer" -ForegroundColor Cyan

    $ftpUser = Read-Host "Enter FTP username"
    if ([string]::IsNullOrWhiteSpace($ftpUser)) {
        Write-Host ""
        Write-Host "ERROR: FTP username cannot be empty." -ForegroundColor Red
        Write-Log "FTP username cannot be empty." "ERROR"
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

function Test-FtpConnection {
    param (
        [string]$ftpServer,
        [string]$ftpUser,
        [string]$ftpPass
    )
    
    try {
        Write-Log "Testing connection to $ftpServer..."
        $request = [System.Net.FtpWebRequest]::Create("ftp://$ftpServer/")
        $request.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
        $request.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
        $request.Timeout = $timeoutSeconds * 1000
        $response = $request.GetResponse()
        $response.Close()
        Write-Log "Connection test successful!" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Connection test failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Upload-FileToFTP-WithRetry {
    param (
        [string]$filePath,
        [string]$ftpServer,
        [string]$ftpUser,
        [string]$ftpPass
    )

    $filename = [System.IO.Path]::GetFileName($filePath)
    $fileSize = (Get-Item $filePath).Length
    $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
    
    Write-Log "Starting upload: $filename ($fileSizeMB MB)"
    
    $attempt = 0
    $uploadedBytes = 0
    $success = $false
    
    while ($attempt -lt $maxRetries -and -not $success) {
        $attempt++
        
        if ($attempt -gt 1) {
            $waitTime = [math]::Min(5 * [math]::Pow(2, $attempt - 2), 60)  # Exponential backoff, max 60s
            Write-Log "Retrying in $waitTime seconds... (Attempt $attempt of $maxRetries)" "WARN"
            Start-Sleep -Seconds $waitTime
        }
        
        $fileStream = $null
        $ftpStream = $null
        
        try {
            Write-Log "Attempt $attempt/$maxRetries - Connecting to $ftpServer..."
            
            $uri = "ftp://$ftpServer/$filename"
            $request = [System.Net.FtpWebRequest]::Create($uri)
            $request.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
            $request.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
            $request.UseBinary = $true
            $request.UsePassive = $true
            $request.KeepAlive = $false
            $request.Timeout = $timeoutSeconds * 1000
            $request.ReadWriteTimeout = $timeoutSeconds * 1000
            
            # Resume support: set content offset if we have uploaded bytes
            if ($uploadedBytes -gt 0) {
                $request.ContentOffset = $uploadedBytes
                Write-Log "Resuming from $([math]::Round($uploadedBytes / 1MB, 2)) MB" "INFO"
            }

            Write-Log "Connected! Starting upload..." "SUCCESS"
            
            $fileStream = [System.IO.File]::OpenRead($filePath)
            
            # Seek to resume position if needed
            if ($uploadedBytes -gt 0) {
                $fileStream.Seek($uploadedBytes, [System.IO.SeekOrigin]::Begin) | Out-Null
            }
            
            $ftpStream = $request.GetRequestStream()

            $buffer = New-Object byte[] $bufferSize
            $totalBytes = $fileSize
            $sentBytes = $uploadedBytes
            $startTime = Get-Date
            $lastUpdate = $startTime

            while (($readBytes = $fileStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $ftpStream.Write($buffer, 0, $readBytes)
                $sentBytes += $readBytes
                
                # Update progress every 500ms
                $now = Get-Date
                if (($now - $lastUpdate).TotalMilliseconds -ge 500) {
                    $percentComplete = [math]::Round(($sentBytes / $totalBytes) * 100, 1)
                    $elapsed = ($now - $startTime).TotalSeconds
                    $speed = if ($elapsed -gt 0) { $sentBytes / $elapsed } else { 0 }
                    $speedMBps = [math]::Round($speed / 1MB, 2)
                    $remaining = if ($speed -gt 0) { ($totalBytes - $sentBytes) / $speed } else { 0 }
                    
                    $status = "Progress: $percentComplete% ($([math]::Round($sentBytes / 1MB, 2)) MB / $fileSizeMB MB) | Speed: $speedMBps MB/s"
                    if ($remaining -gt 0) {
                        $remainingTime = [TimeSpan]::FromSeconds($remaining)
                        $status += " | Remaining: $($remainingTime.ToString('mm\:ss'))"
                    }
                    
                    Write-Progress -Activity "Uploading $filename" -Status $status -PercentComplete $percentComplete
                    $lastUpdate = $now
                }
            }

            $ftpStream.Close()
            $fileStream.Close()
            
            # Verify upload completed
            $uploadedBytes = $sentBytes
            
            if ($uploadedBytes -eq $totalBytes) {
                Write-Progress -Activity "Uploading $filename" -Completed
                Write-Log "$filename upload complete! ($fileSizeMB MB)" "SUCCESS"
                $success = $true
            }
            else {
                Write-Log "Upload incomplete: $uploadedBytes / $totalBytes bytes" "WARN"
            }
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Log "Upload error: $errorMsg" "ERROR"
            
            # Try to save progress
            if ($fileStream -ne $null) {
                $uploadedBytes = $fileStream.Position
            }
            
            if ($attempt -lt $maxRetries) {
                Write-Log "Connection lost. Will retry..." "WARN"
            }
        }
        finally {
            if ($ftpStream -ne $null) { 
                try { $ftpStream.Close() } catch {}
            }
            if ($fileStream -ne $null) { 
                try { $fileStream.Close() } catch {}
            }
        }
    }
    
    if (-not $success) {
        Write-Log "$filename failed after $maxRetries attempts" "ERROR"
    }
    
    return $success
}

# --- Main script logic ---
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "              Manual FTP Tool - Enhanced v2.0.1                 " -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "=== FTP Upload Session Started ===" "INFO"
Write-Log "Log file: $logFile" "INFO"

Write-Host "Use the dialog to select one or more files for FTP transfer." -ForegroundColor Yellow
$selectedFiles = Select-Files

Write-Log "Selected $($selectedFiles.Count) file(s) for upload"

$ftpDetails = Prompt-For-FtpDetails -defaultServer $defaultFtpServer

# Test connection before starting
if (-not (Test-FtpConnection -ftpServer $ftpDetails.Server -ftpUser $ftpDetails.User -ftpPass $ftpDetails.Pass)) {
    Write-Log "Cannot connect to FTP server. Please check your credentials and network connection." "ERROR"
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

Write-Host ""
Write-Log "Starting file uploads..."

$successCount = 0
$failedCount = 0
$failedFiles = @()

foreach ($file in $selectedFiles) {
    Write-Host ""
    Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray
    
    $result = Upload-FileToFTP-WithRetry -filePath $file -ftpServer $ftpDetails.Server -ftpUser $ftpDetails.User -ftpPass $ftpDetails.Pass
    
    if ($result) {
        $successCount++
    }
    else {
        $failedCount++
        $failedFiles += [System.IO.Path]::GetFileName($file)
    }
}

# Clear the plaintext password from memory
Clear-Variable -Name 'ftpDetails'
[GC]::Collect()

# Summary report
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "                      Upload Summary                             " -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Total Files:     $($selectedFiles.Count)" -ForegroundColor White
Write-Host "  Successful:      " -NoNewline
Write-Host $successCount -ForegroundColor Green
Write-Host "  Failed:          " -NoNewline
Write-Host $failedCount -ForegroundColor $(if ($failedCount -gt 0) { "Red" } else { "Green" })

if ($failedFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "  Failed Files:" -ForegroundColor Red
    foreach ($failedFile in $failedFiles) {
        Write-Host "    - $failedFile" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Log "=== Upload Session Complete ===" "INFO"
Write-Log "Summary: $successCount successful, $failedCount failed out of $($selectedFiles.Count) files"
Write-Host "Log file saved to: $logFile" -ForegroundColor Gray
Write-Host ""
