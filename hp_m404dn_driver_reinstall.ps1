<#
.SYNOPSIS
HP M404dn Driver Reinstall - Clean Removal and Reinstall Tool

.DESCRIPTION
Name: hp_m404dn_driver_reinstall.ps1
Version: 3.19.1
Purpose: Cleans up duplicate or broken HP LaserJet Pro M404dn printer copies (USB, WSD, old
         TCP/IP) and reinstalls one clean network printer on a standard TCP/IP port. Checks
         the printer and the driver BEFORE removing anything, so a failed reinstall never
         leaves the user without a printer.
Author: Dwain Henderson Jr. | Superior Networks LLC
Contact: (937) 985-2480 | dhenderson@superiornetworks.biz
Copyright: 2026, Superior Networks LLC
Path: C:\ITTools\Scripts\hp_m404dn_driver_reinstall.ps1

What This Script Does:
  - Shows every printer copy, port, driver and queued job matching the M404dn
  - Removes only the copies the technician picks from a numbered list (with confirmation)
  - Network reinstall: validates the IP, tests TCP 9100 on the printer, picks a usable HP
    driver (keeps the one already installed; never deletes it), shows the plan and asks
    for confirmation, clears stuck jobs, removes the old copies and ports, creates one
    TCP/IP port and one printer, verifies it and offers a test page
  - Reports FAILED (not "Complete") when any reinstall step does not finish
  - Logs every action to the tool log and the master audit log

Input:
  - Printer IP address (network reinstall)
  - Technician choices: which copies to remove, Y/N confirmations
  - Path to the HP driver .inf (only if no HP M404 driver is on the PC)

Output:
  - Console status messages
  - C:\ITTools\Scripts\Logs\hp_m404dn_driver_log.txt
  - C:\ITTools\Scripts\Logs\master_audit_log.txt

Dependencies:
  - Windows PowerShell 4.0 or higher, Windows 8.1 / Server 2012 R2 or newer
  - PrintManagement module (built into Windows)
  - Administrator privileges
  - HP M404-M405 driver from Windows Update or the HP full driver package (not built into Windows)

Change Log:
2026-09-14 v3.9.0 - Added to IT Troubleshooting Toolkit (Dwain Henderson Jr)
2026-10-07 v3.19.1 - Fix: view option showed no tables; check IP and driver before removing
                     anything; keep the installed HP driver instead of deleting it; match
                     driver names by wildcard; clear stuck jobs first; confirm before changes;
                     pick-list removal of duplicate copies; report FAILED on errors; no
                     default-printer change under the admin account (Dwain Henderson Jr)
#>

# ================== Configuration ==================
$installPath = "C:\ITTools\Scripts"
$printerNameFilter = "*M404*"
$driverNameFilter = "*M404*"
$newPrinterName = "HP LaserJet Pro M404dn"
$defaultPortName = "IP_M404DN"
$rawPrintPort = 9100
$logDirectory = Join-Path $installPath "Logs"
$logFile = Join-Path $logDirectory "hp_m404dn_driver_log.txt"
$auditLogFile = Join-Path $logDirectory "master_audit_log.txt"
$hpDriverDownloadUrl = "https://support.hp.com/us-en/drivers/hp-laserjet-pro-m404-m405-series/model/19202536"
$driverCandidates = @(
    "HP LaserJet Pro M404-M405 PCL-6 (V3)",
    "HP LaserJet Pro M404-M405 PCL-6 (V4)",
    "HP LaserJet Pro M404-M405 PCL-6",
    "HP LaserJet Pro M404-M405 PCL 6",
    "HP LaserJet Pro M404-M405"
)

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

function Write-AuditLog {
    param (
        [string]$action,
        [string]$details = "",
        [string]$level = "INFO",
        [string]$errorMessage = ""
    )
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$level] $env:USERNAME@$env:COMPUTERNAME`n"
        $logEntry += "  Action: $action`n"
        if ($details) { $logEntry += "  Details: $details`n" }
        if ($errorMessage) { $logEntry += "  Error: $errorMessage`n" }
        $logEntry += "  $("="*70)`n"
        Add-Content -Path $auditLogFile -Value $logEntry -ErrorAction SilentlyContinue
    } catch {}
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Confirm-Action {
    param ([string]$question)
    $answer = Read-Host "$question (Y/N)"
    return ($answer -eq "Y" -or $answer -eq "y")
}

function Get-M404Printers {
    return @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $printerNameFilter -or $_.DriverName -like $driverNameFilter })
}

function Get-M404Drivers {
    return @(Get-PrinterDriver -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $driverNameFilter })
}

function Get-JobCount {
    param ([string]$printerName)
    return @(Get-PrintJob -PrinterName $printerName -ErrorAction SilentlyContinue).Count
}

function Show-CurrentInstall {
    $printers = @(Get-M404Printers)
    Write-Host ""
    Write-Log "Printer copies matching the M404dn: $($printers.Count)"
    if ($printers.Count -gt 0) {
        $printers | Select-Object Name, PortName, DriverName, @{ Name = "Jobs"; Expression = { Get-JobCount $_.Name } } |
            Format-Table -AutoSize | Out-String -Width 200 | Write-Host
    }

    $portNames = @($printers | ForEach-Object { $_.PortName })
    $ports = @(Get-PrinterPort -ErrorAction SilentlyContinue | Where-Object { $portNames -contains $_.Name -or $_.Name -like "*M404*" -or $_.Name -eq $defaultPortName })
    if ($ports.Count -gt 0) {
        Write-Log "Ports used by those copies (USB = USB cable, WSD = auto-discovered, IP = network):"
        $ports | Select-Object Name, Description, PrinterHostAddress |
            Format-Table -AutoSize | Out-String -Width 200 | Write-Host
    }

    $drivers = @(Get-M404Drivers)
    if ($drivers.Count -gt 0) {
        Write-Log "HP M404 drivers installed:"
        $drivers | Select-Object Name, Manufacturer |
            Format-Table -AutoSize | Out-String -Width 200 | Write-Host
    } else {
        Write-Log "No HP M404 driver is installed on this PC." "WARN"
    }

    if ($printers.Count -gt 1) {
        Write-Log "More than one copy found. Duplicates can send jobs to a stale copy." "WARN"
    }
}

function Clear-PrinterJobs {
    param ([string]$printerName)
    $jobs = @(Get-PrintJob -PrinterName $printerName -ErrorAction SilentlyContinue)
    foreach ($job in $jobs) {
        try {
            Remove-PrintJob -InputObject $job -ErrorAction Stop
        } catch {
            Write-Log "Could not delete job $($job.Id) on $printerName : $($_.Exception.Message)" "WARN"
        }
    }
    if ($jobs.Count -gt 0) { Write-Log "Cleared $($jobs.Count) queued job(s) on $printerName." }
}

function Remove-PrinterCopies {
    # Removes the given printer objects and any TCP/IP ports only they used.
    # Drivers are never removed: the reinstall reuses them.
    param ([object[]]$printers)
    $allOk = $true
    $portNames = @()
    foreach ($p in $printers) {
        Clear-PrinterJobs -printerName $p.Name
        try {
            Remove-Printer -Name $p.Name -ErrorAction Stop
            $portNames += $p.PortName
        } catch {
            Write-Log "Failed to remove $($p.Name): $($_.Exception.Message)" "ERROR"
            Write-AuditLog -action "HP M404dn Driver Reinstall" -level "ERROR" -errorMessage "Remove printer $($p.Name): $($_.Exception.Message)"
            $allOk = $false
        }
    }

    # A copy with a job stuck sending to a dead port stays "pending deletion" until the
    # spooler restarts, so restart it and then confirm each copy is really gone.
    Write-Log "Restarting the Print Spooler to finish removal..."
    try {
        Restart-Service -Name Spooler -Force -ErrorAction Stop
        Start-Sleep -Seconds 3
    } catch {
        Write-Log "Could not restart the spooler: $($_.Exception.Message)" "WARN"
    }
    foreach ($p in $printers) {
        if (Get-Printer -Name $p.Name -ErrorAction SilentlyContinue) {
            Write-Log "Still present after removal: $($p.Name). Reboot the PC and run this option again." "ERROR"
            $allOk = $false
        } else {
            Write-Log "Removed printer copy: $($p.Name)" "SUCCESS"
            Write-AuditLog -action "HP M404dn Driver Reinstall" -details "Removed printer copy: $($p.Name) (port $($p.PortName))"
        }
    }

    $stillUsed = @(Get-Printer -ErrorAction SilentlyContinue | ForEach-Object { $_.PortName })
    foreach ($portName in ($portNames | Select-Object -Unique)) {
        $port = Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue
        # Only TCP/IP ports can be removed; USB and WSD ports belong to Windows and are left alone.
        if ($port -and $port.PrinterHostAddress -and ($stillUsed -notcontains $portName)) {
            try {
                Remove-PrinterPort -Name $portName -ErrorAction Stop
                Write-Log "Removed unused port: $portName" "SUCCESS"
            } catch {
                Write-Log "Could not remove port $portName (harmless): $($_.Exception.Message)" "WARN"
            }
        }
    }
    return $allOk
}

function Select-PrinterCopies {
    param ([object[]]$printers)
    Write-Host ""
    for ($i = 0; $i -lt $printers.Count; $i++) {
        Write-Host ("  {0}. {1}  [port {2}, driver {3}]" -f ($i + 1), $printers[$i].Name, $printers[$i].PortName, $printers[$i].DriverName)
    }
    Write-Host ""
    $answer = Read-Host "Enter the numbers to REMOVE, separated by commas (blank = cancel)"
    $indexes = @()
    foreach ($part in ($answer -split ",")) {
        $n = 0
        if ([int]::TryParse($part.Trim(), [ref]$n) -and $n -ge 1 -and $n -le $printers.Count -and $indexes -notcontains $n) {
            $indexes += $n
        }
    }
    return @($indexes | ForEach-Object { $printers[$_ - 1] })
}

function Remove-SelectedCopies {
    $printers = @(Get-M404Printers)
    if ($printers.Count -eq 0) {
        Write-Log "No M404dn printer copies found. Nothing to remove." "WARN"
        return
    }
    $selected = @(Select-PrinterCopies -printers $printers)
    if ($selected.Count -eq 0) {
        Write-Log "Nothing selected. No changes made."
        return
    }
    Write-Host ""
    Write-Host "These copies will be removed (queued jobs on them are deleted):" -ForegroundColor Yellow
    $selected | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Yellow }
    if ($selected.Count -eq $printers.Count) {
        Write-Host "  This removes EVERY copy. The user cannot print until it is reinstalled." -ForegroundColor Red
    }
    if (-not (Confirm-Action "Remove them now?")) {
        Write-Log "Removal cancelled. No changes made."
        return
    }
    if (Remove-PrinterCopies -printers $selected) {
        Write-Log "Selected copies removed." "SUCCESS"
    } else {
        Write-Log "Some copies could not be removed. See the errors above." "ERROR"
    }
}

function Test-PrinterPort {
    param ([string]$ip)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect($ip, $rawPrintPort, $null, $null)
        if ($async.AsyncWaitHandle.WaitOne(3000, $false) -and $client.Connected) {
            $client.EndConnect($async)
            return $true
        }
        return $false
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Get-UsableDriver {
    # 1. Keep a driver that is already installed (prefer the one the current copies use).
    $installed = @(Get-M404Drivers)
    if ($installed.Count -gt 0) {
        $inUse = @(Get-M404Printers | ForEach-Object { $_.DriverName })
        $pick = $installed | Where-Object { $inUse -contains $_.Name -and $_.Name -like "*PCL*" } | Select-Object -First 1
        if (-not $pick) { $pick = $installed | Where-Object { $_.Name -like "*PCL*" } | Select-Object -First 1 }
        if (-not $pick) { $pick = $installed | Select-Object -First 1 }
        Write-Log "Using installed driver: $($pick.Name)" "SUCCESS"
        return $pick.Name
    }

    # 2. Driver package staged in the driver store but not installed as a printer driver.
    foreach ($name in $driverCandidates) {
        try {
            Add-PrinterDriver -Name $name -ErrorAction Stop
            Write-Log "Installed driver from the driver store: $name" "SUCCESS"
            return $name
        } catch {}
    }

    # 3. Ask for the HP driver package.
    Write-Host ""
    Write-Host "No HP M404 driver is on this PC (it is not built into Windows)." -ForegroundColor Yellow
    Write-Host "Download and extract the HP driver package, then enter the path to its .inf file:" -ForegroundColor Yellow
    Write-Host "  $hpDriverDownloadUrl" -ForegroundColor Cyan
    $infPath = Read-Host "Path to the driver .inf (blank = cancel)"
    if ([string]::IsNullOrWhiteSpace($infPath)) { return $null }
    if (-not (Test-Path $infPath)) {
        Write-Log "File not found: $infPath" "ERROR"
        return $null
    }
    $pnpOutput = & pnputil.exe /add-driver "$infPath" /install 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "pnputil could not stage the driver (exit $LASTEXITCODE): $($pnpOutput -join ' ')" "ERROR"
        return $null
    }
    foreach ($name in $driverCandidates) {
        try {
            Add-PrinterDriver -Name $name -ErrorAction Stop
            Write-Log "Installed driver: $name" "SUCCESS"
            return $name
        } catch {}
    }
    $name = Read-Host "Driver staged. Enter the exact driver model name from the .inf (blank = cancel)"
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }
    try {
        Add-PrinterDriver -Name $name -ErrorAction Stop
        return $name
    } catch {
        Write-Log "Could not install driver '$name': $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Invoke-NetworkReinstall {
    $ip = (Read-Host "Enter the HP M404dn's IP address").Trim()
    $parsed = $null
    if (-not [System.Net.IPAddress]::TryParse($ip, [ref]$parsed) -or $ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
        Write-Log "'$ip' is not a valid IPv4 address. No changes made." "ERROR"
        return $false
    }

    Write-Log "Testing the printer at $ip on TCP $rawPrintPort..."
    if (Test-PrinterPort -ip $ip) {
        Write-Log "Printer answered on $ip." "SUCCESS"
    } else {
        Write-Log "Nothing answered on $ip TCP $rawPrintPort. Check the cable, the IP on the printer's network page, and the DHCP reservation." "WARN"
        if (-not (Confirm-Action "Continue anyway?")) {
            Write-Log "Reinstall cancelled. No changes made."
            return $false
        }
    }

    $driverName = Get-UsableDriver
    if (-not $driverName) {
        Write-Log "No usable driver. Reinstall cancelled. No changes made." "ERROR"
        return $false
    }

    $oldCopies = @(Get-M404Printers)
    Write-Host ""
    Write-Host "Plan:" -ForegroundColor Cyan
    if ($oldCopies.Count -gt 0) {
        Write-Host "  Remove these copies (and clear their queued jobs):" -ForegroundColor Cyan
        $oldCopies | ForEach-Object { Write-Host "    - $($_.Name)  [port $($_.PortName)]" -ForegroundColor Cyan }
    }
    Write-Host "  Add '$newPrinterName' on TCP/IP port $ip with driver '$driverName'" -ForegroundColor Cyan
    Write-Host "  The HP driver is kept (not deleted)." -ForegroundColor Cyan
    if (-not (Confirm-Action "Go ahead?")) {
        Write-Log "Reinstall cancelled. No changes made."
        return $false
    }
    Write-AuditLog -action "HP M404dn Driver Reinstall" -details "Network reinstall started: IP $ip, driver $driverName, removing $($oldCopies.Count) copies"

    if ($oldCopies.Count -gt 0) {
        if (-not (Remove-PrinterCopies -printers $oldCopies)) {
            Write-Log "Some old copies could not be removed. Continuing with the new install." "WARN"
        }
    }

    # Reuse a TCP/IP port that already points at this IP, otherwise create one.
    $port = Get-PrinterPort -ErrorAction SilentlyContinue | Where-Object { $_.PrinterHostAddress -eq $ip } | Select-Object -First 1
    if ($port) {
        $portName = $port.Name
        Write-Log "Reusing existing port $portName for $ip."
    } else {
        $portName = $defaultPortName
        if (Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue) { $portName = "IP_$ip" }
        try {
            Add-PrinterPort -Name $portName -PrinterHostAddress $ip -ErrorAction Stop
            Write-Log "Created TCP/IP port $portName -> $ip." "SUCCESS"
        } catch {
            Write-Log "Failed to create the port: $($_.Exception.Message)" "ERROR"
            return $false
        }
    }

    $printerName = $newPrinterName
    if (Get-Printer -Name $printerName -ErrorAction SilentlyContinue) { $printerName = "$newPrinterName (Network)" }
    try {
        Add-Printer -Name $printerName -DriverName $driverName -PortName $portName -ErrorAction Stop
    } catch {
        Write-Log "Failed to add the printer: $($_.Exception.Message)" "ERROR"
        return $false
    }

    $check = Get-Printer -Name $printerName -ErrorAction SilentlyContinue
    if (-not $check) {
        Write-Log "The printer was not found after install." "ERROR"
        return $false
    }
    Write-Log "Installed '$printerName' on $portName with '$driverName'." "SUCCESS"
    Write-AuditLog -action "HP M404dn Driver Reinstall" -details "Installed $printerName on $portName ($ip) with $driverName"

    if (Confirm-Action "Send a Windows test page now?") {
        try {
            $wmiPrinter = Get-WmiObject -Class Win32_Printer -Filter "Name='$($printerName -replace "'", "''")'"
            $result = $wmiPrinter.PrintTestPage()
            if ($result.ReturnValue -eq 0) { Write-Log "Test page sent." "SUCCESS" } else { Write-Log "Test page returned code $($result.ReturnValue)." "WARN" }
        } catch {
            Write-Log "Failed to send test page: $($_.Exception.Message)" "WARN"
        }
    }

    Write-Host ""
    Write-Host "Set it as the default printer while logged in as the USER (Settings > Printers)." -ForegroundColor Yellow
    Write-Host "Default printers are per user, so setting it from this admin window would not apply to them." -ForegroundColor Yellow
    return $true
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

    Write-Host "  1. View Current Install (copies / ports / drivers / queued jobs)"
    Write-Host "  2. Network Reinstall (checks IP and driver first, then replaces old copies)"
    Write-Host "  3. Remove Selected Copies (pick duplicates or old USB/WSD copies)"
    Write-Host "  B. Back to HP M404dn Troubleshooter"
    Write-Host ""
}

if (-not (Test-Administrator)) {
    Write-Log "Administrator privileges are required. Restart the IT Troubleshooting Toolkit as Administrator." "ERROR"
    Write-Host "This tool requires Administrator privileges. Close the toolkit and restart it as Administrator." -ForegroundColor Yellow
    Read-Host "Press Enter to return to the HP M404dn Troubleshooter" | Out-Null
} else {

Write-AuditLog -action "HP M404dn Driver Reinstall" -details "Tool opened"
do {
    Show-Menu
    $choice = Read-Host "Select an option"
    switch ($choice) {
        "1" { Show-CurrentInstall; Read-Host "Press Enter to continue" | Out-Null }
        "2" {
            Write-Log "========== Network Reinstall =========="
            Show-CurrentInstall
            if (Invoke-NetworkReinstall) {
                Write-Log "========== Network Reinstall Complete ==========" "SUCCESS"
            } else {
                Write-Log "========== Network Reinstall FAILED or cancelled (see messages above) ==========" "ERROR"
                Write-AuditLog -action "HP M404dn Driver Reinstall" -level "WARN" -details "Network reinstall failed or cancelled"
            }
            Read-Host "Press Enter to continue" | Out-Null
        }
        "3" {
            Show-CurrentInstall
            Remove-SelectedCopies
            Read-Host "Press Enter to continue" | Out-Null
        }
        "B" { }
        "b" { }
        default { Write-Host "Invalid selection." -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
    }
} while ($choice -ne "B" -and $choice -ne "b")

Write-Log "Driver reinstall tool session ended."
}
