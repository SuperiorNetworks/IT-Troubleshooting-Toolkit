<#
.SYNOPSIS
FTP Troubleshooter Tool - Interactive Launcher Menu

.DESCRIPTION
Name: launch_menu.ps1
Version: 1.0.0
Purpose: Interactive menu for downloading/installing and running the FTP Troubleshooter Tool
Path: /scripts/launch_menu.ps1
Copyright: 2025

Key Features:
- Download and install latest version from GitHub
- Automatic extraction to C:\sndayton\ftpfix
- Run the FTP troubleshooter tool
- User-friendly menu interface

Input: 
- User menu selection (1, 2, or Q)

Output:
- Downloaded and extracted files to C:\sndayton\ftpfix
- Launched FTP troubleshooter tool

Dependencies:
- Windows PowerShell 5.1 or higher
- Internet connection (for download option)
- Expand-Archive cmdlet (built-in)

Change Log:
2025-11-21 v1.0.0 - Initial release

.NOTES
This launcher provides an easy way to install and run the FTP Troubleshooter Tool.
#>

# Configuration
$repoOwner = "SuperiorNetworks"
$repoName = "Ftp-Troubleshooter-Tool"
$installPath = "C:\sndayton\ftpfix"
$scriptName = "ftp_troubleshooter_tool.ps1"

function Show-Menu {
    Clear-Host
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  FTP Troubleshooter Tool - Launcher" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Download and Install Latest Version" -ForegroundColor Green
    Write-Host "2. Run FTP Troubleshooter Tool" -ForegroundColor Yellow
    Write-Host "Q. Quit" -ForegroundColor Red
    Write-Host ""
    Write-Host "Installation Path: $installPath" -ForegroundColor Gray
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

        # Copy files from extracted folder to installation path
        $sourceFolder = Join-Path $extractPath "$repoName-master"
        Write-Host "Installing to $installPath..." -ForegroundColor Yellow
        
        Get-ChildItem -Path $sourceFolder | Copy-Item -Destination $installPath -Recurse -Force

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
        'Q' {
            Write-Host "`nExiting..." -ForegroundColor Cyan
            exit 0
        }
        default {
            Write-Host "`nInvalid selection. Please choose 1, 2, or Q." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($true)
