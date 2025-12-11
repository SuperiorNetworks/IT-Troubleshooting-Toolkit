<#
.SYNOPSIS
ImageManager Database Diagnostic Tool v2

.DESCRIPTION
Improved version with better column name and value reading
#>

# Configuration
$imageManagerDbPath = "C:\Program Files (x86)\StorageCraft\ImageManager\ImageManager.mdb"
$outputFile = "C:\ITTools\Scripts\Logs\imagemanager_diagnostic_v2.txt"
$logDirectory = "C:\ITTools\Scripts\Logs"

# Ensure log directory exists
if (-not (Test-Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "      ImageManager Database Diagnostic Tool v2                  " -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# Check if database exists
if (-not (Test-Path $imageManagerDbPath)) {
    Write-Host "ERROR: ImageManager database not found" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Write-Host "Database found: $imageManagerDbPath" -ForegroundColor Green
Write-Host ""

# Initialize output
"ImageManager Database Diagnostic Report v2" | Out-File $outputFile
"Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $outputFile -Append
"=" * 80 | Out-File $outputFile -Append
"" | Out-File $outputFile -Append

# Function to export table using DataReader (better for problematic databases)
function Export-TableWithDataReader {
    param(
        [string]$TableName,
        [int]$MaxRows = 5
    )
    
    Write-Host "Analyzing: $TableName" -ForegroundColor Cyan
    
    "" | Out-File $outputFile -Append
    "=" * 80 | Out-File $outputFile -Append
    "TABLE: $TableName" | Out-File $outputFile -Append
    "=" * 80 | Out-File $outputFile -Append
    "" | Out-File $outputFile -Append
    
    try {
        $conn = New-Object System.Data.OleDb.OleDbConnection
        $conn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source='$imageManagerDbPath'"
        $conn.Open()
        
        # Get column schema first
        $schemaCmd = $conn.CreateCommand()
        $schemaCmd.CommandText = "SELECT TOP 1 * FROM [$TableName]"
        $reader = $schemaCmd.ExecuteReader()
        
        $columnCount = $reader.FieldCount
        $columnNames = @()
        $columnTypes = @()
        
        for ($i = 0; $i -lt $columnCount; $i++) {
            $colName = $reader.GetName($i)
            $colType = $reader.GetFieldType($i).Name
            $columnNames += $colName
            $columnTypes += $colType
        }
        
        $reader.Close()
        
        "Column Count: $columnCount" | Out-File $outputFile -Append
        "" | Out-File $outputFile -Append
        
        "Column Names and Types:" | Out-File $outputFile -Append
        for ($i = 0; $i -lt $columnCount; $i++) {
            "  [$i] $($columnNames[$i]) ($($columnTypes[$i]))" | Out-File $outputFile -Append
        }
        "" | Out-File $outputFile -Append
        
        Write-Host "  Columns: $($columnNames -join ', ')" -ForegroundColor Gray
        
        # Now get actual data
        $dataCmd = $conn.CreateCommand()
        $dataCmd.CommandText = "SELECT TOP $MaxRows * FROM [$TableName]"
        $dataReader = $dataCmd.ExecuteReader()
        
        $rowNum = 0
        while ($dataReader.Read() -and $rowNum -lt $MaxRows) {
            $rowNum++
            "Row $rowNum:" | Out-File $outputFile -Append
            
            for ($i = 0; $i -lt $columnCount; $i++) {
                try {
                    if ($dataReader.IsDBNull($i)) {
                        "  $($columnNames[$i]) = (null)" | Out-File $outputFile -Append
                    }
                    else {
                        $value = $dataReader.GetValue($i)
                        $valueStr = $value.ToString()
                        
                        # Truncate long values
                        if ($valueStr.Length -gt 200) {
                            $valueStr = $valueStr.Substring(0, 200) + "..."
                        }
                        
                        "  $($columnNames[$i]) = $valueStr" | Out-File $outputFile -Append
                    }
                }
                catch {
                    "  $($columnNames[$i]) = (error: $_)" | Out-File $outputFile -Append
                }
            }
            "" | Out-File $outputFile -Append
        }
        
        $dataReader.Close()
        $conn.Close()
        
        Write-Host "  Exported $rowNum rows" -ForegroundColor Green
    }
    catch {
        "ERROR: $_" | Out-File $outputFile -Append
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}

# Get list of FTP queue tables
Write-Host "Connecting to database..." -ForegroundColor Cyan

try {
    $conn = New-Object System.Data.OleDb.OleDbConnection
    $conn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source='$imageManagerDbPath'"
    $conn.Open()
    
    $tables = @()
    $schema = $conn.GetSchema("Tables")
    
    foreach ($row in $schema.Rows) {
        $tableName = $row["TABLE_NAME"]
        if (-not $tableName.StartsWith("MSys")) {
            $tables += $tableName
        }
    }
    
    $conn.Close()
    
    Write-Host "Found $($tables.Count) tables" -ForegroundColor Green
    Write-Host ""
    
    "Total Tables: $($tables.Count)" | Out-File $outputFile -Append
    "" | Out-File $outputFile -Append
    
    # Find FTP queue tables
    $ftpQueueTables = $tables | Where-Object { $_ -match '^ftp\d+Queue$' }
    
    if ($ftpQueueTables) {
        Write-Host "FTP Queue Tables: $($ftpQueueTables -join ', ')" -ForegroundColor Yellow
        Write-Host ""
        
        "FTP Queue Tables: $($ftpQueueTables -join ', ')" | Out-File $outputFile -Append
        "" | Out-File $outputFile -Append
        
        # Export each FTP queue table
        foreach ($table in $ftpQueueTables) {
            Export-TableWithDataReader -TableName $table -MaxRows 5
        }
    }
    
    # Also check TargetPaths
    if ($tables -contains "TargetPaths") {
        Write-Host ""
        Export-TableWithDataReader -TableName "TargetPaths" -MaxRows 5
    }
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    "ERROR: $_" | Out-File $outputFile -Append
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "                    Complete!                                    " -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Output: $outputFile" -ForegroundColor Green
Write-Host "Size: $([Math]::Round((Get-Item $outputFile).Length / 1KB, 2)) KB" -ForegroundColor Gray
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
