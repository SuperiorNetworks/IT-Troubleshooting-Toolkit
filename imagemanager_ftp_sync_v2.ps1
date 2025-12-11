<#
.SYNOPSIS
ImageManager FTP Sync Tool v2.0 - Current Files Only

.DESCRIPTION
Syncs current ImageManager replication queue files to FTP server
- Only processes ftp2Queue (current backups)
- Maps to correct server directories via TargetPaths
- Finds files on disk and uploads to matching FTP destinations
#>

param(
    [string]$FtpServer = "",
    [string]$FtpUsername = "",
    [string]$FtpPassword = ""
)

$imageManagerDbPath = "C:\Program Files (x86)\StorageCraft\ImageManager\ImageManager.mdb"
$imageManagerBasePath = "C:\Program Files (x86)\StorageCraft\ImageManager"
$winscpPath = "C:\ITTools\WinSCP\WinSCP.com"

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "     ImageManager FTP Sync Tool v2.0 - Current Files Only       " -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# Check if ImageManager database exists
if (-not (Test-Path $imageManagerDbPath)) {
    Write-Host "ERROR: ImageManager database not found at:" -ForegroundColor Red
    Write-Host "  $imageManagerDbPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Get FTP configuration if not provided
if ([string]::IsNullOrWhiteSpace($FtpServer)) {
    Write-Host "FTP Server Configuration" -ForegroundColor Yellow
    Write-Host ""
    $FtpServer = Read-Host "FTP Server (default: ftp.sndayton.com)"
    if ([string]::IsNullOrWhiteSpace($FtpServer)) {
        $FtpServer = "ftp.sndayton.com"
    }
}

if ([string]::IsNullOrWhiteSpace($FtpUsername)) {
    $FtpUsername = Read-Host "FTP Username"
}

if ([string]::IsNullOrWhiteSpace($FtpPassword)) {
    $FtpPassword = Read-Host "FTP Password" -AsSecureString
    $FtpPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($FtpPassword))
}

Write-Host ""
Write-Host "Connecting to ImageManager database..." -ForegroundColor Cyan

try {
    $conn = New-Object System.Data.OleDb.OleDbConnection
    $conn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source='$imageManagerDbPath'"
    $conn.Open()
    
    # Get TargetPaths mapping
    Write-Host "Reading server path mappings..." -ForegroundColor Cyan
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT Path, Index FROM TargetPaths WHERE Index = 2"
    $reader = $cmd.ExecuteReader()
    
    $targetPath = ""
    $serverName = ""
    
    if ($reader.Read()) {
        $targetPath = $reader.GetString(0)
        # Extract server name from path (e.g., "ftp.sndayton.com/vsn-dc-1216" -> "vsn-dc-1216")
        if ($targetPath -match '/([^/\s]+)(\s|$)') {
            $serverName = $matches[1]
        }
    }
    $reader.Close()
    
    if ([string]::IsNullOrWhiteSpace($serverName)) {
        Write-Host "ERROR: Could not determine server name from TargetPaths" -ForegroundColor Red
        $conn.Close()
        Write-Host ""
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
    
    Write-Host "  Server: " -NoNewline -ForegroundColor Gray
    Write-Host $serverName -ForegroundColor Yellow
    Write-Host "  FTP Path: " -NoNewline -ForegroundColor Gray
    Write-Host $targetPath -ForegroundColor Yellow
    Write-Host ""
    
    # Query ftp2Queue for current files
    Write-Host "Querying current replication queue (ftp2Queue)..." -ForegroundColor Cyan
    
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT Name, FileSize, CreateTime FROM [ftp2Queue]"
    $reader = $cmd.ExecuteReader()
    
    $queueFiles = @()
    
    while ($reader.Read()) {
        $fileName = $reader.GetString(0)
        $fileSize = $reader.GetDouble(1)
        $createTime = $reader.GetDateTime(2)
        
        if ($fileName -match '\.(spi|spf)$') {
            $queueFiles += [PSCustomObject]@{
                FileName = $fileName
                FileSize = $fileSize
                CreateTime = $createTime
            }
        }
    }
    
    $reader.Close()
    $conn.Close()
    
    $totalCount = $queueFiles.Count
    Write-Host "  Found " -NoNewline -ForegroundColor Green
    Write-Host $totalCount -NoNewline -ForegroundColor Green
    Write-Host " files in queue" -ForegroundColor Green
    Write-Host ""
    
    if ($queueFiles.Count -eq 0) {
        Write-Host "No files to upload." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
    
    # Find files on disk
    Write-Host "Locating files on disk..." -ForegroundColor Cyan
    $serverPath = Join-Path $imageManagerBasePath $serverName
    
    if (-not (Test-Path $serverPath)) {
        Write-Host "ERROR: Server directory not found:" -ForegroundColor Red
        Write-Host "  $serverPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
    
    $filesToUpload = @()
    $missingFiles = @()
    
    foreach ($file in $queueFiles) {
        # Search for file in server directory
        $fullPath = Get-ChildItem -Path $serverPath -Filter $file.FileName -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        
        if ($fullPath) {
            $filesToUpload += [PSCustomObject]@{
                LocalPath = $fullPath.FullName
                FileName = $file.FileName
                FileSize = $file.FileSize
                CreateTime = $file.CreateTime
            }
        } else {
            $missingFiles += $file.FileName
        }
    }
    
    $foundCount = $filesToUpload.Count
    Write-Host "  Found " -NoNewline -ForegroundColor Green
    Write-Host $foundCount -NoNewline -ForegroundColor Green
    Write-Host " files on disk" -ForegroundColor Green
    
    if ($missingFiles.Count -gt 0) {
        $missingCount = $missingFiles.Count
        Write-Host "  Missing " -NoNewline -ForegroundColor Yellow
        Write-Host $missingCount -NoNewline -ForegroundColor Yellow
        Write-Host " files (not found on disk)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    
    if ($filesToUpload.Count -eq 0) {
        Write-Host "No files found on disk to upload." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
    
    # Display files to upload
    Write-Host "Files ready for upload:" -ForegroundColor Cyan
    $filesToUpload | Select-Object -First 10 | ForEach-Object {
        $sizeMB = [Math]::Round($_.FileSize / 1MB, 2)
        Write-Host "  - " -NoNewline -ForegroundColor Gray
        Write-Host $_.FileName -NoNewline -ForegroundColor White
        Write-Host " (" -NoNewline -ForegroundColor Gray
        Write-Host $sizeMB -NoNewline -ForegroundColor Yellow
        Write-Host " MB)" -ForegroundColor Gray
    }
    
    if ($filesToUpload.Count -gt 10) {
        $remaining = $filesToUpload.Count - 10
        Write-Host "  ... and " -NoNewline -ForegroundColor Gray
        Write-Host $remaining -NoNewline -ForegroundColor Yellow
        Write-Host " more files" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "FTP Destination: " -NoNewline -ForegroundColor Gray
    Write-Host $FtpServer -NoNewline -ForegroundColor Yellow
    Write-Host "/" -NoNewline -ForegroundColor Gray
    Write-Host $serverName -ForegroundColor Yellow
    Write-Host ""
    
    # Confirm upload
    $confirm = Read-Host "Upload these files to FTP? (Y/N)"
    if ($confirm -ne 'Y' -and $confirm -ne 'y') {
        Write-Host "Upload cancelled." -ForegroundColor Yellow
        exit
    }
    
    Write-Host ""
    Write-Host "Uploading files via WinSCP..." -ForegroundColor Cyan
    Write-Host ""
    
    # Check WinSCP
    if (-not (Test-Path $winscpPath)) {
        Write-Host "ERROR: WinSCP not found at:" -ForegroundColor Red
        Write-Host "  $winscpPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Please install WinSCP first (option 9 in main menu)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
    
    # Create WinSCP script
    $scriptPath = Join-Path $env:TEMP "winscp_upload.txt"
    $logPath = Join-Path $env:TEMP "winscp_log.txt"
    
    $ftpUrl = "ftp://" + $FtpUsername + ":" + $FtpPassword + "@" + $FtpServer + "/" + $serverName + "/"
    
    "option batch abort" | Out-File $scriptPath -Encoding ASCII
    "option confirm off" | Out-File $scriptPath -Append -Encoding ASCII
    "open $ftpUrl" | Out-File $scriptPath -Append -Encoding ASCII
    
    foreach ($file in $filesToUpload) {
        $escapedPath = $file.LocalPath.Replace("'", "''")
        "put `"$escapedPath`"" | Out-File $scriptPath -Append -Encoding ASCII
    }
    
    "exit" | Out-File $scriptPath -Append -Encoding ASCII
    
    # Execute WinSCP
    $process = Start-Process -FilePath $winscpPath -ArgumentList "/script=`"$scriptPath`"","/log=`"$logPath`"" -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Host ""
        Write-Host "Upload completed successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Upload failed. Check log at:" -ForegroundColor Red
        Write-Host "  $logPath" -ForegroundColor Yellow
    }
    
    # Cleanup
    Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
