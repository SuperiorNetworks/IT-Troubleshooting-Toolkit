<#
.SYNOPSIS
ScreenConnect Repair Utility

.DESCRIPTION
Name: screenconnect_repair.ps1
Version: 1.0.0
Purpose: Automates the uninstallation and cleanup of ScreenConnect instances.
Path: C:\ITTools\Scripts\screenconnect_repair.ps1
Copyright: 2026 Superior Networks LLC

Key Features:
- Detects installed ScreenConnect clients via WMI/Registry
- Uninstalls ScreenConnect via MSIEXEC or PackageManagement
- Cleans up leftover services and directories
- Comprehensive logging and verbose output
- Administrator privilege enforcement

Input: 
- None (Automatic detection and prompt)
Output:
- Uninstalled ScreenConnect instances
- Verbose console output and log entries
Dependencies:
- Windows PowerShell 4.0 or higher
- Administrator privileges

Change Log:
2026-07-01 v1.0.0 - Initial release (Dwain Henderson Jr)
#>

$ErrorActionPreference = "Stop"

# Configuration
$installPath = "C:\ITTools\Scripts"
$logDirectory = Join-Path $installPath "Logs"
$logFile = Join-Path $logDirectory "screenconnect_repair_log.txt"

# Ensure directories exist
if (-not (Test-Path $logDirectory)) { New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null }

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

function Remove-ScreenConnect {
    Write-Log "Searching for installed ScreenConnect clients..." "INFO"
    
    # Method 1: Get-Package (Requires PS 5.1+ / PackageManagement)
    $scPackages = @()
    try {
        if (Get-Command Get-Package -ErrorAction SilentlyContinue) {
            $scPackages = Get-Package -Name "ScreenConnect Client*" -ErrorAction SilentlyContinue
        }
    } catch {}

    # Method 2: WMI / CIM
    $wmiPackages = @()
    try {
        $wmiPackages = Get-WmiObject -Class Win32_Product -Filter "Name LIKE 'ScreenConnect Client%'" -ErrorAction SilentlyContinue
    } catch {}

    $foundAny = $false

    if ($scPackages.Count -gt 0) {
        $foundAny = $true
        foreach ($pkg in $scPackages) {
            Write-Log "Found (Package): $($pkg.Name)" "INFO"
            Write-Host "Attempting to uninstall $($pkg.Name)..." -ForegroundColor Yellow
            try {
                $pkg | Uninstall-Package -Force -ErrorAction Stop
                Write-Log "Successfully uninstalled $($pkg.Name)" "SUCCESS"
            } catch {
                Write-Log "Failed to uninstall via Get-Package: $($_.Exception.Message)" "ERROR"
            }
        }
    }

    if ($wmiPackages.Count -gt 0) {
        $foundAny = $true
        foreach ($pkg in $wmiPackages) {
            Write-Log "Found (WMI): $($pkg.Name)" "INFO"
            Write-Host "Attempting to uninstall $($pkg.Name)..." -ForegroundColor Yellow
            try {
                $pkg.Uninstall() | Out-Null
                Write-Log "Successfully uninstalled $($pkg.Name) via WMI" "SUCCESS"
            } catch {
                Write-Log "Failed to uninstall via WMI: $($_.Exception.Message)" "ERROR"
            }
        }
    }

    if (-not $foundAny) {
        Write-Log "No ScreenConnect Client installations found via standard checks." "WARN"
        Write-Host "If you know the thumbprint, you can manually run: Get-Package -Name `"ScreenConnect Client (thumbprint)`" | Uninstall-Package" -ForegroundColor Gray
    }

    # Cleanup leftover services
    Write-Log "Checking for leftover ScreenConnect services..." "INFO"
    $services = Get-Service -Name "ScreenConnect Client*" -ErrorAction SilentlyContinue
    foreach ($svc in $services) {
        Write-Log "Stopping and removing leftover service: $($svc.Name)" "WARN"
        try {
            Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
            # Use sc.exe to delete
            Start-Process -FilePath "sc.exe" -ArgumentList "delete", "`"$($svc.Name)`"" -Wait -NoNewWindow -ErrorAction SilentlyContinue
            Write-Log "Removed service $($svc.Name)" "SUCCESS"
        } catch {
            Write-Log "Failed to remove service $($svc.Name)" "ERROR"
        }
    }

    Write-Log "ScreenConnect repair/cleanup routine completed." "INFO"
}

function Main {
    Clear-Host
    Write-Host ""
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host "                     SUPERIOR NETWORKS LLC                        " -ForegroundColor White
    Write-Host "                  ScreenConnect Repair Utility                    " -ForegroundColor Cyan
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-Administrator)) {
        Write-Log "Administrator privileges required. Please run PowerShell as Administrator." "ERROR"
        Write-Host "`nPress any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    Write-Host "This utility will attempt to locate and cleanly uninstall all ScreenConnect Client instances." -ForegroundColor Yellow
    Write-Host "It will also clean up leftover services." -ForegroundColor Yellow
    Write-Host ""
    
    $confirm = Read-Host "Do you want to proceed? (Y/N)"
    
    if ($confirm.ToUpper() -eq 'Y') {
        Write-Host ""
        Remove-ScreenConnect
    } else {
        Write-Log "Operation cancelled by user." "INFO"
    }
    
    Write-Host "`nPress any key to return to menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

Main
