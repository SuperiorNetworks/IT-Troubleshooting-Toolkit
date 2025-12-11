<#
.SYNOPSIS
ImageManager Database Diagnostic Tool

.DESCRIPTION
Name: diagnostic_imagemanager_db.ps1
Version: 1.0.0
Purpose: Dump contents of ImageManager FTP queue tables for analysis
Path: /scripts/diagnostic_imagemanager_db.ps1
Copyright: 2025

.NOTES
This script exports the contents of FTP queue tables to a text file
for diagnostic purposes to understand the database structure.
#>

# Configuration
$imageManagerDbPath = "C:\Program Files (x86)\StorageCraft\ImageManager\ImageManager.mdb"
$outputFile = "C:\ITTools\Scripts\Logs\imagemanager_diagnostic.txt"
$logDirectory = "C:\ITTools\Scripts\Logs"

# Ensure log directory exists
if (-not (Test-Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "           ImageManager Database Diagnostic Tool                " -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# Check if database exists
if (-not (Test-Path $imageManagerDbPath)) {
    Write-Host "ERROR: ImageManager database not found at:" -ForegroundColor Red
    Write-Host "  $imageManagerDbPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Write-Host "Database found: $imageManagerDbPath" -ForegroundColor Green
Write-Host ""

# Initialize output file
"ImageManager Database Diagnostic Report" | Out-File $outputFile
"Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $outputFile -Append
"Database: $imageManagerDbPath" | Out-File $outputFile -Append
"=" * 80 | Out-File $outputFile -Append
"" | Out-File $outputFile -Append

# Function to get all tables
function Get-ImageManagerTables {
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
        return $tables
    }
    catch {
        Write-Host "Error reading database schema: $_" -ForegroundColor Red
        return $null
    }
}

# Function to get table data
function Get-TableData {
    param([string]$TableName)
    
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
        }
        return $null
    }
    catch {
        Write-Host "  Error querying table: $_" -ForegroundColor Red
        return $null
    }
}

# Function to export table contents
function Export-TableContents {
    param(
        [string]$TableName,
        [int]$MaxRows = 10
    )
    
    Write-Host "Analyzing table: $TableName" -ForegroundColor Cyan
    
    "" | Out-File $outputFile -Append
    "=" * 80 | Out-File $outputFile -Append
    "TABLE: $TableName" | Out-File $outputFile -Append
    "=" * 80 | Out-File $outputFile -Append
    "" | Out-File $outputFile -Append
    
    $data = Get-TableData -TableName $TableName
    
    if (-not $data -or $data.Rows.Count -eq 0) {
        "  (Table is empty)" | Out-File $outputFile -Append
        Write-Host "  Table is empty" -ForegroundColor Yellow
        return
    }
    
    $rowCount = $data.Rows.Count
    Write-Host "  Found $rowCount rows" -ForegroundColor Green
    
    "Row Count: $rowCount" | Out-File $outputFile -Append
    "" | Out-File $outputFile -Append
    
    # Get column names
    $columns = $data.Columns | ForEach-Object { $_.ColumnName }
    "Columns: $($columns -join ', ')" | Out-File $outputFile -Append
    "" | Out-File $outputFile -Append
    
    # Export first N rows
    $exportCount = [Math]::Min($rowCount, $MaxRows)
    "Showing first $exportCount rows:" | Out-File $outputFile -Append
    "-" * 80 | Out-File $outputFile -Append
    "" | Out-File $outputFile -Append
    
    for ($i = 0; $i -lt $exportCount; $i++) {
        $row = $data.Rows[$i]
        "Row $($i + 1):" | Out-File $outputFile -Append
        
        foreach ($column in $columns) {
            try {
                $value = $row[$column]
                if ($null -ne $value) {
                    $valueStr = $value.ToString()
                    if ($valueStr.Length -gt 200) {
                        $valueStr = $valueStr.Substring(0, 200) + "..."
                    }
                    "  $column = $valueStr" | Out-File $outputFile -Append
                }
                else {
                    "  $column = (null)" | Out-File $outputFile -Append
                }
            }
            catch {
                "  $column = (error reading value)" | Out-File $outputFile -Append
            }
        }
        
        "" | Out-File $outputFile -Append
    }
}

# Main execution
Write-Host "Reading database tables..." -ForegroundColor Cyan
$tables = Get-ImageManagerTables

if (-not $tables) {
    Write-Host "ERROR: Could not read database tables" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Write-Host "Found $($tables.Count) tables" -ForegroundColor Green
Write-Host ""

"Total Tables: $($tables.Count)" | Out-File $outputFile -Append
"" | Out-File $outputFile -Append
"All Tables:" | Out-File $outputFile -Append
$tables | ForEach-Object { "  - $_" } | Out-File $outputFile -Append
"" | Out-File $outputFile -Append

# Find FTP queue tables
$ftpQueueTables = $tables | Where-Object { $_ -match '^ftp\d+Queue$' }

if ($ftpQueueTables) {
    Write-Host "Found FTP Queue tables: $($ftpQueueTables -join ', ')" -ForegroundColor Green
    Write-Host ""
    
    "FTP Queue Tables Found: $($ftpQueueTables -join ', ')" | Out-File $outputFile -Append
    "" | Out-File $outputFile -Append
    
    # Export each FTP queue table
    foreach ($table in $ftpQueueTables) {
        Export-TableContents -TableName $table -MaxRows 10
    }
}
else {
    Write-Host "No FTP queue tables found" -ForegroundColor Yellow
    "No FTP queue tables found" | Out-File $outputFile -Append
}

# Also check some other potentially relevant tables
$otherTables = @("TargetPaths", "WatchPaths")
foreach ($table in $otherTables) {
    if ($tables -contains $table) {
        Write-Host ""
        Export-TableContents -TableName $table -MaxRows 5
    }
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "                    Diagnostic Complete                          " -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Output saved to:" -ForegroundColor Green
Write-Host "  $outputFile" -ForegroundColor Yellow
Write-Host ""
Write-Host "File size: $([Math]::Round((Get-Item $outputFile).Length / 1KB, 2)) KB" -ForegroundColor Gray
Write-Host ""
Write-Host "Please send this file for analysis." -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
