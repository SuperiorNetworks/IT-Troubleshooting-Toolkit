<#
.SYNOPSIS
HP M404dn Printer Troubleshooter - Submenu for HP M404dn repair tools

.DESCRIPTION
Name: hp_m404dn_troubleshooter.ps1
Version: 3.9.0
Purpose: Centralized submenu for HP LaserJet Pro M404dn printer troubleshooting and repair.
         Provides access to connectivity diagnostics, print spooler repair, and a clean
         driver reinstall workflow from the IT Troubleshooting Toolkit.
Path: C:\ITTools\Scripts\hp_m404dn_troubleshooter.ps1
Copyright: 2026 Superior Networks LLC

Key Features:
- Launches connectivity testing for network and USB-connected HP M404dn printers
- Launches print spooler repair for stuck jobs and hung spooler service issues
- Launches clean printer, port, and driver removal and reinstall workflow
- Verbose console output and logging for every menu selection
- Superior Networks LLC branding and unified toolkit version display

Input:
- User menu selection (1-3 or B for Back)

Output:
- Launched printer troubleshooting sub-scripts
- Log entries in C:\ITTools\Scripts\Logs\hp_m404dn_troubleshooter_log.txt
- Master audit log entries for submenu activity

Dependencies:
- Windows PowerShell 4.0 or higher
- hp_m404dn_connectivity_test.ps1
- hp_m404dn_spooler_repair.ps1
- hp_m404dn_driver_reinstall.ps1
- Administrator privileges for spooler repair and driver reinstall

Change Log:
2026-09-14 v3.9.0 - Added HP M404dn Printer Troubleshooter submenu (Dwain Henderson Jr)
#>

$ErrorActionPreference = "SilentlyContinue"

# Configuration
$installPath = "C:\ITTools\Scripts"
$connectivityScriptName = "hp_m404dn_connectivity_test.ps1"
$spoolerScriptName = "hp_m404dn_spooler_repair.ps1"
$driverScriptName = "hp_m404dn_driver_reinstall.ps1"
$logDirectory = Join-Path $installPath "Logs"
$logFile = Join-Path $logDirectory "hp_m404dn_troubleshooter_log.txt"
$auditLogFile = Join-Path $logDirectory "master_audit_log.txt"

# Ensure log directory exists
if (-not (Test-Path $logDirectory)) { New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null }

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

function Write-AuditLog {
    param (
        [string]$action,
        [string]$details = "",
        [string]$level = "INFO",
        [string]$errorMessage = ""
    )
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $username = $env:USERNAME
        $computername = $env:COMPUTERNAME
        $logEntry = "[$timestamp] [$level] $username@$computername`n"
        $logEntry += "  Action: $action`n"
        if ($details) { $logEntry += "  Details: $details`n" }
        if ($errorMessage) { $logEntry += "  Error: $errorMessage`n" }
        $logEntry += "  $("="*70)`n"
        Add-Content -Path $auditLogFile -Value $logEntry -ErrorAction SilentlyContinue
    } catch {}
}

function Show-HPM404dnMenu {
    Clear-Host

    # Read master toolkit version dynamically from launch_menu.ps1
    $toolkitVersion = "Unknown"
    $launcherPath = Join-Path $installPath "launch_menu.ps1"
    if (Test-Path $launcherPath) {
        $launcherContent = Get-Content $launcherPath -Raw
        if ($launcherContent -match 'Version:\s*(\d+\.\d+\.\d+)') {
            $toolkitVersion = $matches[1]
        }
    }

    Write-Host ""
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host "                     SUPERIOR NETWORKS LLC                        " -ForegroundColor White
    Write-Host "       HP M404dn Printer Troubleshooter - Toolkit v$toolkitVersion          " -ForegroundColor Cyan
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Recommended repair workflow:" -ForegroundColor Gray
    Write-Host "    1. Confirm connectivity, then repair the spooler if jobs are stuck." -ForegroundColor DarkGray
    Write-Host "    2. Reinstall the driver only after connectivity and spooler checks." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    1. Connectivity Test (network / USB diagnostics)" -ForegroundColor Cyan
    Write-Host "    2. Spooler Repair (stuck jobs / hung spooler)" -ForegroundColor Cyan
    Write-Host "    3. Driver Reinstall (clean remove & reinstall)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    B. Back to Main Menu" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Installation Path: $installPath" -ForegroundColor Gray
    Write-Host ""
}

function Run-HPM404dnTool {
    param (
        [string]$scriptName,
        [string]$toolName
    )

    Write-Host "`n=== Launching $toolName ===" -ForegroundColor Cyan
    Write-Log "Launching $scriptName" "INFO"
    Write-AuditLog -action "HP M404dn Troubleshooter" -details "Launching $scriptName"

    $scriptPath = Join-Path $installPath $scriptName
    if (Test-Path $scriptPath) {
        Write-Host "Starting $toolName..." -ForegroundColor Green
        Write-Host "Script: $scriptPath" -ForegroundColor Gray
        Write-Host ""
        & $scriptPath
    } else {
        Write-Log "Script not found: $scriptPath" "ERROR"
        Write-AuditLog -action "HP M404dn Troubleshooter" -level "ERROR" -errorMessage "Script not found: $scriptPath"
        Write-Host "`nError: $scriptName not found!" -ForegroundColor Red
        Write-Host "Expected: $scriptPath" -ForegroundColor Yellow
        Write-Host "`nPlease use Option 1 from the main menu to download and install the toolkit." -ForegroundColor Yellow
        Write-Host "`nPress any key to return to menu..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

Write-Log "HP M404dn Troubleshooter submenu opened." "INFO"
Write-AuditLog -action "HP M404dn Troubleshooter" -details "Submenu opened"

do {
    Show-HPM404dnMenu
    Write-Host "  Select an option (1-3 or B): " -NoNewline -ForegroundColor White
    $choice = Read-Host

    switch ($choice.ToUpper()) {
        '1' {
            Write-Log "Option 1 selected: Connectivity Test" "INFO"
            Run-HPM404dnTool -scriptName $connectivityScriptName -toolName "HP M404dn Connectivity Test"
        }
        '2' {
            Write-Log "Option 2 selected: Spooler Repair" "INFO"
            Run-HPM404dnTool -scriptName $spoolerScriptName -toolName "HP M404dn Spooler Repair"
        }
        '3' {
            Write-Log "Option 3 selected: Driver Reinstall" "INFO"
            Run-HPM404dnTool -scriptName $driverScriptName -toolName "HP M404dn Driver Reinstall"
        }
        'B' {
            Write-Log "User returned to main menu." "INFO"
            Write-AuditLog -action "HP M404dn Troubleshooter" -details "User returned to main menu"
            Write-Host "`nReturning to main menu..." -ForegroundColor Cyan
            exit 0
        }
        default {
            Write-Log "Invalid menu selection: $choice" "WARN"
            Write-Host "`nInvalid selection. Please choose 1-3 or B." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($true)
