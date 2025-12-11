<#
.SYNOPSIS
    Installs Microsoft Access Database Engine for ImageManager database access
.DESCRIPTION
    Downloads and installs the Microsoft Access Database Engine (ACE) OLE DB provider
    required for reading ImageManager.mdb files. Includes verbose troubleshooting,
    comprehensive logging, and support for all Windows versions.
.NOTES
    Version: 1.0.0
    Author: Superior Networks LLC
    Requires: PowerShell 4.0+, Administrator privileges
#>

# Requires -RunAsAdministrator

param(
    [switch]$Silent = $false
)

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Script version
$ScriptVersion = "1.0.0"

# Paths
$LogDir = "C:\ITTools\Scripts\Logs"
$LogFile = Join-Path $LogDir "access_engine_install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$TempDir = Join-Path $env:TEMP "ACE_Install"

# Download URLs (Microsoft official)
$ACE_x64_URL = "https://download.microsoft.com/download/3/5/C/35C84C36-661A-44E6-9324-8786B8DBE231/AccessDatabaseEngine_X64.exe"
$ACE_x86_URL = "https://download.microsoft.com/download/3/5/C/35C84C36-661A-44E6-9324-8786B8DBE231/AccessDatabaseEngine.exe"

# Registry paths for ACE detection
$ACE_Registry_Paths = @(
    "HKLM:\SOFTWARE\Microsoft\Office\14.0\Common\FilesPaths",
    "HKLM:\SOFTWARE\Microsoft\Office\15.0\Common\FilesPaths",
    "HKLM:\SOFTWARE\Microsoft\Office\16.0\Common\FilesPaths",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\14.0\Common\FilesPaths",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\15.0\Common\FilesPaths",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\16.0\Common\FilesPaths"
)

# Provider names to check
$ACE_Providers = @(
    "Microsoft.ACE.OLEDB.12.0",
    "Microsoft.ACE.OLEDB.14.0",
    "Microsoft.ACE.OLEDB.15.0",
    "Microsoft.ACE.OLEDB.16.0"
)

#region Logging Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'VERBOSE')]
        [string]$Level = 'INFO'
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    # Ensure log directory exists
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    
    # Write to log file
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
    
    # Write to console with colors
    switch ($Level) {
        'SUCCESS' { Write-Host $Message -ForegroundColor Green }
        'WARNING' { Write-Host $Message -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Message -ForegroundColor Red }
        'VERBOSE' { Write-Host $Message -ForegroundColor Gray }
        default   { Write-Host $Message -ForegroundColor Cyan }
    }
}

function Write-VerboseLog {
    param([string]$Message)
    Write-Log -Message $Message -Level 'VERBOSE'
}

#endregion

#region Detection Functions

function Test-ACEInstalled {
    Write-VerboseLog "Checking for existing Access Database Engine installation..."
    
    # Method 1: Check registry paths
    Write-VerboseLog "Method 1: Checking registry paths..."
    foreach ($RegPath in $ACE_Registry_Paths) {
        if (Test-Path $RegPath) {
            Write-VerboseLog "  Found registry path: $RegPath"
            Write-Log "Access Database Engine detected via registry: $RegPath" -Level 'SUCCESS'
            return $true
        }
    }
    Write-VerboseLog "  No ACE registry paths found"
    
    # Method 2: Try to create OLE DB connection
    Write-VerboseLog "Method 2: Testing OLE DB providers..."
    foreach ($Provider in $ACE_Providers) {
        try {
            Write-VerboseLog "  Testing provider: $Provider"
            $null = New-Object -ComObject ADODB.Connection
            $conn = New-Object -ComObject ADODB.Connection
            $conn.Provider = $Provider
            $conn = $null
            Write-Log "Access Database Engine detected via provider: $Provider" -Level 'SUCCESS'
            return $true
        }
        catch {
            Write-VerboseLog "  Provider $Provider not available: $($_.Exception.Message)"
        }
    }
    
    # Method 3: Check for ACE DLL files
    Write-VerboseLog "Method 3: Checking for ACE DLL files..."
    $CommonFilesPaths = @(
        "${env:ProgramFiles}\Common Files\Microsoft Shared\OFFICE14",
        "${env:ProgramFiles}\Common Files\Microsoft Shared\OFFICE15",
        "${env:ProgramFiles}\Common Files\Microsoft Shared\OFFICE16",
        "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\OFFICE14",
        "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\OFFICE15",
        "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\OFFICE16"
    )
    
    foreach ($Path in $CommonFilesPaths) {
        $AceDll = Join-Path $Path "ACEOLEDB.DLL"
        if (Test-Path $AceDll) {
            Write-VerboseLog "  Found ACE DLL: $AceDll"
            Write-Log "Access Database Engine detected via DLL: $AceDll" -Level 'SUCCESS'
            return $true
        }
    }
    Write-VerboseLog "  No ACE DLL files found"
    
    Write-Log "Access Database Engine is NOT installed" -Level 'WARNING'
    return $false
}

function Get-SystemArchitecture {
    Write-VerboseLog "Detecting system architecture..."
    
    if ([Environment]::Is64BitOperatingSystem) {
        Write-VerboseLog "  System is 64-bit"
        Write-Log "Detected 64-bit operating system" -Level 'INFO'
        return "x64"
    }
    else {
        Write-VerboseLog "  System is 32-bit"
        Write-Log "Detected 32-bit operating system" -Level 'INFO'
        return "x86"
    }
}

function Get-WindowsVersion {
    Write-VerboseLog "Detecting Windows version..."
    
    $OS = Get-WmiObject -Class Win32_OperatingSystem
    $Version = $OS.Version
    $Caption = $OS.Caption
    
    Write-VerboseLog "  OS: $Caption"
    Write-VerboseLog "  Version: $Version"
    Write-Log "Windows Version: $Caption ($Version)" -Level 'INFO'
    
    return @{
        Caption = $Caption
        Version = $Version
        VersionNumber = [version]$Version
    }
}

function Test-DiskSpace {
    param([int]$RequiredMB = 200)
    
    Write-VerboseLog "Checking available disk space..."
    
    $SystemDrive = $env:SystemDrive
    $Drive = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$SystemDrive'"
    $FreeSpaceMB = [math]::Round($Drive.FreeSpace / 1MB, 2)
    
    Write-VerboseLog "  Drive: $SystemDrive"
    Write-VerboseLog "  Free space: $FreeSpaceMB MB"
    Write-VerboseLog "  Required: $RequiredMB MB"
    
    if ($FreeSpaceMB -lt $RequiredMB) {
        Write-Log "Insufficient disk space: $FreeSpaceMB MB available, $RequiredMB MB required" -Level 'ERROR'
        return $false
    }
    
    Write-Log "Sufficient disk space available: $FreeSpaceMB MB" -Level 'SUCCESS'
    return $true
}

#endregion

#region Installation Functions

function Install-ACE {
    param(
        [string]$Architecture
    )
    
    Write-Log "Starting Access Database Engine installation..." -Level 'INFO'
    
    # Determine download URL
    if ($Architecture -eq "x64") {
        $DownloadURL = $ACE_x64_URL
        $InstallerName = "AccessDatabaseEngine_X64.exe"
        Write-Log "Using 64-bit installer" -Level 'INFO'
    }
    else {
        $DownloadURL = $ACE_x86_URL
        $InstallerName = "AccessDatabaseEngine.exe"
        Write-Log "Using 32-bit installer" -Level 'INFO'
    }
    
    # Create temp directory
    Write-VerboseLog "Creating temporary directory: $TempDir"
    if (-not (Test-Path $TempDir)) {
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    }
    
    $InstallerPath = Join-Path $TempDir $InstallerName
    
    try {
        # Download installer
        Write-Log "Downloading Access Database Engine installer..." -Level 'INFO'
        Write-VerboseLog "  URL: $DownloadURL"
        Write-VerboseLog "  Destination: $InstallerPath"
        
        # Enable TLS 1.2 for older systems
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($DownloadURL, $InstallerPath)
        
        if (Test-Path $InstallerPath) {
            $FileSize = (Get-Item $InstallerPath).Length / 1MB
            Write-Log "Download complete: $([math]::Round($FileSize, 2)) MB" -Level 'SUCCESS'
        }
        else {
            throw "Download failed: File not found at $InstallerPath"
        }
        
        # Run installer
        Write-Log "Running installer (silent mode)..." -Level 'INFO'
        Write-VerboseLog "  Command: $InstallerPath /quiet /passive /norestart"
        
        $Process = Start-Process -FilePath $InstallerPath -ArgumentList "/quiet", "/passive", "/norestart" -Wait -PassThru
        
        Write-VerboseLog "  Installer exit code: $($Process.ExitCode)"
        
        # Check exit code
        switch ($Process.ExitCode) {
            0 {
                Write-Log "Installation completed successfully!" -Level 'SUCCESS'
                return $true
            }
            3010 {
                Write-Log "Installation completed successfully (restart required)" -Level 'SUCCESS'
                Write-Log "Note: A system restart may be required for full functionality" -Level 'WARNING'
                return $true
            }
            1603 {
                Write-Log "Installation failed: Fatal error during installation" -Level 'ERROR'
                Write-VerboseLog "  This may occur if a conflicting version is already installed"
                return $false
            }
            1638 {
                Write-Log "Installation skipped: Another version is already installed" -Level 'WARNING'
                return $true
            }
            default {
                Write-Log "Installation completed with exit code: $($Process.ExitCode)" -Level 'WARNING'
                return $false
            }
        }
    }
    catch {
        Write-Log "Installation error: $($_.Exception.Message)" -Level 'ERROR'
        Write-VerboseLog "  Exception type: $($_.Exception.GetType().FullName)"
        Write-VerboseLog "  Stack trace: $($_.Exception.StackTrace)"
        return $false
    }
    finally {
        # Cleanup
        Write-VerboseLog "Cleaning up temporary files..."
        if (Test-Path $TempDir) {
            try {
                Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-VerboseLog "  Temporary directory removed"
            }
            catch {
                Write-VerboseLog "  Could not remove temporary directory: $($_.Exception.Message)"
            }
        }
    }
}

function Show-ManualInstructions {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              MANUAL INSTALLATION INSTRUCTIONS" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "If automatic installation failed, you can install manually:" -ForegroundColor Yellow
    Write-Host ""
    
    $Arch = Get-SystemArchitecture
    if ($Arch -eq "x64") {
        Write-Host "1. Download the 64-bit installer from:" -ForegroundColor White
        Write-Host "   $ACE_x64_URL" -ForegroundColor Gray
    }
    else {
        Write-Host "1. Download the 32-bit installer from:" -ForegroundColor White
        Write-Host "   $ACE_x86_URL" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "2. Run the installer with these options:" -ForegroundColor White
    Write-Host "   - Accept the license agreement" -ForegroundColor Gray
    Write-Host "   - Use default installation location" -ForegroundColor Gray
    Write-Host "   - Complete the installation" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. After installation, run this tool again to verify" -ForegroundColor White
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

#endregion

#region Main Script

function Main {
    # Header
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "                  SUPERIOR NETWORKS LLC" -ForegroundColor Cyan
    Write-Host "       Access Database Engine Installer - v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Log "Access Database Engine Installer v$ScriptVersion started" -Level 'INFO'
    Write-Log "Log file: $LogFile" -Level 'INFO'
    
    # Check if running as administrator
    Write-VerboseLog "Checking administrator privileges..."
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $IsAdmin) {
        Write-Log "This script must be run as Administrator!" -Level 'ERROR'
        Write-Host ""
        Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
        Write-Host ""
        return $false
    }
    Write-VerboseLog "  Running with administrator privileges"
    
    # Get system information
    $WinVersion = Get-WindowsVersion
    $Architecture = Get-SystemArchitecture
    
    # Check disk space
    if (-not (Test-DiskSpace -RequiredMB 200)) {
        Write-Host ""
        Write-Host "Insufficient disk space. Please free up space and try again." -ForegroundColor Red
        Write-Host ""
        return $false
    }
    
    # Check if already installed
    Write-Host "Checking for existing installation..." -ForegroundColor Cyan
    Write-Host ""
    
    if (Test-ACEInstalled) {
        Write-Host ""
        Write-Host "Access Database Engine is already installed!" -ForegroundColor Green
        Write-Host ""
        Write-Host "The ImageManager Queue tool should work without issues." -ForegroundColor White
        Write-Host ""
        
        if (-not $Silent) {
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        
        return $true
    }
    
    # Not installed - offer to install
    Write-Host ""
    Write-Host "Access Database Engine is NOT currently installed." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This component is required for the ImageManager Queue tool" -ForegroundColor White
    Write-Host "to read the ImageManager.mdb database file." -ForegroundColor White
    Write-Host ""
    Write-Host "What will be installed:" -ForegroundColor Cyan
    Write-Host "  - Microsoft Access Database Engine (ACE) OLE DB Provider" -ForegroundColor Gray
    Write-Host "  - Size: ~25 MB download, ~50 MB installed" -ForegroundColor Gray
    Write-Host "  - Architecture: $Architecture" -ForegroundColor Gray
    Write-Host "  - Installation: Silent (no user interaction required)" -ForegroundColor Gray
    Write-Host ""
    
    # Ask for confirmation
    if (-not $Silent) {
        Write-Host "Would you like to install it now? (Y/N): " -ForegroundColor Yellow -NoNewline
        $Response = Read-Host
        
        if ($Response -notmatch '^[Yy]') {
            Write-Log "Installation cancelled by user" -Level 'WARNING'
            Write-Host ""
            Write-Host "Installation cancelled." -ForegroundColor Yellow
            Write-Host ""
            Show-ManualInstructions
            return $false
        }
    }
    
    Write-Host ""
    Write-Host "Starting installation..." -ForegroundColor Cyan
    Write-Host ""
    
    # Install
    $Success = Install-ACE -Architecture $Architecture
    
    if ($Success) {
        Write-Host ""
        Write-Host "Verifying installation..." -ForegroundColor Cyan
        Write-Host ""
        
        # Verify installation
        if (Test-ACEInstalled) {
            Write-Host ""
            Write-Host "================================================================" -ForegroundColor Green
            Write-Host "          INSTALLATION COMPLETED SUCCESSFULLY!" -ForegroundColor Green
            Write-Host "================================================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "The Access Database Engine is now installed and ready to use." -ForegroundColor White
            Write-Host ""
            Write-Host "You can now use the 'Upload ImageManager Queue' tool." -ForegroundColor White
            Write-Host ""
            
            Write-Log "Installation verified successfully" -Level 'SUCCESS'
            
            if (-not $Silent) {
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            
            return $true
        }
        else {
            Write-Host ""
            Write-Host "Installation completed, but verification failed." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "The installer reported success, but the provider could not be detected." -ForegroundColor Yellow
            Write-Host "This may require a system restart." -ForegroundColor Yellow
            Write-Host ""
            
            Write-Log "Installation completed but verification failed" -Level 'WARNING'
            
            Write-Host "Would you like to see manual installation instructions? (Y/N): " -ForegroundColor Yellow -NoNewline
            $Response = Read-Host
            
            if ($Response -match '^[Yy]') {
                Show-ManualInstructions
            }
            
            return $false
        }
    }
    else {
        Write-Host ""
        Write-Host "================================================================" -ForegroundColor Red
        Write-Host "                 INSTALLATION FAILED" -ForegroundColor Red
        Write-Host "================================================================" -ForegroundColor Red
        Write-Host ""
        
        Write-Log "Installation failed" -Level 'ERROR'
        
        Write-Host "Would you like to:" -ForegroundColor Yellow
        Write-Host "  1. Retry installation" -ForegroundColor White
        Write-Host "  2. View manual installation instructions" -ForegroundColor White
        Write-Host "  3. Exit" -ForegroundColor White
        Write-Host ""
        Write-Host "Enter choice (1-3): " -ForegroundColor Yellow -NoNewline
        $Choice = Read-Host
        
        switch ($Choice) {
            "1" {
                Write-Host ""
                Write-Host "Retrying installation..." -ForegroundColor Cyan
                Write-Host ""
                Write-Log "Retrying installation per user request" -Level 'INFO'
                return Main
            }
            "2" {
                Show-ManualInstructions
                return $false
            }
            default {
                Write-Host ""
                Write-Host "Installation cancelled." -ForegroundColor Yellow
                Write-Host ""
                return $false
            }
        }
    }
}

# Run main function
$Result = Main

Write-Log "Script completed with result: $Result" -Level 'INFO'
Write-Host ""

# Return result for scripting
return $Result

#endregion
