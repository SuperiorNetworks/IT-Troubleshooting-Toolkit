<#
.SYNOPSIS
IT Troubleshooting Toolkit - Bootstrap Installer (PowerShell 4.0+ Compatible)

.DESCRIPTION
Smart launcher that automatically installs or updates the toolkit and runs it.
Compatible with PowerShell 4.0+ (Windows Server 2012 R2, Windows 7, and newer).
Can be run from anywhere - handles everything automatically.

.USAGE
For Windows Server 2012 R2 / Windows 7/8 (PowerShell 4.0), run this command:

[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;irm https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/bootstrap_ps4.ps1|iex

Note: No spaces around operators (=, ;, |) for PowerShell 4.0 compatibility

Or save this file and run:
PowerShell.exe -ExecutionPolicy Bypass -File bootstrap_ps4.ps1

.REQUIREMENTS
- PowerShell 4.0 or higher
- .NET Framework 4.5 or higher (for ZIP extraction)

.COPYRIGHT
2025 Superior Networks LLC
#>

# Enable TLS 1.2 for GitHub downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Configuration
$installPath = "C:\ITTools\Scripts"
$launcherScript = Join-Path $installPath "launch_menu.ps1"
$githubZipUrl = "https://github.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/archive/refs/heads/master.zip"
$tempDir = "C:\ITTools\Temp"

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "      IT Troubleshooting Toolkit - Bootstrap Installer          " -ForegroundColor White
Write-Host "           (PowerShell 4.0+ Compatible Version)                 " -ForegroundColor White
Write-Host "                  Superior Networks LLC                          " -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion.Major
Write-Host "PowerShell Version: $psVersion.0" -ForegroundColor Gray
if ($psVersion -lt 4) {
    Write-Host ""
    Write-Host "ERROR: PowerShell 4.0 or higher is required." -ForegroundColor Red
    Write-Host "Current version: $psVersion.0" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please upgrade to PowerShell 4.0 or higher." -ForegroundColor Yellow
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}
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

# Function to extract ZIP using .NET (PowerShell 4.0 compatible)
function Extract-ZipFile {
    param(
        [string]$ZipPath,
        [string]$DestinationPath
    )
    
    try {
        # Load .NET ZIP assembly
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        
        # Extract
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $DestinationPath)
        return $true
    }
    catch {
        Write-Host "Error extracting ZIP: $_" -ForegroundColor Red
        return $false
    }
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
        
        # Extract using .NET (PowerShell 4.0 compatible)
        $extractPath = Join-Path $tempDir "extract"
        if (Test-Path $extractPath) {
            Remove-Item -Path $extractPath -Recurse -Force
        }
        Write-Host "Extracting files..." -ForegroundColor Yellow
        
        $extractSuccess = Extract-ZipFile -ZipPath $zipFile -DestinationPath $extractPath
        
        if (-not $extractSuccess) {
            Write-Host ""
            Write-Host "Installation failed. Please check your internet connection and try again." -ForegroundColor Red
            Write-Host ""
            Write-Host "Press any key to exit..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 1
        }
        
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
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -Path $_.FullName -Destination $installPath -Recurse -Force
        }
        
        # Cleanup
        Remove-Item -Path $zipFile -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        
        if ($isUpdate) {
            Write-Host "Update installed successfully!" -ForegroundColor Green
        }
        else {
            Write-Host "Toolkit installed successfully!" -ForegroundColor Green
        }
        
        return $true
    }
    catch {
        Write-Host ""
        Write-Host "Installation failed: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please check your internet connection and try again." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }
}

# Main logic
Write-Host "Checking installation..." -ForegroundColor Cyan

$installedVersion = Get-InstalledVersion

if ($null -eq $installedVersion) {
    # Not installed
    Write-Host "Toolkit not found. Installing..." -ForegroundColor Yellow
    Write-Host ""
    
    $success = Install-Toolkit -isUpdate $false
    
    if (-not $success) {
        exit 1
    }
}
else {
    # Already installed - check for updates
    Write-Host "Current version: $installedVersion" -ForegroundColor Green
    Write-Host ""
    Write-Host "Checking for updates..." -ForegroundColor Cyan
    
    $latestVersion = Get-LatestVersion
    
    if ($null -ne $latestVersion) {
        if ($latestVersion -gt $installedVersion) {
            Write-Host "New version available: $latestVersion" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Downloading update..." -ForegroundColor Yellow
            
            $success = Install-Toolkit -isUpdate $true
            
            if (-not $success) {
                Write-Host ""
                Write-Host "Update failed. Running current version..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
            else {
                # Show changelog
                Write-Host ""
                Write-Host "=================================================================" -ForegroundColor Cyan
                Write-Host "                        What's New                               " -ForegroundColor White
                Write-Host "=================================================================" -ForegroundColor Cyan
                Write-Host ""
                
                $readmePath = Join-Path $installPath "README.md"
                if (Test-Path $readmePath) {
                    $readmeContent = Get-Content $readmePath -Raw
                    
                    # Extract changelog for new version
                    $versionPattern = "### Version $latestVersion"
                    $nextVersionPattern = "### Version \d+\.\d+\.\d+"
                    
                    if ($readmeContent -match "(?s)$versionPattern(.*?)(?=$nextVersionPattern|$)") {
                        $changelog = $matches[1].Trim()
                        
                        # Display with color coding
                        $changelog -split "`n" | ForEach-Object {
                            if ($_ -match '^\s*-\s*\*\*') {
                                Write-Host $_ -ForegroundColor Green
                            }
                            else {
                                Write-Host $_ -ForegroundColor Gray
                            }
                        }
                    }
                }
                
                Write-Host ""
                Write-Host "=================================================================" -ForegroundColor Cyan
                Write-Host ""
                Start-Sleep -Seconds 3
            }
        }
        else {
            Write-Host "You have the latest version." -ForegroundColor Green
            Write-Host ""
        }
    }
}

# Launch toolkit
Write-Host "Launching toolkit..." -ForegroundColor Cyan
Write-Host ""
Start-Sleep -Seconds 1

if (Test-Path $launcherScript) {
    & $launcherScript
}
else {
    Write-Host "Error: Launcher not found at $launcherScript" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
