<#
.SYNOPSIS
FTP Troubleshooter Tool - Interactive Launcher Menu

.DESCRIPTION
Name: launch_menu.ps1
Version: 1.3.0
Purpose: Interactive menu for downloading/installing and running the FTP Troubleshooter Tool,
         plus managing the StorageCraft ImageManager service
Path: /scripts/launch_menu.ps1
Copyright: 2025

Key Features:
- Download and install latest version from GitHub
- Automatic extraction to C:\ITTools\FTPFIX
- Run the FTP troubleshooter tool
- Start, stop, and restart StorageCraft ImageManager service
- User-friendly menu interface

Input: 
- User menu selection (1-6 or Q)

Output:
- Downloaded and extracted files to C:\sndayton\ftpfix
- Launched FTP troubleshooter tool
- Service status changes

Dependencies:
- Windows PowerShell 5.1 or higher
- Internet connection (for download option)
- Expand-Archive cmdlet (built-in)
- Administrator privileges (for service management)

Change Log:
2025-11-21 v1.0.0 - Initial release
2025-11-21 v1.1.0 - Added StorageCraft ImageManager service management options
2025-11-21 v1.2.0 - Updated installation path to C:\ITTools\FTPFIX
2025-11-21 v1.3.0 - Fixed file overwrite during installation; always show menu first

.NOTES
This launcher provides an easy way to install, run, and manage the FTP Troubleshooter Tool
and StorageCraft ImageManager service.
#>

# Configuration
$repoOwner = "SuperiorNetworks"
$repoName = "Ftp-Troubleshooter-Tool"
$installPath = "C:\ITTools\FTPFIX"
$scriptName = "ftp_troubleshooter_tool.ps1"
$serviceName = "StorageCraft ImageManager"

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-Menu {
    Clear-Host
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  FTP Troubleshooter Tool - Launcher" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "FTP Tool Management:" -ForegroundColor White
    Write-Host "  1. Download and Install Latest Version" -ForegroundColor Green
    Write-Host "  2. Run FTP Troubleshooter Tool" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "StorageCraft ImageManager Service:" -ForegroundColor White
    Write-Host "  3. Start ImageManager Service" -ForegroundColor Green
    Write-Host "  4. Stop ImageManager Service" -ForegroundColor Red
    Write-Host "  5. Restart ImageManager Service" -ForegroundColor Yellow
    Write-Host "  6. Check ImageManager Service Status" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Q. Quit" -ForegroundColor Red
    Write-Host ""
    Write-Host "Installation Path: $installPath" -ForegroundColor Gray
    
    # Show current service status
    try {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            $statusColor = if ($service.Status -eq 'Running') { 'Green' } else { 'Yellow' }
            Write-Host "ImageManager Status: " -NoNewline -ForegroundColor Gray
            Write-Host $service.Status -ForegroundColor $statusColor
        }
    } catch {
        # Service not found, silently continue
    }
    
    Write-Host ""
}

function Download-And-Install {
    Write-Host "`n=== Downloading Latest Version ===" -ForegroundColor Cyan
    
    try {
        # Create installation directory if it doesn't exist
        if (-not (Test-Path $installPath)) {
            Write-Host "Creating installation directory: $installPath" -ForegroundColor Yellow
            New-Item -ItemType Directory -Path $installPath -Force | Out-Null
        }

        # Download the latest release as ZIP
        $zipUrl = "https://github.com/$repoOwner/$repoName/archive/refs/heads/master.zip"
        $zipFile = Join-Path $env:TEMP "ftp-troubleshooter.zip"
        $extractPath = Join-Path $env:TEMP "ftp-troubleshooter-extract"

        Write-Host "Downloading from GitHub..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing

        Write-Host "Extracting files..." -ForegroundColor Yellow
        
        # Remove old extraction folder if it exists
        if (Test-Path $extractPath) {
            Remove-Item -Path $extractPath -Recurse -Force
        }
        
        Expand-Archive -Path $zipFile -DestinationPath $extractPath -Force

        # Copy files from extracted folder to installation path (overwrite existing)
        $sourceFolder = Join-Path $extractPath "$repoName-master"
        Write-Host "Installing to $installPath..." -ForegroundColor Yellow
        Write-Host "Overwriting existing files if present..." -ForegroundColor Yellow
        
        # Copy each item individually with force to ensure overwrite
        Get-ChildItem -Path $sourceFolder -File | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $installPath -Force
        }
        
        # Copy directories recursively with force
        Get-ChildItem -Path $sourceFolder -Directory | ForEach-Object {
            $destDir = Join-Path $installPath $_.Name
            if (Test-Path $destDir) {
                Remove-Item -Path $destDir -Recurse -Force
            }
            Copy-Item -Path $_.FullName -Destination $installPath -Recurse -Force
        }

        # Cleanup
        Remove-Item -Path $zipFile -Force
        Remove-Item -Path $extractPath -Recurse -Force

        Write-Host "`n✓ Installation complete!" -ForegroundColor Green
        Write-Host "Files installed to: $installPath" -ForegroundColor Green
        
    }
    catch {
        Write-Error "Failed to download and install: $_"
        Write-Host "`nTroubleshooting tips:" -ForegroundColor Yellow
        Write-Host "- Check your internet connection" -ForegroundColor Yellow
        Write-Host "- Ensure you have write permissions to $installPath" -ForegroundColor Yellow
        Write-Host "- Try running PowerShell as Administrator" -ForegroundColor Yellow
    }
    
    Write-Host "`nPress any key to return to menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Run-Troubleshooter {
    Write-Host "`n=== Launching FTP Troubleshooter Tool ===" -ForegroundColor Cyan
    
    $scriptPath = Join-Path $installPath $scriptName
    
    if (Test-Path $scriptPath) {
        Write-Host "Starting $scriptName..." -ForegroundColor Green
        Write-Host ""
        
        # Run the script
        & $scriptPath
        
    }
    else {
        Write-Host "`n✗ Error: FTP Troubleshooter Tool not found!" -ForegroundColor Red
        Write-Host "Expected location: $scriptPath" -ForegroundColor Yellow
        Write-Host "`nPlease use Option 1 to download and install first." -ForegroundColor Yellow
        Write-Host "`nPress any key to return to menu..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Start-ImageManagerService {
    Write-Host "`n=== Starting StorageCraft ImageManager Service ===" -ForegroundColor Cyan
    
    if (-not (Test-Administrator)) {
        Write-Host "✗ Error: Administrator privileges required!" -ForegroundColor Red
        Write-Host "Please run this script as Administrator to manage services." -ForegroundColor Yellow
        Write-Host "`nPress any key to return to menu..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    try {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        
        if ($service.Status -eq 'Running') {
            Write-Host "✓ Service is already running." -ForegroundColor Green
        }
        else {
            Write-Host "Starting service..." -ForegroundColor Yellow
            Start-Service -Name $serviceName
            Start-Sleep -Seconds 2
            $service.Refresh()
            Write-Host "✓ Service started successfully!" -ForegroundColor Green
            Write-Host "Current status: $($service.Status)" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "✗ Error: $_" -ForegroundColor Red
        Write-Host "`nPossible reasons:" -ForegroundColor Yellow
        Write-Host "- Service not installed" -ForegroundColor Yellow
        Write-Host "- Insufficient permissions" -ForegroundColor Yellow
        Write-Host "- Service is disabled" -ForegroundColor Yellow
    }
    
    Write-Host "`nPress any key to return to menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Stop-ImageManagerService {
    Write-Host "`n=== Stopping StorageCraft ImageManager Service ===" -ForegroundColor Cyan
    
    if (-not (Test-Administrator)) {
        Write-Host "✗ Error: Administrator privileges required!" -ForegroundColor Red
        Write-Host "Please run this script as Administrator to manage services." -ForegroundColor Yellow
        Write-Host "`nPress any key to return to menu..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    try {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        
        if ($service.Status -eq 'Stopped') {
            Write-Host "✓ Service is already stopped." -ForegroundColor Green
        }
        else {
            Write-Host "Stopping service..." -ForegroundColor Yellow
            Stop-Service -Name $serviceName -Force
            Start-Sleep -Seconds 2
            $service.Refresh()
            Write-Host "✓ Service stopped successfully!" -ForegroundColor Green
            Write-Host "Current status: $($service.Status)" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "✗ Error: $_" -ForegroundColor Red
        Write-Host "`nPossible reasons:" -ForegroundColor Yellow
        Write-Host "- Service not installed" -ForegroundColor Yellow
        Write-Host "- Insufficient permissions" -ForegroundColor Yellow
        Write-Host "- Service has dependent services" -ForegroundColor Yellow
    }
    
    Write-Host "`nPress any key to return to menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Restart-ImageManagerService {
    Write-Host "`n=== Restarting StorageCraft ImageManager Service ===" -ForegroundColor Cyan
    
    if (-not (Test-Administrator)) {
        Write-Host "✗ Error: Administrator privileges required!" -ForegroundColor Red
        Write-Host "Please run this script as Administrator to manage services." -ForegroundColor Yellow
        Write-Host "`nPress any key to return to menu..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    try {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        
        Write-Host "Current status: $($service.Status)" -ForegroundColor Cyan
        Write-Host "Restarting service..." -ForegroundColor Yellow
        
        Restart-Service -Name $serviceName -Force
        Start-Sleep -Seconds 3
        $service.Refresh()
        
        Write-Host "✓ Service restarted successfully!" -ForegroundColor Green
        Write-Host "New status: $($service.Status)" -ForegroundColor Cyan
    }
    catch {
        Write-Host "✗ Error: $_" -ForegroundColor Red
        Write-Host "`nPossible reasons:" -ForegroundColor Yellow
        Write-Host "- Service not installed" -ForegroundColor Yellow
        Write-Host "- Insufficient permissions" -ForegroundColor Yellow
        Write-Host "- Service has dependent services" -ForegroundColor Yellow
    }
    
    Write-Host "`nPress any key to return to menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Get-ImageManagerServiceStatus {
    Write-Host "`n=== StorageCraft ImageManager Service Status ===" -ForegroundColor Cyan
    
    try {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        
        Write-Host "`nService Name: " -NoNewline
        Write-Host $service.Name -ForegroundColor White
        
        Write-Host "Display Name: " -NoNewline
        Write-Host $service.DisplayName -ForegroundColor White
        
        $statusColor = switch ($service.Status) {
            'Running' { 'Green' }
            'Stopped' { 'Red' }
            default { 'Yellow' }
        }
        Write-Host "Status: " -NoNewline
        Write-Host $service.Status -ForegroundColor $statusColor
        
        Write-Host "Startup Type: " -NoNewline
        Write-Host $service.StartType -ForegroundColor White
        
        # Check if service can be stopped/paused
        Write-Host "`nCan Stop: " -NoNewline
        Write-Host $service.CanStop -ForegroundColor $(if ($service.CanStop) { 'Green' } else { 'Red' })
        
        Write-Host "Can Pause: " -NoNewline
        Write-Host $service.CanPauseAndContinue -ForegroundColor $(if ($service.CanPauseAndContinue) { 'Green' } else { 'Red' })
        
    }
    catch {
        Write-Host "`n✗ Service not found or not accessible!" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Yellow
        Write-Host "`nPossible reasons:" -ForegroundColor Yellow
        Write-Host "- StorageCraft ImageManager is not installed" -ForegroundColor Yellow
        Write-Host "- Service name has changed" -ForegroundColor Yellow
        Write-Host "- Insufficient permissions to query service" -ForegroundColor Yellow
    }
    
    Write-Host "`nPress any key to return to menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main menu loop
do {
    Show-Menu
    $choice = Read-Host "Select an option"
    
    switch ($choice.ToUpper()) {
        '1' {
            Download-And-Install
        }
        '2' {
            Run-Troubleshooter
        }
        '3' {
            Start-ImageManagerService
        }
        '4' {
            Stop-ImageManagerService
        }
        '5' {
            Restart-ImageManagerService
        }
        '6' {
            Get-ImageManagerServiceStatus
        }
        'Q' {
            Write-Host "`nExiting..." -ForegroundColor Cyan
            exit 0
        }
        default {
            Write-Host "`nInvalid selection. Please choose 1-6 or Q." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($true)
