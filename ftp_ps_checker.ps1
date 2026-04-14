<#
.SYNOPSIS
FTP PS Checker - Pure PowerShell FTP Connectivity Tester

.DESCRIPTION
Name: ftp_ps_checker.ps1
Version: 1.0.0
Purpose: Tests FTP connectivity, authentication, and directory listing using pure PowerShell
         without relying on external tools like WinSCP. Useful for isolating network/firewall issues.
Path: C:\ITTools\Scripts\ftp_ps_checker.ps1
Copyright: 2025

Key Features:
- Pure PowerShell implementation (no WinSCP dependency)
- Tests TCP Port 21 connectivity
- Tests FTP authentication
- Tests FTP directory listing
- Verbose troubleshooting output
- Comprehensive logging to master audit log

Input: 
- FTP Server Address
- FTP Username
- FTP Password

Output:
- Console status messages (Success/Failure for each step)
- Log entries in C:\ITTools\Scripts\Logs\ftp_ps_checker_log.txt

Dependencies:
- Windows PowerShell 4.0 or higher
- Network access to FTP server

Change Log:
2026-04-14 v1.0.0 - Initial release (Dwain Henderson Jr)
#>

# Configuration
$defaultFtpServer = "ftp.sndayton.com"
$logDirectory = "C:\ITTools\Scripts\Logs"
$logFile = Join-Path $logDirectory "ftp_ps_checker_log.txt"

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
    
    Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
    
    $color = switch ($level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    
    Write-Host $message -ForegroundColor $color
}

function Test-TcpPort {
    param (
        [string]$ComputerName,
        [int]$Port,
        [int]$TimeoutMs = 3000
    )
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connectTask = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
        $waitResult = $connectTask.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        
        if (-not $waitResult) {
            $tcpClient.Close()
            return $false
        }
        
        $tcpClient.EndConnect($connectTask)
        $tcpClient.Close()
        return $true
    }
    catch {
        return $false
    }
}

function Main {
    Clear-Host
    
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "                    FTP PS Checker Tool                          " -ForegroundColor White
    Write-Host "             Pure PowerShell Connectivity Tester                 " -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Log "FTP PS Checker started"
    
    # Get FTP credentials
    Write-Host "FTP Server Configuration" -ForegroundColor Yellow
    Write-Host ""
    
    $ftpServer = Read-Host "FTP Server (default: $defaultFtpServer)"
    if ([string]::IsNullOrWhiteSpace($ftpServer)) {
        $ftpServer = $defaultFtpServer
    }
    
    $ftpUsername = Read-Host "FTP Username"
    if ([string]::IsNullOrWhiteSpace($ftpUsername)) {
        Write-Log "Username cannot be empty." "ERROR"
        Write-Host "`nPress any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    $ftpPassword = Read-Host "FTP Password" -AsSecureString
    $ftpPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ftpPassword))
    
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "                     Running Diagnostics                         " -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $allPassed = $true
    
    # Step 1: Test TCP Port 21
    Write-Host "Step 1: Testing TCP Port 21 connectivity to $ftpServer..." -ForegroundColor Yellow
    Write-Log "Testing TCP Port 21 connectivity to $ftpServer"
    
    if (Test-TcpPort -ComputerName $ftpServer -Port 21) {
        Write-Log "  [PASS] Successfully connected to port 21." "SUCCESS"
    } else {
        Write-Log "  [FAIL] Could not connect to port 21. Check firewall or network routing." "ERROR"
        $allPassed = $false
    }
    
    Write-Host ""
    
    # Step 2: Test FTP Authentication and Directory Listing
    if ($allPassed) {
        Write-Host "Step 2: Testing FTP Authentication and Directory Listing..." -ForegroundColor Yellow
        Write-Log "Testing FTP Authentication and Directory Listing"
        
        try {
            $uri = "ftp://$ftpServer/"
            $request = [System.Net.FtpWebRequest]::Create($uri)
            $request.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
            $request.Credentials = New-Object System.Net.NetworkCredential($ftpUsername, $ftpPasswordPlain)
            $request.UsePassive = $true
            $request.KeepAlive = $false
            $request.Timeout = 10000 # 10 seconds
            
            Write-Log "  Sending FTP request..." "INFO"
            $response = $request.GetResponse()
            $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
            $directoryList = $reader.ReadToEnd()
            
            $reader.Close()
            $response.Close()
            
            Write-Log "  [PASS] Successfully authenticated and retrieved directory listing." "SUCCESS"
            
            Write-Host ""
            Write-Host "Directory Listing Sample (First 5 lines):" -ForegroundColor Gray
            $lines = $directoryList -split "`n"
            $count = 0
            foreach ($line in $lines) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    Write-Host "  $line" -ForegroundColor DarkGray
                    $count++
                    if ($count -ge 5) { break }
                }
            }
            if ($lines.Count -gt 5) {
                Write-Host "  ... ($($lines.Count - 5) more items)" -ForegroundColor DarkGray
            }
            
        } catch {
            Write-Log "  [FAIL] FTP Error: $($_.Exception.Message)" "ERROR"
            if ($_.Exception.InnerException) {
                Write-Log "  Inner Exception: $($_.Exception.InnerException.Message)" "ERROR"
            }
            $allPassed = $false
        }
    } else {
        Write-Host "Step 2: Skipped due to previous failure." -ForegroundColor DarkGray
    }
    
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    
    if ($allPassed) {
        Write-Host "  DIAGNOSTIC RESULT: SUCCESS" -ForegroundColor Green
        Write-Host "  The FTP server is reachable and credentials are valid." -ForegroundColor Green
        Write-Log "Diagnostic Result: SUCCESS" "SUCCESS"
    } else {
        Write-Host "  DIAGNOSTIC RESULT: FAILED" -ForegroundColor Red
        Write-Host "  Please review the errors above." -ForegroundColor Red
        Write-Log "Diagnostic Result: FAILED" "ERROR"
    }
    
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

Main
