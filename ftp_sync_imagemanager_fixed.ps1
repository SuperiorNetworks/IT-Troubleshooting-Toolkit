# Quick fix script to test ImageManager database query
# This will be integrated into the main script after testing

$imageManagerDbPath = "C:\Program Files (x86)\StorageCraft\ImageManager\ImageManager.mdb"

Write-Host ""
Write-Host "Testing ImageManager Database Query" -ForegroundColor Cyan
Write-Host ""

try {
    $conn = New-Object System.Data.OleDb.OleDbConnection
    $conn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source='$imageManagerDbPath'"
    $conn.Open()
    
    # Get FTP queue tables
    $schema = $conn.GetOleDbSchemaTable([System.Data.OleDb.OleDbSchemaGuid]::Tables, @($null, $null, $null, "TABLE"))
    $tables = @()
    foreach ($row in $schema.Rows) {
        $tableName = $row["TABLE_NAME"]
        if ($tableName -match '^ftp\d+Queue$') {
            $tables += $tableName
        }
    }
    
    $tableList = $tables -join ', '
    Write-Host "Found FTP Queue tables: $tableList" -ForegroundColor Green
    Write-Host ""
    
    $allFiles = @()
    
    foreach ($table in $tables) {
        Write-Host "Querying " -NoNewline -ForegroundColor Yellow
        Write-Host "$table" -NoNewline -ForegroundColor Yellow
        Write-Host "..." -ForegroundColor Yellow
        
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT Name, FileSize, CreateTime FROM [$table]"
        
        $reader = $cmd.ExecuteReader()
        $count = 0
        
        while ($reader.Read()) {
            $fileName = $reader.GetString(0)
            $fileSize = $reader.GetDouble(1)
            $createTime = $reader.GetDateTime(2)
            
            if ($fileName -match '\.(spi|spf)$') {
                $count++
                $allFiles += [PSCustomObject]@{
                    Table = $table
                    FileName = $fileName
                    FileSize = [Math]::Round($fileSize / 1MB, 2)
                    CreateTime = $createTime
                }
            }
        }
        
        $reader.Close()
        Write-Host "  Found " -NoNewline -ForegroundColor Gray
        Write-Host "$count" -NoNewline -ForegroundColor Gray
        Write-Host " files" -ForegroundColor Gray
    }
    
    $conn.Close()
    
    Write-Host ""
    $totalCount = $allFiles.Count
    Write-Host "Total files in queue: $totalCount" -ForegroundColor Green
    Write-Host ""
    
    if ($allFiles.Count -gt 0) {
        Write-Host "Files waiting for replication:" -ForegroundColor Cyan
        $allFiles | Format-Table -AutoSize Table, FileName, @{Label="Size (MB)";Expression={$_.FileSize}}, CreateTime
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
