<#
.SYNOPSIS
IT Troubleshooting Toolkit - Interactive Launcher Menu

.DESCRIPTION
Name: launch_menu.ps1
Version: 2.3.0
Purpose: Centralized launcher menu for IT troubleshooting tools and service management.
         Provides quick access to FTP file transfer tools and StorageCraft ImageManager service control.
Path: /scripts/launch_menu.ps1
Copyright: 2025

Key Features:
- Self-updating toolkit installation from GitHub
- Automatic extraction to C:\ITTools\Scripts with file overwrite
- FTP Troubleshooter Tool access (manual file uploads)
- StorageCraft ImageManager service management (start/stop/restart/status)
- User-friendly color-coded menu interface
- Real-time service status display
- Administrator privilege detection
- Superior Networks branding

Input: 
- User menu selection (1-3 or Q)

Output:
- Downloaded and extracted files to C:\ITTools\Scripts
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
2025-11-21 v1.2.0 - Updated installation path to C:\ITTools\Scripts
2025-11-21 v1.3.0 - Fixed file overwrite during installation; always show menu first
2025-11-21 v1.4.0 - Rebranded as IT Troubleshooting Toolkit Launcher
2025-11-21 v1.5.0 - Updated installation path to C:\ITTools\Scripts
2025-11-22 v1.6.0 - Integrated Superior Networks branding and color scheme
2025-11-22 v1.7.0 - Fixed encoding issues with ASCII art branding
2025-11-22 v2.0.0 - Added MassGrave PowerShell Utilities integration; Renamed repo to IT-Troubleshooting-Toolkit
2025-11-22 v2.1.0 - Reorganized menu: Grouped StorageCraft tools under 'StorageCraft Troubleshooter'; Renamed FTP tool to 'Manual FTP Tool'
2025-11-22 v2.2.0 - Created separate StorageCraft Troubleshooter script with submenu; Simplified main launcher
2025-11-22 v2.3.0 - Enhanced Manual FTP Tool with retry logic, resume support, and logging; Added log viewer

.NOTES
This launcher provides centralized access to multiple IT troubleshooting tools and utilities.
Designed for IT professionals and MSPs to streamline common troubleshooting tasks.
#>

# Configuration
$repoOwner = "SuperiorNetworks"
$repoName = "IT-Troubleshooting-Toolkit"
$installPath = "C:\ITTools\Scripts"
$scriptName = "ftp_troubleshooter_tool.ps1"
$serviceName = "StorageCraft ImageManager"

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-Menu {
    Clear-Host
    
    # Superior Networks Branding Header
    Write-Host ""
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host "                     SUPERIOR NETWORKS LLC                        " -ForegroundColor White
    Write-Host "               IT Troubleshooting Toolkit - v2.3.0                " -ForegroundColor Cyan
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Toolkit Management:" -ForegroundColor White
    Write-Host "    1. Download and Install Latest Version" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Troubleshooting Tools:" -ForegroundColor White
    Write-Host "    2. StorageCraft Troubleshooter" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Windows/Office Activation:" -ForegroundColor White
    Write-Host "    3. Run MassGrave Activation Scripts (MAS)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "    Q. Quit" -ForegroundColor Red
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

        Write-Host "`nInstallation complete!" -ForegroundColor Green
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

function Run-StorageCraftTroubleshooter {
    Write-Host "`n=== Launching StorageCraft Troubleshooter ===" -ForegroundColor Cyan
    
    $scScriptName = "storagecraft_troubleshooter.ps1"
    $scriptPath = Join-Path $installPath $scScriptName
    
    if (Test-Path $scriptPath) {
        Write-Host "Starting StorageCraft Troubleshooter..." -ForegroundColor Green
        Write-Host ""
        
        # Run the StorageCraft submenu script
        & $scriptPath
        
    }
    else {
        Write-Host "`nError: StorageCraft Troubleshooter not found!" -ForegroundColor Red
        Write-Host "Expected location: $scriptPath" -ForegroundColor Yellow
        Write-Host "`nPlease use Option 1 to download and install first." -ForegroundColor Yellow
        Write-Host "`nPress any key to return to menu..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Run-MassGraveActivation {
    Write-Host "`n=== MassGrave Activation Scripts (MAS) ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This will launch the Microsoft Activation Scripts (MAS) utility." -ForegroundColor Yellow
    Write-Host "MAS provides activation methods for Windows and Office products." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Features:" -ForegroundColor White
    Write-Host "  - HWID (Digital License) for Windows 10-11" -ForegroundColor Gray
    Write-Host "  - Ohook for Office (Permanent)" -ForegroundColor Gray
    Write-Host "  - TSforge for Windows/ESU/Office" -ForegroundColor Gray
    Write-Host "  - Online KMS (180 days, renewable)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Source: https://massgrave.dev/" -ForegroundColor Cyan
    Write-Host ""
    
    $confirm = Read-Host "Do you want to launch MAS? (Y/N)"
    
    if ($confirm.ToUpper() -eq 'Y') {
        Write-Host ""
        Write-Host "Launching MassGrave Activation Scripts..." -ForegroundColor Green
        Write-Host "Please wait..." -ForegroundColor Yellow
        Write-Host ""
        
        try {
            # Execute the MAS script
            Invoke-Expression (Invoke-RestMethod -Uri 'https://get.activated.win')
        }
        catch {
            Write-Host "Error launching MAS: $_" -ForegroundColor Red
            Write-Host ""
            Write-Host "Troubleshooting:" -ForegroundColor Yellow
            Write-Host "- Check your internet connection" -ForegroundColor Yellow
            Write-Host "- Verify the URL is not blocked by your ISP/DNS" -ForegroundColor Yellow
            Write-Host "- Try running PowerShell as Administrator" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to return to menu..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
    else {
        Write-Host ""
        Write-Host "MAS launch cancelled." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to return to menu..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# Main menu loop
do {
    Show-Menu
    Write-Host "  Select an option (1-3 or Q): " -NoNewline -ForegroundColor White
    $choice = Read-Host
    
    switch ($choice.ToUpper()) {
        '1' {
            Download-And-Install
        }
        '2' {
            Run-StorageCraftTroubleshooter
        }
        '3' {
            Run-MassGraveActivation
        }
        'Q' {
            Write-Host "`nExiting..." -ForegroundColor Cyan
            exit 0
        }
        default {
            Write-Host "`nInvalid selection. Please choose 1-3 or Q." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($true)
