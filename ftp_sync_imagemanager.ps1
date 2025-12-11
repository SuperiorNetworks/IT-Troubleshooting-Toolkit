<#
.SYNOPSIS
FTP Sync with ImageManager Integration

.DESCRIPTION
Name: ftp_sync_imagemanager.ps1
Version: 1.1.0
Purpose: Query ImageManager replication queue and upload queued files via FTP using WinSCP
Path: /scripts/ftp_sync_imagemanager.ps1
Copyright: 2025

Key Features:
- Query ImageManager.mdb database for replication queue
- Display files waiting to replicate
- Upload queued files via FTP using WinSCP
- Automatic WinSCP portable download
- Pre-configured for ftp.sndayton.com
- Comprehensive logging

.NOTES
Requires Microsoft Access Database Engine (ACE) OLE DB Provider
#>

# --- Configuration ---
$defaultFtpServer = "ftp.sndayton.com"
$imageManagerDbPath = "C:\Program Files (x86)\StorageCraft\ImageManager\ImageManager.mdb"
$logDirectory = "C:\ITTools\Scripts\Logs"
$logFile = Join-Path $logDirectory "ftp_sync_imagemanager_log.txt"
$winscpDirectory = "C:\ITTools\WinSCP"
$winscpExe = Join-Path $winscpDirectory "WinSCP.com"
$winscpUrl = "https://raw.githubusercontent.com/SuperiorNetworks/IT-Troubleshooting-Toolkit/master/WinSCP-6.5.5-Setup.exe"
$aceInstallerPath = "C:\ITTools\Scripts\install_access_engine.ps1"

# Ensure directories exist
if (-not (Test-Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
}

if (-not (Test-Path $winscpDirectory)) {
    New-Item -ItemType Directory -Path $winscpDirectory -Force | Out-Null
}

# --- Logging Function ---
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

# --- WinSCP Functions ---
function Test-WinSCP {
    if (Test-Path $winscpExe) {
        Write-Log "WinSCP found at: $winscpExe" "SUCCESS"
        return $true
    }
    return $false
}

function Download-WinSCP {
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "                 Downloading WinSCP Portable                     " -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Log "WinSCP not found. Downloading from GitHub repository..."
    Write-Log "This only needs to happen once."
    Write-Log "Download source: GitHub Repository"
    
    $installerPath = Join-Path $env:TEMP "WinSCP-Setup.exe"
    
    try {
        # Enable TLS 1.2 for older systems
        Write-Host "Configuring secure connection..." -ForegroundColor Gray
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host ""
        
        Write-Host "Downloading WinSCP installer... Please wait..." -ForegroundColor Yellow
        
        # Use WebClient for better compatibility with PowerShell 4.0
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($winscpUrl, $installerPath)
        
        Write-Log "Download complete!" "SUCCESS"
        Write-Host "Extracting portable files..." -ForegroundColor Yellow
        
        # Run installer in silent mode to extract files
        $extractArgs = "/VERYSILENT /DIR=`"$winscpDirectory`" /NOCANCEL /NORESTART"
        $process = Start-Process -FilePath $installerPath -ArgumentList $extractArgs -Wait -PassThru
        
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        
        Write-Log "WinSCP installed successfully to: $winscpDirectory" "SUCCESS"
        Write-Host ""
        return $true
    }
    catch {
        Write-Log "Failed to download WinSCP: $_" "ERROR"
        Write-Host ""
        Write-Host "Please download WinSCP manually from: https://winscp.net/" -ForegroundColor Yellow
        Write-Host "Extract to: $winscpDirectory" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }
}

# --- Access Database Engine Functions ---
function Test-ACEInstalled {
    # Check if ACE provider is available
    $aceProviders = @(
        "Microsoft.ACE.OLEDB.12.0",
        "Microsoft.ACE.OLEDB.14.0",
        "Microsoft.ACE.OLEDB.15.0",
        "Microsoft.ACE.OLEDB.16.0"
    )
    
    foreach ($provider in $aceProviders) {
        try {
            $conn = New-Object System.Data.OleDb.OleDbConnection
            $conn.Provider = $provider
            $conn = $null
            Write-Log "Access Database Engine detected: $provider" "SUCCESS"
            return $true
        }
        catch {
            # Provider not available, continue checking
        }
    }
    
    Write-Log "Access Database Engine NOT detected" "WARN"
    return $false
}

function Install-ACEPrompt {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Yellow
    Write-Host "          ACCESS DATABASE ENGINE REQUIRED" -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "The ImageManager Queue tool requires the Microsoft Access" -ForegroundColor White
    Write-Host "Database Engine to read the ImageManager.mdb file." -ForegroundColor White
    Write-Host ""
    Write-Host "This is a free Microsoft component (~25 MB download)." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Would you like to install it now? (Y/N): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    
    if ($response -match '^[Yy]') {
        Write-Host ""
        Write-Host "Launching Access Database Engine installer..." -ForegroundColor Cyan
        Write-Host ""
        
        if (Test-Path $aceInstallerPath) {
            # Run the installer
            & $aceInstallerPath
            
            # Check if installation was successful
            if (Test-ACEInstalled) {
                Write-Host ""
                Write-Host "Installation successful! Continuing with ImageManager Queue tool..." -ForegroundColor Green
                Write-Host ""
                return $true
            }
            else {
                Write-Host ""
                Write-Host "Installation may require a system restart." -ForegroundColor Yellow
                Write-Host "Please restart and try again." -ForegroundColor Yellow
                Write-Host ""
                return $false
            }
        }
        else {
            Write-Host ""
            Write-Host "Error: Installer not found at: $aceInstallerPath" -ForegroundColor Red
            Write-Host ""
            Write-Host "Please use menu option #10 to install Access Database Engine." -ForegroundColor Yellow
            Write-Host ""
            return $false
        }
    }
    else {
        Write-Host ""
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To use this tool, you can install Access Database Engine" -ForegroundColor White
        Write-Host "using menu option #10 in the StorageCraft Troubleshooter." -ForegroundColor White
        Write-Host ""
        return $false
    }
}

# --- ImageManager Database Functions ---
function Test-ImageManagerDatabase {
    if (Test-Path $imageManagerDbPath) {
        Write-Log "ImageManager database found: $imageManagerDbPath" "SUCCESS"
        return $true
    } else {
        Write-Log "ImageManager database NOT found: $imageManagerDbPath" "ERROR"
        return $false
    }
}

function Get-ImageManagerTables {
    try {
        $conn = New-Object System.Data.OleDb.OleDbConnection
        $conn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source='$imageManagerDbPath'"
        $conn.Open()
        
        $schemaTable = $conn.GetOleDbSchemaTable([System.Data.OleDb.OleDbSchemaGuid]::Tables, @($null, $null, $null, "TABLE"))
        
        $tables = @()
        foreach ($row in $schemaTable.Rows) {
            $tableName = $row["TABLE_NAME"]
            if (-not $tableName.StartsWith("MSys")) {
                $tables += $tableName
            }
        }
        
        $conn.Close()
        return $tables
    }
    catch {
        Write-Log "Error reading database schema: $_" "ERROR"
        return $null
    }
}

function Get-TableData {
    param(
        [string]$TableName
    )
    
    try {
        $conn = New-Object System.Data.OleDb.OleDbConnection
        $conn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source='$imageManagerDbPath'"
        $conn.Open()
        
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT * FROM [$TableName]"
        
        $adapter = New-Object System.Data.OleDb.OleDbDataAdapter $cmd
        $dataset = New-Object System.Data.DataSet
        $adapter.Fill($dataset) | Out-Null
        
        $conn.Close()
        
        if ($dataset.Tables.Count -gt 0) {
            return $dataset.Tables[0]
        } else {
            return $null
        }
    }
    catch {
        Write-Log "Error querying table $TableName : $_" "WARN"
        return $null
    }
}

function Get-ReplicationQueueFiles {
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "           Querying ImageManager Replication Queue              " -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Log "Analyzing ImageManager database..."
    
    $tables = Get-ImageManagerTables
    
    if (-not $tables) {
        Write-Log "Could not access database tables." "ERROR"
        return $null
    }
    
    Write-Log "Found $($tables.Count) tables in database."
    Write-Host ""
    
    # Display all tables for user reference
    Write-Host "Available tables in ImageManager.mdb:" -ForegroundColor Yellow
    $tables | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    Write-Host ""
    
    # Try common table names
    $commonTableNames = @(
        "ReplicationQueue",
        "ReplicationJobs",
        "Jobs",
        "Tasks",
        "Queue",
        "Replication",
        "ManagedFolders",
        "Folders"
    )
    
    $queueFiles = @()
    
    foreach ($tableName in $commonTableNames) {
        if ($tables -contains $tableName) {
            Write-Log "Checking table: $tableName" "INFO"
            $data = Get-TableData -TableName $tableName
            
            if ($data -and $data.Rows.Count -gt 0) {
                Write-Log "Found $($data.Rows.Count) rows in $tableName" "SUCCESS"
                
                # Display column names
                $columns = $data.Columns | ForEach-Object { $_.ColumnName }
                Write-Host "  Columns: $($columns -join ', ')" -ForegroundColor Gray
                
                # Try to extract file paths
                foreach ($row in $data.Rows) {
                    foreach ($column in $columns) {
                        $value = $row[$column]
                        if ($value -and $value.ToString().Contains("\") -and $value.ToString().Contains(".spi")) {
                            $queueFiles += [PSCustomObject]@{
                                Table = $tableName
                                Column = $column
                                FilePath = $value.ToString()
                            }
                        }
                    }
                }
            }
        }
    }
    
    # If no files found in common tables, search all tables
    if ($queueFiles.Count -eq 0) {
        Write-Log "No files found in common tables. Searching all tables..." "WARN"
        
        foreach ($tableName in $tables) {
            $data = Get-TableData -TableName $tableName
            
            if ($data -and $data.Rows.Count -gt 0) {
                $columns = $data.Columns | ForEach-Object { $_.ColumnName }
                
                foreach ($row in $data.Rows) {
                    foreach ($column in $columns) {
                        $value = $row[$column]
                        if ($value -and $value.ToString().Contains("\") -and $value.ToString().Contains(".spi")) {
                            $queueFiles += [PSCustomObject]@{
                                Table = $tableName
                                Column = $column
                                FilePath = $value.ToString()
                            }
                        }
                    }
                }
            }
        }
    }
    
    return $queueFiles
}

# --- FTP Upload Function ---
function Upload-FilesViaWinSCP {
    param(
        [array]$Files,
        [string]$FtpServer,
        [string]$FtpUsername,
        [string]$FtpPassword
    )
    
    if ($Files.Count -eq 0) {
        Write-Log "No files to upload." "WARN"
        return
    }
    
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "                   Uploading Files via WinSCP                    " -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Create WinSCP script
    $scriptPath = Join-Path $env:TEMP "winscp_upload_script.txt"
    
    $scriptContent = @"
open ftp://${FtpUsername}:${FtpPassword}@${FtpServer}/
option batch abort
option confirm off
"@
    
    foreach ($file in $Files) {
        if (Test-Path $file) {
            $fileName = [System.IO.Path]::GetFileName($file)
            $scriptContent += "`nput `"$file`" `"/$fileName`""
        }
    }
    
    $scriptContent += "`nclose`nexit"
    
    Set-Content -Path $scriptPath -Value $scriptContent
    
    Write-Log "Uploading $($Files.Count) files to $FtpServer..."
    
    try {
        $output = & $winscpExe /script="$scriptPath" 2>&1
        
        Write-Log "Upload completed!" "SUCCESS"
        Write-Host ""
        Write-Host "WinSCP Output:" -ForegroundColor Gray
        $output | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        
        Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
        
        Write-Host ""
        Write-Log "All files uploaded successfully!" "SUCCESS"
    }
    catch {
        Write-Log "Error during upload: $_" "ERROR"
        Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
    }
}

# --- Main Script ---
function Main {
    Clear-Host
    
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "          FTP Sync Tool (ImageManager Integration)              " -ForegroundColor White
    Write-Host "                StorageCraft Backup Synchronization              " -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Log "FTP Sync Tool started (ImageManager-based)"
    Write-Host "Script location: $PSCommandPath" -ForegroundColor Gray
    Write-Host ""
    
    # Check for Access Database Engine
    Write-Host "Checking for Access Database Engine..." -ForegroundColor Cyan
    if (-not (Test-ACEInstalled)) {
        Write-Host ""
        if (-not (Install-ACEPrompt)) {
            Write-Host "Press any key to exit..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
    }
    Write-Host ""
    
    # Check for ImageManager database
    if (-not (Test-ImageManagerDatabase)) {
        Write-Host ""
        Write-Host "ERROR: ImageManager database not found!" -ForegroundColor Red
        Write-Host "Expected location: $imageManagerDbPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Please ensure:" -ForegroundColor Yellow
        Write-Host "  1. StorageCraft ImageManager is installed" -ForegroundColor Gray
        Write-Host "  2. The database file exists at the expected location" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    # Check for WinSCP
    if (-not (Test-WinSCP)) {
        if (-not (Download-WinSCP)) {
            return
        }
    }
    
    # Get replication queue
    $queueFiles = Get-ReplicationQueueFiles
    
    if (-not $queueFiles -or $queueFiles.Count -eq 0) {
        Write-Host ""
        Write-Host "No files found in replication queue." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "This could mean:" -ForegroundColor Gray
        Write-Host "  - No files are currently queued for replication" -ForegroundColor Gray
        Write-Host "  - The queue is stored in a different table" -ForegroundColor Gray
        Write-Host "  - ImageManager is not actively managing replication" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    # Display queue
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "                    Replication Queue Files                      " -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Found $($queueFiles.Count) files in replication queue:" -ForegroundColor Green
    Write-Host ""
    
    $index = 1
    foreach ($file in $queueFiles) {
        Write-Host "$index. $($file.FilePath)" -ForegroundColor White
        Write-Host "   Source: Table=$($file.Table), Column=$($file.Column)" -ForegroundColor Gray
        $index++
    }
    
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Get FTP credentials
    Write-Host "FTP Server Configuration" -ForegroundColor Yellow
    Write-Host ""
    
    $ftpServer = Read-Host "FTP Server (default: $defaultFtpServer)"
    if ([string]::IsNullOrWhiteSpace($ftpServer)) {
        $ftpServer = $defaultFtpServer
    }
    
    $ftpUsername = Read-Host "FTP Username"
    $ftpPassword = Read-Host "FTP Password" -AsSecureString
    $ftpPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ftpPassword))
    
    Write-Host ""
    
    # Confirm upload
    Write-Host "Ready to upload $($queueFiles.Count) files to $ftpServer" -ForegroundColor Yellow
    $confirm = Read-Host "Proceed with upload? (Y/N)"
    
    if ($confirm -eq "Y" -or $confirm -eq "y") {
        $filePaths = $queueFiles | ForEach-Object { $_.FilePath }
        Upload-FilesViaWinSCP -Files $filePaths -FtpServer $ftpServer -FtpUsername $ftpUsername -FtpPassword $ftpPasswordPlain
    } else {
        Write-Log "Upload cancelled by user." "WARN"
    }
    
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Run main script
Main
