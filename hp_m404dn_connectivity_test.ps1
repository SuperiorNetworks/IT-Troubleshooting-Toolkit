<#
.SYNOPSIS
HP M404dn Connectivity Test - Network and USB Diagnostic Tool

.DESCRIPTION
Name: hp_m404dn_connectivity_test.ps1
Version: 3.9.0
Purpose: Diagnoses connectivity failures between a Windows 11 machine and an HP LaserJet Pro
         M404dn - covers both network (Ethernet/JetDirect) and USB connection paths. Tests
         ping, raw print port 9100, embedded web server (80/443), and SNMP (161) for network
         installs, and enumerates the USB device tree for direct-connect installs. Ends with
         a plain-language diagnosis based on which tests failed.
Path: C:\ITTools\Scripts\hp_m404dn_connectivity_test.ps1
Copyright: 2026 Superior Networks LLC

Key Features:
- Auto-detects printer IP from the installed printer's TCP/IP port when available
- Manual IP entry fallback
- Ping (ICMP) test
- Port 9100 test (raw/JetDirect printing - this is the one that actually matters for print jobs)
- Port 80/443 test (Embedded Web Server - printer's built-in status/config page)
- Port 161 test (SNMP - used for ink/toner and status monitoring)
- USB device enumeration for HP printer/scanner class devices (catches the printer being
  misidentified as a scanner or removable drive, a known M404 series symptom)
- Print Spooler service status check
- Plain-language diagnosis summary at the end
- Comprehensive logging to master audit log

Input:
- Printer name (defaults to first printer matching "M404")
- Printer IP address (auto-detected or manually entered)

Output:
- Console pass/fail table for each test
- Diagnosis summary with suggested next step
- Log entries in C:\ITTools\Scripts\Logs\hp_m404dn_connectivity_log.txt

Dependencies:
- Windows PowerShell 5.1 or higher (Windows 11)
- Test-NetConnection cmdlet (built into Windows 11)
- Network access to the printer's subnet (for network-connected tests)

Change Log:
2026-09-14 v3.9.0 - Added to IT Troubleshooting Toolkit (Dwain Henderson Jr)
#>

# ================== Configuration ==================
$installPath = "C:\ITTools\Scripts"
$printerNameFilter = "*M404*"
$logDirectory = "C:\ITTools\Scripts\Logs"
$logFile = Join-Path $logDirectory "hp_m404dn_connectivity_log.txt"

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

function Get-PrinterIP {
    $printer = Get-Printer | Where-Object { $_.Name -like $printerNameFilter } | Select-Object -First 1
    if (-not $printer) {
        Write-Log "No installed printer matched filter '$printerNameFilter'." "WARN"
        return $null
    }

    Write-Log "Found installed printer: $($printer.Name) (Port: $($printer.PortName))"
    $port = Get-PrinterPort -Name $printer.PortName -ErrorAction SilentlyContinue
    if ($port -and $port.PrinterHostAddress) {
        Write-Log "Detected printer IP from port: $($port.PrinterHostAddress)" "SUCCESS"
        return $port.PrinterHostAddress
    }
    return $null
}

function Test-PortConnectivity {
    param([string]$ipAddress, [int]$port, [string]$label)
    try {
        $result = Test-NetConnection -ComputerName $ipAddress -Port $port -WarningAction SilentlyContinue -ErrorAction Stop
        if ($result.TcpTestSucceeded) {
            Write-Log "$label (port $port): OPEN" "SUCCESS"
            return $true
        } else {
            Write-Log "$label (port $port): CLOSED / UNREACHABLE" "ERROR"
            return $false
        }
    } catch {
        Write-Log "$label (port $port): TEST FAILED - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-PrinterPing {
    param([string]$ipAddress)
    try {
        $result = Test-Connection -ComputerName $ipAddress -Count 2 -ErrorAction Stop
        Write-Log "Ping to ${ipAddress}: SUCCESS (avg response received)" "SUCCESS"
        return $true
    } catch {
        Write-Log "Ping to ${ipAddress}: FAILED - printer may be off, sleeping, or IP changed" "ERROR"
        return $false
    }
}

function Test-USBConnection {
    Write-Host ""
    Write-Log "Enumerating USB devices for HP printer hardware..."
    if (-not (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue)) {
        Write-Log "Get-PnpDevice is unavailable on this system. Use Device Manager to inspect USB printer devices." "WARN"
        return
    }
    $usbDevices = @(Get-PnpDevice | Where-Object {
        $_.FriendlyName -like "*HP*" -and ($_.Class -eq "Printer" -or $_.Class -eq "USB" -or $_.Class -eq "Image" -or $_.Class -eq "WPD")
    })

    if (-not $usbDevices -or $usbDevices.Count -eq 0) {
        Write-Log "No HP USB devices detected. If this is a USB-connected M404dn, check the cable and port." "WARN"
        return
    }

    Write-Host ""
    Write-Host "HP USB/Printer Devices Found:" -ForegroundColor Cyan
    $usbDevices | Select-Object FriendlyName, Class, Status | Format-Table -AutoSize

    $misidentified = $usbDevices | Where-Object { $_.Class -eq "Image" -or $_.Class -eq "WPD" }
    if ($misidentified) {
        Write-Log "WARNING: Printer appears under Class '$($misidentified[0].Class)' instead of 'Printer'." "WARN"
        Write-Log "This is a known M404 series symptom (Windows sees it as a scanner or removable drive)." "WARN"
        Write-Log "Fix: unplug USB, uninstall the device in Device Manager, replug, let Windows redetect." "WARN"
    }

    $problemDevices = $usbDevices | Where-Object { $_.Status -ne "OK" }
    if ($problemDevices) {
        Write-Log "$($problemDevices.Count) HP device(s) reporting a non-OK status." "WARN"
    }
}

function Test-SpoolerStatus {
    $svc = Get-Service -Name Spooler -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        Write-Log "Print Spooler service: RUNNING" "SUCCESS"
        return $true
    } else {
        Write-Log "Print Spooler service: NOT RUNNING" "ERROR"
        return $false
    }
}

function Show-ToolBanner {
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
    Write-Host "           HP M404dn Connectivity Test - Toolkit v$toolkitVersion" -ForegroundColor Cyan
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# ================== Main ==================
Show-ToolBanner
Write-Log "========== Starting HP M404dn Connectivity Test =========="

$spoolerOk = Test-SpoolerStatus

Write-Host ""
Write-Host "Is this printer connected via Network (Ethernet) or USB?" -ForegroundColor Cyan
Write-Host "  1. Network"
Write-Host "  2. USB"
$connType = Read-Host "Select an option"

$results = @{}

if ($connType -eq "1") {
    $ip = Get-PrinterIP
    if (-not $ip) {
        $ip = Read-Host "Enter the HP M404dn IP address manually"
    }

    if ([string]::IsNullOrWhiteSpace($ip)) {
        Write-Log "No IP address provided. Cannot continue network tests." "ERROR"
    } else {
        Write-Host ""
        $results["Ping"] = Test-PrinterPing -ipAddress $ip
        $results["RawPrint9100"] = Test-PortConnectivity -ipAddress $ip -port 9100 -label "Raw/JetDirect Print"
        $results["EWS443"] = Test-PortConnectivity -ipAddress $ip -port 443 -label "Embedded Web Server (HTTPS)"
        $results["EWS80"] = Test-PortConnectivity -ipAddress $ip -port 80 -label "Embedded Web Server (HTTP)"
        $results["SNMP161"] = Test-PortConnectivity -ipAddress $ip -port 161 -label "SNMP Status"
    }
} elseif ($connType -eq "2") {
    Test-USBConnection
} else {
    Write-Log "Invalid selection - running both network and USB checks." "WARN"
    $ip = Get-PrinterIP
    if ($ip) {
        $results["Ping"] = Test-PrinterPing -ipAddress $ip
        $results["RawPrint9100"] = Test-PortConnectivity -ipAddress $ip -port 9100 -label "Raw/JetDirect Print"
    }
    Test-USBConnection
}

# ================== Diagnosis ==================
Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  DIAGNOSIS SUMMARY" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

if (-not $spoolerOk) {
    Write-Host "-> Print Spooler service is down. Run hp_m404dn_spooler_repair.ps1 first." -ForegroundColor Yellow
}
if ($results.ContainsKey("Ping") -and -not $results["Ping"]) {
    Write-Host "-> Printer did not respond to ping. Check power, and confirm the IP hasn't" -ForegroundColor Yellow
    Write-Host "   changed (DHCP lease renewal is a common cause). Print a config page from" -ForegroundColor Yellow
    Write-Host "   the printer's control panel to confirm its current IP." -ForegroundColor Yellow
}
if ($results.ContainsKey("RawPrint9100") -and $results["Ping"] -and -not $results["RawPrint9100"]) {
    Write-Host "-> Printer responds to ping but port 9100 is closed. This points to a" -ForegroundColor Yellow
    Write-Host "   firewall blocking raw print traffic, or the printer's network card is" -ForegroundColor Yellow
    Write-Host "   flaky (matches the community-reported symptom of USB working but" -ForegroundColor Yellow
    Write-Host "   network jobs failing on this model)." -ForegroundColor Yellow
}
if ($results.Count -eq 0) {
    Write-Host "-> See USB device results above for next steps." -ForegroundColor Yellow
}

Write-Log "========== Connectivity Test Complete =========="
