<#
.SYNOPSIS
ConnectWise RMM Agent Repair Utility

.DESCRIPTION
Name: connectwise_rmm_repair.ps1
Version: 1.0.0
Purpose: Automates the download and execution of the ConnectWise RMM Platform Watchdog repair utility.
Path: C:\ITTools\Scripts\connectwise_rmm_repair.ps1
Copyright: 2026 Superior Networks LLC

Key Features:
- Downloads platform-watchdog.exe from official source
- Executes healthcheck, healthcheckandrestore, uninstall, and autoupdatecleanup actions
- Comprehensive logging and verbose output
- Administrator privilege enforcement

Input: 
- User menu selection for specific repair action
Output:
- Executed platform-watchdog.exe with chosen parameters
- Verbose console output and log entries
Dependencies:
- Windows PowerShell 4.0 or higher
- Administrator privileges
- Internet connection

Change Log:
2026-07-01 v1.0.0 - Initial release (Dwain Henderson Jr)
#>

$ErrorActionPreference = "Stop"

# Configuration
$installPath = "C:\ITTools\Scripts"
$downloadDir = "C:\ITTools\Downloads\CWRMM"
$downloadUrl = "https://prod.setup.itsupport247.net/windows/RepairUtility/32/Platform-Watchdog/EXE/utility"
$exeName = "platform-watchdog.exe"
$exePath = Join-Path $downloadDir $exeName
$logDirectory = Join-Path $installPath "Logs"
$logFile = Join-Path $logDirectory "cw_rmm_repair_log.txt"

# Ensure directories exist
if (-not (Test-Path $logDirectory)) { New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null }
if (-not (Test-Path $downloadDir)) { New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null }

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to screen with colors
    switch ($Level) {
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
        "WARN"    { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default   { Write-Host $logEntry -ForegroundColor Gray }
    }
    
    # Write to file
    try { Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue } catch {}
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Download-Utility {
    if (Test-Path $exePath) {
        Write-Log "Platform Watchdog utility already exists at $exePath" "INFO"
        return $true
    }
    
    Write-Log "Downloading Platform Watchdog utility from official source..." "INFO"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $downloadUrl -OutFile $exePath -UseBasicParsing
        if (Test-Path $exePath) {
            Write-Log "Download successful." "SUCCESS"
            return $true
        } else {
            Write-Log "Download failed: File not found after download attempt." "ERROR"
            return $false
        }
    } catch {
        Write-Log "Download failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Run-Action {
    param ([string]$ActionArg)
    
    if (-not (Download-Utility)) { return }
    
    Write-Log "Executing action: $ActionArg" "INFO"
    Write-Host "Please wait while the utility runs..." -ForegroundColor Yellow
    
    try {
        $process = Start-Process -FilePath $exePath -ArgumentList "-action=$ActionArg", "-display=yes" -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -eq 0) {
            Write-Log "Action '$ActionArg' completed successfully." "SUCCESS"
        } else {
            Write-Log "Action '$ActionArg' exited with code $($process.ExitCode)." "WARN"
        }
    } catch {
        Write-Log "Failed to execute utility: $($_.Exception.Message)" "ERROR"
    }
}

function Main {
    Clear-Host
    Write-Host ""
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host "                     SUPERIOR NETWORKS LLC                        " -ForegroundColor White
    Write-Host "            ConnectWise RMM Agent Repair Utility                  " -ForegroundColor Cyan
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-Administrator)) {
        Write-Log "Administrator privileges required. Please run PowerShell as Administrator." "ERROR"
        Write-Host "`nPress any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    do {
        Write-Host "  Select an action to perform:" -ForegroundColor White
        Write-Host "    1. Health Check (-action=healthcheck)" -ForegroundColor Green
        Write-Host "    2. Health Check and Restore (-action=healthcheckandrestore)" -ForegroundColor Yellow
        Write-Host "    3. Uninstall Agent (-action=uninstall)" -ForegroundColor Red
        Write-Host "    4. Auto Update Cleanup (-action=autoupdatecleanup)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "    B. Back to Menu" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "  Select an option (1-4 or B): " -NoNewline -ForegroundColor White
        $choice = Read-Host
        
        Write-Host ""
        switch ($choice.ToUpper()) {
            '1' { Run-Action "healthcheck" }
            '2' { Run-Action "healthcheckandrestore" }
            '3' { Run-Action "uninstall" }
            '4' { Run-Action "autoupdatecleanup" }
            'B' { return }
            default { Write-Host "Invalid selection." -ForegroundColor Red }
        }
        
        Write-Host "`nPress any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-Host
    } while ($true)
}

Main
