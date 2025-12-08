<#
.SYNOPSIS
StorageCraft Troubleshooter - Submenu for StorageCraft backup tools

.DESCRIPTION
Name: storagecraft_troubleshooter.ps1
Version: 1.1.1
Purpose: Centralized submenu for StorageCraft backup troubleshooting tools.
         Provides access to Manual FTP Tool and ImageManager service management.
Path: /scripts/storagecraft_troubleshooter.ps1
Copyright: 2025

Key Features:
- Manual FTP file upload tool (backup for ImageManager failures)
- ImageManager service management (start/stop/restart/status)
- User-friendly submenu interface
- Real-time service status display
- Administrator privilege detection
- Superior Networks branding

Input: 
- User menu selection (1-5 or B for Back)

Output:
- Launched FTP troubleshooter tool
- Service status changes
- Service information display

Dependencies:
- Windows PowerShell 5.1 or higher
- ftp_troubleshooter_tool.ps1 (for Manual FTP Tool)
- Administrator privileges (for service management)

Change Log:
2025-11-22 v1.0.0 - Initial release - Extracted from main launcher as separate submenu
2025-11-22 v1.1.0 - Added FTP upload log viewer function
2025-12-08 v1.1.1 - Fixed version display; Fixed Manual FTP Tool launch to wait for completion

.NOTES
This submenu provides focused access to StorageCraft backup troubleshooting tools.
Designed for IT professionals and MSPs managing StorageCraft backup solutions.
#>

# Configuration
$installPath = "C:\ITTools\Scripts"
$ftpScriptName = "ftp_troubleshooter_tool.ps1"
$serviceName = "StorageCraft ImageManager"

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-StorageCraftMenu {
    Clear-Host
    
    # StorageCraft Troubleshooter Header
    Write-Host ""
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host "                     SUPERIOR NETWORKS LLC                        " -ForegroundColor White
    Write-Host "              StorageCraft Troubleshooter - v1.1.1                " -ForegroundColor Cyan
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Manual Tools:" -ForegroundColor White
    Write-Host "    1. Manual FTP Tool" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ImageManager Service Management:" -ForegroundColor White
    Write-Host "    2. Start ImageManager Service" -ForegroundColor Green
    Write-Host "    3. Stop ImageManager Service" -ForegroundColor Red
    Write-Host "    4. Restart ImageManager Service" -ForegroundColor Yellow
    Write-Host "    5. Check ImageManager Service Status" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Logs and Diagnostics:" -ForegroundColor White
    Write-Host "    6. View FTP Upload Logs" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "    B. Back to Main Menu" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Installation Path: $installPath" -ForegroundColor Gray
    
    # Show current service status
    try {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            $statusColor = if ($service.Status -eq 'Running') { 'Green' } else { 'Yellow' }
            Write-Host "  ImageManager Status: " -NoNewline -ForegroundColor Gray
            Write-Host $service.Status -ForegroundColor $statusColor
        }
    } catch {
        # Service not found, silently continue
    }
    
    Write-Host ""
}

function Run-ManualFTPTool {
    Write-Host "`n=== Launching Manual FTP Tool ===" -ForegroundColor Cyan
    
    $scriptPath = Join-Path $installPath $ftpScriptName
    
    if (Test-Path $scriptPath) {
        Write-Host "Starting FTP Troubleshooter..." -ForegroundColor Green
        Write-Host "Script location: $scriptPath" -ForegroundColor Gray
        Write-Host ""
        
        & $scriptPath
        
        Write-Host "`nPress any key to return to menu..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    else {
        Write-Host "`nError: Manual FTP Tool not found!" -ForegroundColor Red
        Write-Host "Expected location: $scriptPath" -ForegroundColor Yellow
        Write-Host "`nPlease use the main menu to download and install the toolkit first." -ForegroundColor Yellow
        Write-Host "`nPress any key to return to menu..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Start-ImageManagerService {
    Write-Host "`n=== Starting ImageManager Service ===" -ForegroundColor Cyan
    
    if (-not (Test-Administrator)) {
        Write-Host "`nError: Administrator privileges required!" -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator to manage services." -ForegroundColor Yellow
        Write-Host "`nPress any key to return to menu..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    try {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        
        if ($service.Status -eq 'Running') {
            Write-Host "`nService is already running." -ForegroundColor Yellow
        }
        else {
            Write-Host "`nStarting service..." -ForegroundColor Green
            Start-Service -Name $serviceName -ErrorAction Stop
            Start-Sleep -Seconds 2
            $service = Get-Service -Name $serviceName
            Write-Host "Service Status: " -NoNewline -ForegroundColor Gray
            Write-Host $service.Status -ForegroundColor Green
        }
    }
    catch {
        Write-Host "`nError starting service: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`nPress any key to return to menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Stop-ImageManagerService {
    Write-Host "`n=== Stopping ImageManager Service ===" -ForegroundColor Cyan
    
    if (-not (Test-Administrator)) {
        Write-Host "`nError: Administrator privileges required!" -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator to manage services." -ForegroundColor Yellow
        Write-Host "`nPress any key to return to menu..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    try {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        
        if ($service.Status -eq 'Stopped') {
            Write-Host "`nService is already stopped." -ForegroundColor Yellow
        }
        else {
            Write-Host "`nStopping service..." -ForegroundColor Yellow
            Stop-Service -Name $serviceName -Force -ErrorAction Stop
            Start-Sleep -Seconds 2
            $service = Get-Service -Name $serviceName
            Write-Host "Service Status: " -NoNewline -ForegroundColor Gray
            Write-Host $service.Status -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "`nError stopping service: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`nPress any key to return to menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Restart-ImageManagerService {
    Write-Host "`n=== Restarting ImageManager Service ===" -ForegroundColor Cyan
    
    if (-not (Test-Administrator)) {
        Write-Host "`nError: Administrator privileges required!" -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator to manage services." -ForegroundColor Yellow
        Write-Host "`nPress any key to return to menu..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    try {
        Write-Host "`nRestarting service..." -ForegroundColor Yellow
        Restart-Service -Name $serviceName -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
        $service = Get-Service -Name $serviceName
        Write-Host "Service Status: " -NoNewline -ForegroundColor Gray
        Write-Host $service.Status -ForegroundColor Green
        Write-Host "`nService restarted successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "`nError restarting service: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`nPress any key to return to menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Get-ImageManagerServiceStatus {
    Write-Host "`n=== ImageManager Service Status ===" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        
        Write-Host "  Service Name: $($service.Name)" -ForegroundColor White
        Write-Host "  Display Name: $($service.DisplayName)" -ForegroundColor White
        Write-Host "  Status:       " -NoNewline -ForegroundColor Gray
        $statusColor = if ($service.Status -eq 'Running') { 'Green' } else { 'Yellow' }
        Write-Host $service.Status -ForegroundColor $statusColor
        Write-Host "  Start Type:   $($service.StartType)" -ForegroundColor Gray
        Write-Host "  Can Stop:     " -NoNewline -ForegroundColor Gray
        Write-Host $service.CanStop -ForegroundColor $(if ($service.CanStop) { 'Green' } else { 'Red' })
        
        Write-Host "  Can Pause:    " -NoNewline -ForegroundColor Gray
        Write-Host $service.CanPauseAndContinue -ForegroundColor $(if ($service.CanPauseAndContinue) { 'Green' } else { 'Red' })
    }
    catch {
        Write-Host "`nError: Service not found or inaccessible" -ForegroundColor Red
        Write-Host "Service Name: $serviceName" -ForegroundColor Yellow
    }
    
    Write-Host "`nPress any key to return to menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function View-FTPUploadLogs {
    Write-Host "`n=== FTP Upload Logs ===" -ForegroundColor Cyan
    Write-Host ""
    
    $logFile = "C:\ITTools\Scripts\Logs\ftp_upload_log.txt"
    
    if (-not (Test-Path $logFile)) {
        Write-Host "No log file found." -ForegroundColor Yellow
        Write-Host "Log file location: $logFile" -ForegroundColor Gray
        Write-Host "`nThe log file will be created after the first FTP upload." -ForegroundColor Gray
    }
    else {
        $logInfo = Get-Item $logFile
        $logSizeKB = [math]::Round($logInfo.Length / 1KB, 2)
        
        Write-Host "Log File: $logFile" -ForegroundColor Gray
        Write-Host "Size: $logSizeKB KB | Last Modified: $($logInfo.LastWriteTime)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Showing last 100 lines:" -ForegroundColor White
        Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray
        Write-Host ""
        
        try {
            $logContent = Get-Content $logFile -Tail 100
            
            foreach ($line in $logContent) {
                # Color-code log entries based on level
                if ($line -match "\[ERROR\]") {
                    Write-Host $line -ForegroundColor Red
                }
                elseif ($line -match "\[WARN\]") {
                    Write-Host $line -ForegroundColor Yellow
                }
                elseif ($line -match "\[SUCCESS\]") {
                    Write-Host $line -ForegroundColor Green
                }
                else {
                    Write-Host $line -ForegroundColor White
                }
            }
        }
        catch {
            Write-Host "Error reading log file: $_" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray
    }
    
    Write-Host "`nPress any key to return to menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main menu loop
do {
    Show-StorageCraftMenu
    Write-Host "  Select an option (1-6 or B): " -NoNewline -ForegroundColor White
    $choice = Read-Host
    
    switch ($choice.ToUpper()) {
        '1' {
            Run-ManualFTPTool
        }
        '2' {
            Start-ImageManagerService
        }
        '3' {
            Stop-ImageManagerService
        }
        '4' {
            Restart-ImageManagerService
        }
        '5' {
            Get-ImageManagerServiceStatus
        }
        '6' {
            View-FTPUploadLogs
        }
        'B' {
            Write-Host "`nReturning to main menu..." -ForegroundColor Cyan
            exit 0
        }
        default {
            Write-Host "`nInvalid selection. Please choose 1-5 or B." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($true)
