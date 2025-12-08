<#
.SYNOPSIS
IT Troubleshooting Toolkit - Bootstrap Installer

.DESCRIPTION
Smart launcher that automatically installs or updates the toolkit and runs it.
Can be run from anywhere - handles everything automatically.

.USAGE
PowerShell.exe -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/bootstrap.ps1 | iex"

Or save this file and run:
PowerShell.exe -ExecutionPolicy Bypass -File bootstrap.ps1

.COPYRIGHT
2025 Superior Networks LLC
#>

# Configuration
$installPath = "C:\ITTools\Scripts"
$launcherScript = Join-Path $installPath "launch_menu.ps1"
$githubZipUrl = "https://github.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/archive/refs/heads/master.zip"
$tempDir = "C:\ITTools\Temp"

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "      IT Troubleshooting Toolkit - Bootstrap Installer          " -ForegroundColor White
Write-Host "                  Superior Networks LLC                          " -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# Function to get version from file
function Get-InstalledVersion {
    if (Test-Path $launcherScript) {
        $content = Get-Content $launcherScript -Raw
        if ($content -match 'Version:\s*(\d+\.\d+\.\d+)') {
            return [version]$matches[1]
        }
    }
    return $null
}

# Function to get latest version from GitHub
function Get-LatestVersion {
    try {
        $rawUrl = "https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/launch_menu.ps1"
        $content = Invoke-WebRequest -Uri $rawUrl -UseBasicParsing -TimeoutSec 10
        if ($content.Content -match 'Version:\s*(\d+\.\d+\.\d+)') {
            return [version]$matches[1]
        }
    }
    catch {
        Write-Host "Warning: Could not check for updates. Proceeding with local version..." -ForegroundColor Yellow
    }
    return $null
}

# Function to download and install toolkit
function Install-Toolkit {
    param([bool]$isUpdate = $false)
    
    try {
        # Create directories
        if (-not (Test-Path $installPath)) {
            New-Item -ItemType Directory -Path $installPath -Force | Out-Null
        }
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        
        # Download
        $zipFile = Join-Path $tempDir "toolkit.zip"
        Write-Host "Downloading from GitHub..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $githubZipUrl -OutFile $zipFile -UseBasicParsing
        
        # Extract
        $extractPath = Join-Path $tempDir "extract"
        if (Test-Path $extractPath) {
            Remove-Item -Path $extractPath -Recurse -Force
        }
        Write-Host "Extracting files..." -ForegroundColor Yellow
        Expand-Archive -Path $zipFile -DestinationPath $extractPath -Force
        
        # Find source folder
        $sourceFolder = Join-Path $extractPath "IT-Troubleshooting-Toolkit-master"
        
        if ($isUpdate) {
            Write-Host "Installing update..." -ForegroundColor Yellow
        }
        else {
            Write-Host "Installing toolkit..." -ForegroundColor Yellow
        }
        
        # Copy files
        Get-ChildItem -Path $sourceFolder -File | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $installPath -Force
        }
        
        # Copy directories
        Get-ChildItem -Path $sourceFolder -Directory | ForEach-Object {
            $destDir = Join-Path $installPath $_.Name
            if (Test-Path $destDir) {
                Remove-Item -Path $destDir -Recurse -Force
            }
            Copy-Item -Path $_.FullName -Destination $installPath -Recurse -Force
        }
        
        # Cleanup
        Remove-Item -Path $zipFile -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-Host "✓ Installation complete!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ Installation failed: $_" -ForegroundColor Red
        return $false
    }
}

# Main Logic
Write-Host "Checking installation..." -ForegroundColor Cyan

$installedVersion = Get-InstalledVersion

if ($null -eq $installedVersion) {
    # Not installed - install it
    Write-Host "Toolkit not found. Installing..." -ForegroundColor Yellow
    Write-Host ""
    
    if (Install-Toolkit -isUpdate $false) {
        $installedVersion = Get-InstalledVersion
        Write-Host ""
        Write-Host "✓ Installed IT Troubleshooting Toolkit v$installedVersion" -ForegroundColor Green
        Write-Host "  Location: $installPath" -ForegroundColor Gray
    }
    else {
        Write-Host ""
        Write-Host "Installation failed. Please check your internet connection and try again." -ForegroundColor Red
        Write-Host ""
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}
else {
    # Already installed - check for updates
    Write-Host "✓ Toolkit found: v$installedVersion" -ForegroundColor Green
    Write-Host "  Location: $installPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Checking for updates..." -ForegroundColor Cyan
    
    $latestVersion = Get-LatestVersion
    
    if ($null -ne $latestVersion -and $latestVersion -gt $installedVersion) {
        Write-Host "Update available: v$installedVersion → v$latestVersion" -ForegroundColor Yellow
        Write-Host ""
        
        if (Install-Toolkit -isUpdate $true) {
            $installedVersion = Get-InstalledVersion
            Write-Host ""
            Write-Host "✓ Updated to v$installedVersion" -ForegroundColor Green
        }
    }
    else {
        Write-Host "✓ Already up-to-date" -ForegroundColor Green
    }
}

# Launch the toolkit
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "                   Launching Toolkit...                          " -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

Start-Sleep -Seconds 1

# Execute the launcher script
& $launcherScript
