<#
.SYNOPSIS
ImageManager Database Query Module

.DESCRIPTION
Name: imagemanager_db_module.ps1
Version: 1.0.0
Purpose: Query StorageCraft ImageManager.mdb database to retrieve replication queue information
Path: /scripts/imagemanager_db_module.ps1
Copyright: 2025

.NOTES
This module provides functions to:
- Connect to ImageManager.mdb database
- Discover database schema
- Query replication queue
- Extract pending file information
#>

# Function to test if ImageManager database exists
function Test-ImageManagerDatabase {
    param(
        [string]$DatabasePath = "C:\Program Files (x86)\StorageCraft\ImageManager\ImageManager.mdb"
    )
    
    if (Test-Path $DatabasePath) {
        Write-Host "ImageManager database found: $DatabasePath" -ForegroundColor Green
        return $true
    } else {
        Write-Host "ImageManager database NOT found: $DatabasePath" -ForegroundColor Red
        return $false
    }
}

# Function to get database schema (all tables)
function Get-ImageManagerSchema {
    param(
        [string]$DatabasePath = "C:\Program Files (x86)\StorageCraft\ImageManager\ImageManager.mdb"
    )
    
    try {
        $conn = New-Object System.Data.OleDb.OleDbConnection
        $conn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source='$DatabasePath'"
        $conn.Open()
        
        # Get schema information for tables
        $schemaTable = $conn.GetOleDbSchemaTable([System.Data.OleDb.OleDbSchemaGuid]::Tables, @($null, $null, $null, "TABLE"))
        
        $tables = @()
        foreach ($row in $schemaTable.Rows) {
            $tables += [PSCustomObject]@{
                TableName = $row["TABLE_NAME"]
                TableType = $row["TABLE_TYPE"]
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

# Function to get table columns
function Get-TableColumns {
    param(
        [string]$DatabasePath,
        [string]$TableName
    )
    
    try {
        $conn = New-Object System.Data.OleDb.OleDbConnection
        $conn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source='$DatabasePath'"
        $conn.Open()
        
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT TOP 1 * FROM [$TableName]"
        
        $adapter = New-Object System.Data.OleDb.OleDbDataAdapter $cmd
        $dataset = New-Object System.Data.DataSet
        $adapter.Fill($dataset) | Out-Null
        
        $columns = @()
        if ($dataset.Tables.Count -gt 0) {
            foreach ($column in $dataset.Tables[0].Columns) {
                $columns += $column.ColumnName
            }
        }
        
        $conn.Close()
        return $columns
    }
    catch {
        Write-Host "Error reading table columns for $TableName : $_" -ForegroundColor Yellow
        return $null
    }
}

# Function to query a table
function Get-TableData {
    param(
        [string]$DatabasePath,
        [string]$TableName,
        [string]$WhereClause = ""
    )
    
    try {
        $conn = New-Object System.Data.OleDb.OleDbConnection
        $conn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source='$DatabasePath'"
        $conn.Open()
        
        $cmd = $conn.CreateCommand()
        if ($WhereClause) {
            $cmd.CommandText = "SELECT * FROM [$TableName] WHERE $WhereClause"
        } else {
            $cmd.CommandText = "SELECT * FROM [$TableName]"
        }
        
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
        Write-Host "Error querying table $TableName : $_" -ForegroundColor Red
        return $null
    }
}

# Function to find replication-related tables
function Find-ReplicationTables {
    param(
        [string]$DatabasePath = "C:\Program Files (x86)\StorageCraft\ImageManager\ImageManager.mdb"
    )
    
    Write-Host "`nSearching for replication-related tables..." -ForegroundColor Cyan
    
    $tables = Get-ImageManagerSchema -DatabasePath $DatabasePath
    
    if (-not $tables) {
        Write-Host "Could not retrieve database schema." -ForegroundColor Red
        return $null
    }
    
    # Look for tables with replication-related names
    $keywords = @("Replication", "Queue", "Job", "Task", "Pending", "Transfer", "FTP", "Sync")
    
    $replicationTables = @()
    
    foreach ($table in $tables) {
        $tableName = $table.TableName
        
        # Skip system tables
        if ($tableName.StartsWith("MSys")) {
            continue
        }
        
        # Check if table name contains any keywords
        $isReplicationTable = $false
        foreach ($keyword in $keywords) {
            if ($tableName -like "*$keyword*") {
                $isReplicationTable = $true
                break
            }
        }
        
        if ($isReplicationTable) {
            $columns = Get-TableColumns -DatabasePath $DatabasePath -TableName $tableName
            $rowCount = 0
            
            try {
                $data = Get-TableData -DatabasePath $DatabasePath -TableName $tableName
                if ($data) {
                    $rowCount = $data.Rows.Count
                }
            }
            catch {
                $rowCount = 0
            }
            
            $replicationTables += [PSCustomObject]@{
                TableName = $tableName
                Columns = ($columns -join ", ")
                RowCount = $rowCount
            }
        }
    }
    
    return $replicationTables
}

# Function to get replication queue files
function Get-ReplicationQueueFiles {
    param(
        [string]$DatabasePath = "C:\Program Files (x86)\StorageCraft\ImageManager\ImageManager.mdb"
    )
    
    Write-Host "`nAnalyzing ImageManager database for replication queue..." -ForegroundColor Cyan
    
    # First, find all tables
    $tables = Get-ImageManagerSchema -DatabasePath $DatabasePath
    
    if (-not $tables) {
        Write-Host "Could not access database." -ForegroundColor Red
        return $null
    }
    
    Write-Host "Found $($tables.Count) tables in database." -ForegroundColor Gray
    
    # Try common table names first
    $commonTableNames = @(
        "ReplicationQueue",
        "ReplicationJobs",
        "ReplicationTasks",
        "Jobs",
        "Tasks",
        "Queue",
        "PendingFiles",
        "Replication"
    )
    
    $queueData = $null
    $foundTable = $null
    
    foreach ($tableName in $commonTableNames) {
        $matchingTable = $tables | Where-Object { $_.TableName -eq $tableName }
        if ($matchingTable) {
            Write-Host "Trying table: $tableName" -ForegroundColor Yellow
            $queueData = Get-TableData -DatabasePath $DatabasePath -TableName $tableName
            if ($queueData -and $queueData.Rows.Count -gt 0) {
                $foundTable = $tableName
                Write-Host "Found data in table: $tableName" -ForegroundColor Green
                break
            }
        }
    }
    
    # If not found, search all non-system tables
    if (-not $queueData) {
        Write-Host "Common table names not found. Searching all tables..." -ForegroundColor Yellow
        
        foreach ($table in $tables) {
            $tableName = $table.TableName
            
            # Skip system tables
            if ($tableName.StartsWith("MSys")) {
                continue
            }
            
            Write-Host "Checking table: $tableName" -ForegroundColor Gray
            
            $columns = Get-TableColumns -DatabasePath $DatabasePath -TableName $tableName
            
            # Look for tables with file-related columns
            $hasFileColumn = $false
            foreach ($col in $columns) {
                if ($col -like "*File*" -or $col -like "*Path*" -or $col -like "*Name*") {
                    $hasFileColumn = $true
                    break
                }
            }
            
            if ($hasFileColumn) {
                $data = Get-TableData -DatabasePath $DatabasePath -TableName $tableName
                if ($data -and $data.Rows.Count -gt 0) {
                    Write-Host "Found potential queue table: $tableName (Columns: $($columns -join ', '))" -ForegroundColor Cyan
                    $queueData = $data
                    $foundTable = $tableName
                    break
                }
            }
        }
    }
    
    if ($queueData) {
        return [PSCustomObject]@{
            TableName = $foundTable
            Data = $queueData
        }
    } else {
        return $null
    }
}

# Export functions
Export-ModuleMember -Function Test-ImageManagerDatabase, Get-ImageManagerSchema, Get-TableColumns, Get-TableData, Find-ReplicationTables, Get-ReplicationQueueFiles
