<#
.SYNOPSIS
HP M404dn Driver Reinstall - Clean Removal and Reinstall Tool

.DESCRIPTION
Name: hp_m404dn_driver_reinstall.ps1
Version: 3.9.0
Purpose: Cleanly removes and reinstalls the HP LaserJet Pro M404dn printer object, printer
         port, and driver on Windows 11. Addresses the recurring pattern where printer
         hardware is fine but Windows has lost the correct driver or communication path -
         most often caused by a generic/WSD driver being used instead of the correct
         HP PCL-6 driver, or a corrupted driver after a Windows Update.
Path: C:\ITTools\Scripts\hp_m404dn_driver_reinstall.ps1
Copyright: 2026 Superior Networks LLC

Key Features:
- Lists all currently installed printer objects matching the M404dn
- Removes the printer object, its port, and the driver (in the correct order to avoid
  "printer driver is in use" errors)
- Restarts the spooler between removal steps to release file locks
- Searches for the in-box Windows driver ("HP LaserJet Pro M404-M405 PCL-6" family) and
  offers to use it automatically if present in the local driver store
- Falls back to a manual .inf path prompt if the in-box driver isn't found (i.e. after
  downloading the full driver package from HP)
- Re-adds a standard TCP/IP port (prompts for IP) and creates the printer
- Optional: set as default printer, send a Windows test page
- Comprehensive logging to master audit log

Input:
- Printer name (defaults to first printer matching "M404")
- Printer IP address (for network reinstall)
- Path to driver .inf file (only if in-box driver is not found)

Output:
- Console status messages (Success/Failure for each step)
- Log entries in C:\ITTools\Scripts\Logs\hp_m404dn_driver_log.txt

Dependencies:
- Windows PowerShell 5.1 or higher (Windows 11)
- Administrator privileges (required for driver/port/printer management)
- PrintManagement module (built into Windows 11)
- Internet access only if downloading the full driver package from HP manually

Change Log:
2026-09-14 v3.9.0 - Added to IT Troubleshooting Toolkit (Dwain Henderson Jr)
#>

# ================== Configuration ==================
$installPath = "C:\ITTools\Scripts"
$printerNameFilter = "*M404*"
$driverNameFilter = "*M404*"
$defaultPortName = "IP_M404DN"
$logDirectory = "C:\ITTools\Scripts\Logs"
$logFile = Join-Path $logDirectory "hp_m404dn_driver_log.txt"
$hpDriverDownloadUrl = "https://support.hp.com/us-en/drivers/hp-laserjet-pro-m404-m405-series/model/19202536"

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

function Show-CurrentInstall {
    Write-Log "Current printers matching '$printerNameFilter':"
    $printers = Get-Printer | Where-Object { $_.Name -like $printerNameFilter }
    if ($printers) {
        $printers | Select-Object Name, DriverName, PortName | Format-Table -AutoSize
    } else {
        Write-Log "No printer objects currently match '$printerNameFilter'." "WARN"
    }

    Write-Log "Current drivers matching '$driverNameFilter':"
    $drivers = Get-PrinterDriver | Where-Object { $_.Name -like $driverNameFilter }
    if ($drivers) {
        $drivers | Select-Object Name, Manufacturer, DriverVersion | Format-Table -AutoSize
    } else {
        Write-Log "No driver currently matches '$driverNameFilter'." "WARN"
    }
    return $printers
}

function Remove-ExistingInstall {
    $printers = Get-Printer | Where-Object { $_.Name -like $printerNameFilter }
    foreach ($p in $printers) {
        try {
            Write-Log "Removing printer object: $($p.Name)"
            Remove-Printer -Name $p.Name -ErrorAction Stop
            Write-Log "Removed printer: $($p.Name)" "SUCCESS"
        } catch {
            Write-Log "Failed to remove printer $($p.Name): $($_.Exception.Message)" "ERROR"
        }
    }

    # Restart spooler to release driver file locks before removing the driver
    Write-Log "Restarting spooler to release file locks..."
    try {
        Restart-Service -Name Spooler -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
    } catch {
        Write-Log "Could not restart spooler: $($_.Exception.Message)" "WARN"
    }

    $drivers = Get-PrinterDriver | Where-Object { $_.Name -like $driverNameFilter }
    foreach ($d in $drivers) {
        try {
            Write-Log "Removing driver: $($d.Name)"
            Remove-PrinterDriver -Name $d.Name -ErrorAction Stop
            Write-Log "Removed driver: $($d.Name)" "SUCCESS"
        } catch {
            Write-Log "Failed to remove driver $($d.Name): $($_.Exception.Message)" "WARN"
            Write-Log "This usually means it's still in use - may need a reboot to fully clear." "WARN"
        }
    }

    $ports = Get-PrinterPort | Where-Object { $_.Name -like "*M404*" -or $_.Name -eq $defaultPortName }
    foreach ($port in $ports) {
        try {
            Write-Log "Removing port: $($port.Name)"
            Remove-PrinterPort -Name $port.Name -ErrorAction Stop
            Write-Log "Removed port: $($port.Name)" "SUCCESS"
        } catch {
            Write-Log "Failed to remove port $($port.Name): $($_.Exception.Message)" "WARN"
        }
    }
}

function Find-InboxDriver {
    Write-Log "Searching Windows driver store for an in-box HP M404-M405 driver..."
    $candidates = @(
        "HP LaserJet Pro M404-M405 PCL-6",
        "HP LaserJet Pro M404-M405 PCL 6",
        "HP LaserJet Pro M404-M405"
    )
    foreach ($name in $candidates) {
        $found = Get-PrinterDriver -Name $name -ErrorAction SilentlyContinue
        if ($found) {
            Write-Log "Found in-box driver: $($found.Name)" "SUCCESS"
            return $found.Name
        }
    }

    # Search PnP driver store as a fallback (driver may be present but not yet installed as a printer driver)
    $storeMatch = Get-WindowsDriver -Online -ErrorAction SilentlyContinue | Where-Object { $_.OriginalFileName -like "*hpcu*" -or $_.ProviderName -like "*HP*" } | Select-Object -First 1
    if ($storeMatch) {
        Write-Log "Possible HP driver package found in driver store (OEM: $($storeMatch.Driver))." "WARN"
    }

    Write-Log "No in-box M404-M405 driver found." "WARN"
    return $null
}

function Add-InboxDriver {
    Write-Log "Adding in-box driver 'HP LaserJet Pro M404-M405 PCL-6' via Add-PrinterDriver..."
    try {
        Add-PrinterDriver -Name "HP LaserJet Pro M404-M405 PCL-6" -ErrorAction Stop
        Write-Log "In-box driver installed successfully." "SUCCESS"
        return "HP LaserJet Pro M404-M405 PCL-6"
    } catch {
        Write-Log "Could not add in-box driver: $($_.Exception.Message)" "WARN"
        return $null
    }
}

function New-PrinterInstall {
    Write-Host ""
    $ip = Read-Host "Enter the HP M404dn's IP address"
    if ([string]::IsNullOrWhiteSpace($ip)) {
        Write-Log "No IP entered - aborting reinstall." "ERROR"
        return
    }

    $driverName = Find-InboxDriver
    if (-not $driverName) {
        $driverName = Add-InboxDriver
    }

    if (-not $driverName) {
        Write-Host ""
        Write-Host "In-box driver not available on this machine." -ForegroundColor Yellow
        Write-Host "Download the full driver package from HP first:" -ForegroundColor Yellow
        Write-Host "  $hpDriverDownloadUrl" -ForegroundColor Cyan
        $infPath = Read-Host "After installing, enter the full path to the driver .inf file (or leave blank to cancel)"
        if ([string]::IsNullOrWhiteSpace($infPath)) {
            Write-Log "No driver available - reinstall cancelled." "ERROR"
            return
        }
        try {
            pnputil /add-driver "$infPath" /install | Out-Null
            $driverName = Read-Host "Enter the exact driver name as it now appears in Print Management"
        } catch {
            Write-Log "Failed to stage driver from $infPath : $($_.Exception.Message)" "ERROR"
            return
        }
    }

    try {
        Write-Log "Creating TCP/IP port '$defaultPortName' for $ip..."
        Add-PrinterPort -Name $defaultPortName -PrinterHostAddress $ip -ErrorAction Stop
        Write-Log "Port created." "SUCCESS"
    } catch {
        Write-Log "Failed to create printer port: $($_.Exception.Message)" "ERROR"
        return
    }

    try {
        Write-Log "Adding printer 'HP LaserJet Pro M404dn' using driver '$driverName'..."
        Add-Printer -Name "HP LaserJet Pro M404dn" -DriverName $driverName -PortName $defaultPortName -ErrorAction Stop
        Write-Log "Printer installed successfully." "SUCCESS"
    } catch {
        Write-Log "Failed to add printer: $($_.Exception.Message)" "ERROR"
        return
    }

    $setDefault = Read-Host "Set as default printer? (Y/N)"
    if ($setDefault -eq "Y" -or $setDefault -eq "y") {
        try {
            $wmiPrinter = Get-WmiObject -Class Win32_Printer -Filter "Name='HP LaserJet Pro M404dn'"
            $wmiPrinter.SetDefaultPrinter() | Out-Null
            Write-Log "Set as default printer." "SUCCESS"
        } catch {
            Write-Log "Could not set as default: $($_.Exception.Message)" "WARN"
        }
    }

    $testPage = Read-Host "Send a Windows test page now? (Y/N)"
    if ($testPage -eq "Y" -or $testPage -eq "y") {
        try {
            $wmiPrinter = Get-WmiObject -Class Win32_Printer -Filter "Name='HP LaserJet Pro M404dn'"
            $wmiPrinter.PrintTestPage() | Out-Null
            Write-Log "Test page sent." "SUCCESS"
        } catch {
            Write-Log "Failed to send test page: $($_.Exception.Message)" "WARN"
        }
    }
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
    Write-Host "            HP M404dn Driver Reinstall - Toolkit v$toolkitVersion" -ForegroundColor Cyan
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  1. View Current Install (printer / driver / port)"
    Write-Host "  2. Full Clean Reinstall (remove old, install fresh via network IP)"
    Write-Host "  3. Remove Existing Install Only"
    Write-Host "  4. Install Fresh Only (no removal - use if nothing is currently installed)"
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
        "1" { Show-CurrentInstall | Out-Null; Read-Host "Press Enter to continue" }
        "2" {
            Write-Log "========== Starting Full Clean Reinstall =========="
            Show-CurrentInstall | Out-Null
            Remove-ExistingInstall
            New-PrinterInstall
            Write-Log "========== Full Clean Reinstall Complete ==========" "SUCCESS"
            Read-Host "Press Enter to continue"
        }
        "3" { Remove-ExistingInstall; Read-Host "Press Enter to continue" }
        "4" { New-PrinterInstall; Read-Host "Press Enter to continue" }
        "B" { }
        "b" { }
        default { Write-Host "Invalid selection." -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
    }
} while ($choice -ne "B" -and $choice -ne "b")

Write-Log "Driver reinstall tool session ended."
}
