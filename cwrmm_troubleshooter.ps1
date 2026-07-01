<#
.SYNOPSIS
ConnectWise RMM Troubleshooter - Submenu for ConnectWise RMM and ScreenConnect repair tools

.DESCRIPTION
Name: cwrmm_troubleshooter.ps1
Version: 1.0.0
Purpose: Centralized submenu for ConnectWise RMM and ScreenConnect troubleshooting and repair.
         Provides access to the Platform Watchdog repair utility and the ScreenConnect
         uninstall/cleanup tool. Intended to resolve agent health issues and stuck
         installations (e.g., "ScreenConnect Installation Pending" in the RMM dashboard).
Path: C:\ITTools\Scripts\cwrmm_troubleshooter.ps1
Copyright: 2026 Superior Networks LLC

Key Features:
- Launches ConnectWise RMM Platform Watchdog repair utility
- Launches ScreenConnect uninstall and cleanup tool
- Verbose output and audit logging
- Administrator privilege enforcement
- Superior Networks branding

Input:
- User menu selection (1-2 or B for Back)

Output:
- Launched repair sub-scripts
- Audit log entries

Dependencies:
- Windows PowerShell 4.0 or higher
- connectwise_rmm_repair.ps1
- screenconnect_repair.ps1
- Administrator privileges

Change Log:
2026-07-01 v1.0.0 - Initial release (Dwain Henderson Jr)
                    Standalone submenu for CW RMM and ScreenConnect repair tools.
                    Moved from nested position inside StorageCraft Troubleshooter to
                    its own top-level entry on the main menu.
#>

$ErrorActionPreference = "SilentlyContinue"

# Configuration
$installPath = "C:\ITTools\Scripts"
$cwRmmRepairScriptName = "connectwise_rmm_repair.ps1"
$scRepairScriptName = "screenconnect_repair.ps1"
$logDirectory = Join-Path $installPath "Logs"
$auditLogFile = Join-Path $logDirectory "master_audit_log.txt"

# Ensure log directory exists
if (-not (Test-Path $logDirectory)) { New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null }

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
        if ($details)      { $logEntry += "  Details: $details`n" }
        if ($errorMessage) { $logEntry += "  Error: $errorMessage`n" }
        $logEntry += "  $("="*70)`n"
        Add-Content -Path $auditLogFile -Value $logEntry -ErrorAction SilentlyContinue
    } catch {}
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-CWRMMMenu {
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
    Write-Host "       ConnectWise RMM Troubleshooter - Toolkit v$toolkitVersion           " -ForegroundColor Cyan
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  About this tool:" -ForegroundColor Gray
    Write-Host "  Use these utilities to fix stuck or broken ConnectWise RMM agents" -ForegroundColor Gray
    Write-Host "  and ScreenConnect installations (e.g., 'Installation Pending')." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ConnectWise RMM Agent Repair:" -ForegroundColor White
    Write-Host "    1. Repair ConnectWise RMM (Platform Watchdog)" -ForegroundColor Magenta
    Write-Host "       Downloads and runs the official CW RMM repair utility." -ForegroundColor DarkGray
    Write-Host "       Actions: healthcheck, healthcheckandrestore, uninstall," -ForegroundColor DarkGray
    Write-Host "       autoupdatecleanup. Download to: C:\ITStuff\Downloads\CWRMM" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  ScreenConnect Repair:" -ForegroundColor White
    Write-Host "    2. Repair ScreenConnect (Uninstall/Cleanup)" -ForegroundColor Magenta
    Write-Host "       Detects and removes all ScreenConnect Client instances via" -ForegroundColor DarkGray
    Write-Host "       PackageManagement and WMI. Cleans up leftover services." -ForegroundColor DarkGray
    Write-Host "       Run this BEFORE Option 1 to clear a stuck installation." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    B. Back to Main Menu" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Installation Path: $installPath" -ForegroundColor Gray
    Write-Host ""
}

function Run-CWRMMRepair {
    Write-Host "`n=== Launching ConnectWise RMM Repair ===" -ForegroundColor Cyan
    Write-AuditLog -action "CW RMM Troubleshooter" -details "Launching connectwise_rmm_repair.ps1"

    $scriptPath = Join-Path $installPath $cwRmmRepairScriptName

    if (Test-Path $scriptPath) {
        Write-Host "Starting ConnectWise RMM Repair Utility..." -ForegroundColor Green
        Write-Host "Script: $scriptPath" -ForegroundColor Gray
        Write-Host ""
        & $scriptPath
    } else {
        Write-Host "`nError: connectwise_rmm_repair.ps1 not found!" -ForegroundColor Red
        Write-Host "Expected: $scriptPath" -ForegroundColor Yellow
        Write-Host "`nPlease use Option 1 from the main menu to download and install the toolkit." -ForegroundColor Yellow
        Write-AuditLog -action "CW RMM Repair" -level "ERROR" -errorMessage "Script not found: $scriptPath"
        Write-Host "`nPress any key to return to menu..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Run-ScreenConnectRepair {
    Write-Host "`n=== Launching ScreenConnect Repair ===" -ForegroundColor Cyan
    Write-AuditLog -action "CW RMM Troubleshooter" -details "Launching screenconnect_repair.ps1"

    $scriptPath = Join-Path $installPath $scRepairScriptName

    if (Test-Path $scriptPath) {
        Write-Host "Starting ScreenConnect Repair Utility..." -ForegroundColor Green
        Write-Host "Script: $scriptPath" -ForegroundColor Gray
        Write-Host ""
        & $scriptPath
    } else {
        Write-Host "`nError: screenconnect_repair.ps1 not found!" -ForegroundColor Red
        Write-Host "Expected: $scriptPath" -ForegroundColor Yellow
        Write-Host "`nPlease use Option 1 from the main menu to download and install the toolkit." -ForegroundColor Yellow
        Write-AuditLog -action "ScreenConnect Repair" -level "ERROR" -errorMessage "Script not found: $scriptPath"
        Write-Host "`nPress any key to return to menu..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# Log entry
Write-AuditLog -action "CW RMM Troubleshooter" -details "Submenu opened"

# Main menu loop
do {
    Show-CWRMMMenu
    Write-Host "  Select an option (1-2 or B): " -NoNewline -ForegroundColor White
    $choice = Read-Host

    switch ($choice.ToUpper()) {
        '1' {
            Write-AuditLog -action "Menu Selection" -details "Option 1: Repair ConnectWise RMM"
            try {
                Run-CWRMMRepair
            } catch {
                Write-AuditLog -action "CW RMM Repair" -level "ERROR" -errorMessage $_.Exception.Message
            }
        }
        '2' {
            Write-AuditLog -action "Menu Selection" -details "Option 2: Repair ScreenConnect"
            try {
                Run-ScreenConnectRepair
            } catch {
                Write-AuditLog -action "ScreenConnect Repair" -level "ERROR" -errorMessage $_.Exception.Message
            }
        }
        'B' {
            Write-AuditLog -action "CW RMM Troubleshooter" -details "User returned to main menu"
            Write-Host "`nReturning to main menu..." -ForegroundColor Cyan
            exit 0
        }
        default {
            Write-AuditLog -action "Invalid Menu Selection" -level "WARN" -details "User entered: $choice"
            Write-Host "`nInvalid selection. Please choose 1-2 or B." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($true)
