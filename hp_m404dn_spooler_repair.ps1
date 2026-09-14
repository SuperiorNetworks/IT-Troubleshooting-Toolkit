<#
.SYNOPSIS
HP M404dn Spooler Repair - Print Spooler Diagnostic and Repair Tool

.DESCRIPTION
Name: hp_m404dn_spooler_repair.ps1
Version: 3.9.0
Purpose: Diagnoses and repairs Windows Print Spooler issues specific to the HP LaserJet Pro
         M404dn - stuck/corrupted print jobs, hung spooler service after USB or network
         reconnect, and orphaned spool files. Matches the most common M404dn failure pattern
         on Windows 11: job stuck in queue, printer shows Ready, nothing prints.
Path: C:\ITTools\Scripts\hp_m404dn_spooler_repair.ps1
Copyright: 2026 Superior Networks LLC

Key Features:
- Displays current spooler service status
- Lists stuck/pending jobs for the HP M404dn queue specifically
- Stops spooler service, clears orphaned .SHD/.SPL spool files, restarts service
- Verifies queue is clear and spooler is running after repair
- Quick "just restart spooler" option for the common USB reconnect issue
- Comprehensive logging to master audit log

Input:
- Printer name (defaults to first printer matching "M404" - can override)
- Menu selection (Full Repair / View Stuck Jobs / Quick Spooler Restart / Clear Spool Folder Only)

Output:
- Console status messages (Success/Failure for each step)
- Log entries in C:\ITTools\Scripts\Logs\hp_m404dn_spooler_log.txt

Dependencies:
- Windows PowerShell 5.1 or higher (Windows 11)
- Administrator privileges (required to stop/start the Spooler service)
- PrintManagement module (built into Windows 11)

Change Log:
2026-09-14 v3.9.0 - Added to IT Troubleshooting Toolkit (Dwain Henderson Jr)
#>

# ================== Configuration ==================
$installPath = "C:\ITTools\Scripts"
$printerNameFilter = "*M404*"
$logDirectory = "C:\ITTools\Scripts\Logs"
$logFile = Join-Path $logDirectory "hp_m404dn_spooler_log.txt"
$spoolFolder = "$env:SystemRoot\System32\spool\PRINTERS"

# ================== Setup ==================
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

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-TargetPrinter {
    $printer = Get-Printer | Where-Object { $_.Name -like $printerNameFilter } | Select-Object -First 1
    if (-not $printer) {
        Write-Log "No installed printer matched filter '$printerNameFilter'. Showing all printer jobs instead." "WARN"
    }
    return $printer
}

function Show-StuckJobs {
    Write-Log "Checking print queue for stuck jobs..."
    $printers = @(Get-Printer | Where-Object { $_.Name -like $printerNameFilter })
    if ($printers.Count -eq 0) {
        Write-Log "No installed printer matched filter '$printerNameFilter'. No M404dn queue can be inspected." "WARN"
        return $null
    }

    $jobs = @()
    foreach ($printer in $printers) {
        $jobs += @(Get-PrintJob -PrinterName $printer.Name -ErrorAction SilentlyContinue)
    }

    if (-not $jobs -or $jobs.Count -eq 0) {
        Write-Log "No jobs currently in the queue." "SUCCESS"
        return $null
    }

    Write-Host ""
    Write-Host "Current Queue:" -ForegroundColor Cyan
    $jobs | Select-Object Id, DocumentName, JobStatus, SubmittedTime, PagesPrinted | Format-Table -AutoSize
    Write-Log "$($jobs.Count) job(s) found in queue." "WARN"
    return $jobs
}

function Stop-SpoolerService {
    Write-Log "Stopping Print Spooler service..."
    try {
        Stop-Service -Name Spooler -Force -ErrorAction Stop
        Write-Log "Spooler service stopped." "SUCCESS"
        return $true
    } catch {
        Write-Log "Failed to stop Spooler service: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Start-SpoolerService {
    Write-Log "Starting Print Spooler service..."
    try {
        Start-Service -Name Spooler -ErrorAction Stop
        Start-Sleep -Seconds 2
        $svc = Get-Service -Name Spooler
        if ($svc.Status -eq "Running") {
            Write-Log "Spooler service is running." "SUCCESS"
            return $true
        } else {
            Write-Log "Spooler service did not reach Running state (Status: $($svc.Status))." "ERROR"
            return $false
        }
    } catch {
        Write-Log "Failed to start Spooler service: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Clear-SpoolFolder {
    Write-Log "Clearing orphaned spool files from $spoolFolder..."
    if (-not (Test-Path $spoolFolder)) {
        Write-Log "Spool folder not found at $spoolFolder." "ERROR"
        return $false
    }
    try {
        $files = Get-ChildItem -Path $spoolFolder -Include *.SHD, *.SPL -Recurse -Force -ErrorAction SilentlyContinue
        $count = ($files | Measure-Object).Count
        if ($count -eq 0) {
            Write-Log "No orphaned spool files found." "SUCCESS"
            return $true
        }
        $files | Remove-Item -Force -ErrorAction Stop
        Write-Log "Removed $count orphaned spool file(s)." "SUCCESS"
        return $true
    } catch {
        Write-Log "Error clearing spool folder: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Invoke-FullRepair {
    Write-Log "========== Starting Full Spooler Repair =========="
    Show-StuckJobs | Out-Null

    if (-not (Stop-SpoolerService)) {
        Write-Log "Aborting repair - could not stop Spooler service." "ERROR"
        return
    }

    Start-Sleep -Seconds 1
    Clear-SpoolFolder | Out-Null

    if (-not (Start-SpoolerService)) {
        Write-Log "Repair incomplete - Spooler service did not restart cleanly." "ERROR"
        return
    }

    Start-Sleep -Seconds 2
    Write-Log "Verifying queue is clear..."
    Show-StuckJobs | Out-Null
    Write-Log "========== Full Spooler Repair Complete ==========" "SUCCESS"
    Write-Host ""
    Write-Host "If the printer still won't respond, power-cycle the HP M404dn itself" -ForegroundColor Yellow
    Write-Host "(known issue: printer connected before Windows boots works fine; if" -ForegroundColor Yellow
    Write-Host "powered on after boot, this repair usually clears it)." -ForegroundColor Yellow
}

function Invoke-QuickRestart {
    Write-Log "========== Quick Spooler Restart =========="
    if (Stop-SpoolerService) {
        Start-Sleep -Seconds 1
        Start-SpoolerService | Out-Null
    }
    Write-Log "========== Quick Spooler Restart Complete ==========" "SUCCESS"
}

# ================== Main Menu ==================
function Show-Menu {
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
    Write-Host "             HP M404dn Spooler Repair - Toolkit v$toolkitVersion" -ForegroundColor Cyan
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  1. Full Repair (stop spooler, clear spool files, restart)"
    Write-Host "  2. View Current Stuck Jobs Only"
    Write-Host "  3. Quick Spooler Restart Only"
    Write-Host "  4. Clear Spool Folder Only (spooler must already be stopped)"
    Write-Host "  B. Back to HP M404dn Troubleshooter"
    Write-Host ""
}

if (-not (Test-Administrator)) {
    Write-Log "Administrator privileges are required. Restart the IT Troubleshooting Toolkit as Administrator." "ERROR"
    Write-Host "This tool requires Administrator privileges. Close the toolkit and restart it as Administrator." -ForegroundColor Yellow
    Read-Host "Press Enter to return to the HP M404dn Troubleshooter" | Out-Null
} else {

do {
    Show-Menu
    $choice = Read-Host "Select an option"
    switch ($choice) {
        "1" { Invoke-FullRepair; Read-Host "Press Enter to continue" }
        "2" { Show-StuckJobs | Out-Null; Read-Host "Press Enter to continue" }
        "3" { Invoke-QuickRestart; Read-Host "Press Enter to continue" }
        "4" {
            if ((Get-Service -Name Spooler).Status -eq "Running") {
                Write-Log "Spooler is running - stop it first (option 1 handles this automatically)." "WARN"
            } else {
                Clear-SpoolFolder | Out-Null
            }
            Read-Host "Press Enter to continue"
        }
        "B" { }
        "b" { }
        default { Write-Host "Invalid selection." -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
    }
} while ($choice -ne "B" -and $choice -ne "b")

Write-Log "Spooler repair tool session ended."
}
