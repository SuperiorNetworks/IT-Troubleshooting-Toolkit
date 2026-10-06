<#
.SYNOPSIS
IT Troubleshooting Toolkit - Bootstrap Installer

.DESCRIPTION
Smart launcher that automatically installs or updates the toolkit and runs it.
Can be run from anywhere - handles everything automatically.

.USAGE
PowerShell.exe -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/bootstrap.ps1 | iex"

Or save this file and run:
PowerShell.exe -ExecutionPolicy Bypass -File bootstrap.ps1

.COPYRIGHT
Name: bootstrap.ps1
Version: 3.18.0
Purpose: Installs or updates the IT Troubleshooting Toolkit from GitHub and launches it.
         PowerShell 5.0+ (Windows 10/11, Server 2016+); uses Expand-Archive.
Author: Dwain Henderson Jr. | Superior Networks LLC
Contact: (937) 985-2480 | dhenderson@superiornetworks.biz
Copyright: 2026, Superior Networks LLC
Path: C:\ITTools\Scripts\bootstrap.ps1

What This Script Does:
  - Downloads the toolkit ZIP from GitHub (master branch by default)
  - Installs it to C:\ITTools\Scripts, or updates it when GitHub has a higher version
  - Verifies the required toolkit files were installed
  - Launches launch_menu.ps1

Input:
  - SUPERIOR_NETWORKS_BRANCH environment variable (optional). Installs that branch instead of
    master and always reinstalls. For test boxes only, e.g.:
    $env:SUPERIOR_NETWORKS_BRANCH='dev'
  - GitHub: SuperiorNetworks/IT-Troubleshooting-Toolkit

Output:
  - Toolkit files in C:\ITTools\Scripts (temporary files in C:\ITTools\Scripts\Temp)

Dependencies:
  - Windows PowerShell 5.0 or higher (Expand-Archive)
  - Internet access to github.com and raw.githubusercontent.com (TLS 1.2)

Change Log:
2026-10-06 v3.17.1 - Added SUPERIOR_NETWORKS_BRANCH override for testing branches; source
                     folder is now found in the ZIP instead of hardcoded; standard header (Dwain Henderson Jr)
2026-10-06 v3.17.2 - Enable TLS 1.2 before downloading; install command in .USAGE sets TLS 1.2 first (Dwain Henderson Jr)
2026-10-06 v3.18.0 - Require project_planner.ps1; skip the repo tests folder when installing (Dwain Henderson Jr)
#>

# Enable TLS 1.2 for GitHub downloads (older .NET defaults to TLS 1.0, which GitHub refuses)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Configuration
$installPath = "C:\ITTools\Scripts"
$launcherScript = Join-Path $installPath "launch_menu.ps1"
# Branch to install. Defaults to master (production). Set $env:SUPERIOR_NETWORKS_BRANCH on a
# test box to install another branch, e.g. dev.
$branch = $env:SUPERIOR_NETWORKS_BRANCH
if ([string]::IsNullOrWhiteSpace($branch)) {
    $branch = "master"
}
$branch = $branch.Trim()
$isTestBranch = ($branch -ne "master")
$githubZipUrl = "https://github.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/archive/refs/heads/$branch.zip"
$tempDir = Join-Path $installPath "Temp"
$requiredToolkitFiles = @(
    "launch_menu.ps1",
    "storagecraft_troubleshooter.ps1",
    "storagecraft_log_viewer.ps1",
    "project_planner.ps1",
    "hp_m404dn_troubleshooter.ps1",
    "hp_m404dn_connectivity_test.ps1",
    "hp_m404dn_spooler_repair.ps1",
    "hp_m404dn_driver_reinstall.ps1"
)

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "      IT Troubleshooting Toolkit - Bootstrap Installer          " -ForegroundColor White
Write-Host "                  Superior Networks LLC                          " -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""
if ($isTestBranch) {
    Write-Host "TEST BRANCH: $branch - not for production machines" -ForegroundColor Yellow
    Write-Host ""
}

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
        $rawUrl = "https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/$branch/launch_menu.ps1"
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
        
        # Find source folder (GitHub names it IT-Troubleshooting-Toolkit-<branch>, with / changed to -)
        $sourceDir = Get-ChildItem -Path $extractPath | Where-Object { $_.PSIsContainer } | Select-Object -First 1
        if ($null -eq $sourceDir) {
            throw "Downloaded ZIP did not contain the toolkit folder."
        }
        $sourceFolder = $sourceDir.FullName
        
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
        
        # Verify required toolkit files, including the HP M404dn Printer Troubleshooter module
        foreach ($requiredToolkitFile in $requiredToolkitFiles) {
            $installedFile = Join-Path $installPath $requiredToolkitFile
            if (-not (Test-Path $installedFile)) {
                throw "Required toolkit file was not installed: $requiredToolkitFile"
            }
        }

        # Copy directories (repo tests are not installed on client machines)
        Get-ChildItem -Path $sourceFolder | Where-Object { $_.PSIsContainer -and $_.Name -ne "tests" } | ForEach-Object {
            $destDir = Join-Path $installPath $_.Name
            if (Test-Path $destDir) {
                Remove-Item -Path $destDir -Recurse -Force
            }
            Copy-Item -Path $_.FullName -Destination $installPath -Recurse -Force
        }
        
        # Cleanup
        Remove-Item -Path $zipFile -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-Host "[OK] Installation complete!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[FAIL] Installation failed: $_" -ForegroundColor Red
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
        Write-Host "[OK] Installed IT Troubleshooting Toolkit v$installedVersion" -ForegroundColor Green
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
    Write-Host "[OK] Toolkit found: v$installedVersion" -ForegroundColor Green
    Write-Host "  Location: $installPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Checking for updates..." -ForegroundColor Cyan
    
    $latestVersion = Get-LatestVersion
    
    if ($isTestBranch) {
        Write-Host "Test branch '$branch': reinstalling from GitHub" -ForegroundColor Yellow
        Write-Host ""

        if (Install-Toolkit -isUpdate $true) {
            $installedVersion = Get-InstalledVersion
            Write-Host ""
            Write-Host "[OK] Installed branch '$branch' v$installedVersion" -ForegroundColor Green
        }
    }
    elseif ($null -ne $latestVersion -and $latestVersion -gt $installedVersion) {
        Write-Host "Update available: v$installedVersion -> v$latestVersion" -ForegroundColor Yellow
        Write-Host ""
        
        if (Install-Toolkit -isUpdate $true) {
            $installedVersion = Get-InstalledVersion
            Write-Host ""
            Write-Host "[OK] Updated to v$installedVersion" -ForegroundColor Green
        }
    }
    else {
        Write-Host "[OK] Already up-to-date" -ForegroundColor Green
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
