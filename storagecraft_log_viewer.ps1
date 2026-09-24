<#
.SYNOPSIS
StorageCraft Log Viewer - Browse, search, and open StorageCraft logs

.DESCRIPTION
Name: storagecraft_log_viewer.ps1
Version: 3.17.0
Purpose: Searches every known StorageCraft log location (ShadowProtect SPX service logs,
         SPX GUI logs, and ImageManager logs) and presents them as a log library showing
         the date, name, and size of each file. Selecting a file opens it in a built-in
         pager with line numbers, page navigation, and text search, so large logs can be
         reviewed without leaving the toolkit.
Author: Dwain Henderson Jr. | Superior Networks LLC
Contact: (937) 985-2480 | dhenderson@superiornetworks.biz
Copyright: 2026, Superior Networks LLC
Path: C:\ITTools\Scripts\storagecraft_log_viewer.ps1

What This Script Does:
  - Searches all known StorageCraft log locations (SPX service, SPX GUI, ImageManager)
  - Displays a log library table with source, date modified, size, and file name
  - Supports sorting by date, name, or size, plus source filtering and name filtering
  - Provides a built-in pager for large logs (next/previous page, jump to line, top/end)
  - Provides text search with match list and jump-to-match
  - Can scan every discovered log for a text string at once (support-call triage)
  - Offers open in Notepad, open containing folder, and export a copy for support tickets
  - Records every selection and error to the master audit log
  - Provides a verbose troubleshooting mode writing to a dedicated log file

Input:
  - User menu selections (file number, navigation commands, search terms)
  - StorageCraft log files discovered under the configured search paths

Output:
  - Console log library, source status summary, and paginated log content
  - Optional Notepad launch, folder launch, and exported log copy
  - Audit entries: C:\ITTools\Scripts\Logs\master_audit_log.txt
  - Verbose entries: C:\ITTools\Scripts\Logs\storagecraft_log_viewer_log.txt

Dependencies:
  - Windows PowerShell 4.0 or higher
  - Read access to StorageCraft log directories (Administrator recommended)
  - StorageCraft ShadowProtect SPX and/or ImageManager installed (otherwise paths report MISS)

Change Log:
2026-09-24 v3.17.0 - Initial release - SPX, SPX GUI, and ImageManager log library with
                     built-in pager, text search, log export, and verbose troubleshooting
#>

$ErrorActionPreference = "Continue"

# Configuration
$installPath = "C:\ITTools\Scripts"
$logDirectory = Join-Path $installPath "Logs"
$auditLogFile = Join-Path $logDirectory "master_audit_log.txt"
$viewerLogFile = Join-Path $logDirectory "storagecraft_log_viewer_log.txt"
$exportDirectory = Join-Path $logDirectory "LogExports"

# Ensure log directories exist
if (-not (Test-Path $logDirectory)) { New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null }

# Runtime state
$script:verboseMode = $false
$script:verboseLogFile = $viewerLogFile

function Write-AuditLog {
    param (
        [string]$action,
        [string]$details = "",
        [string]$level = "INFO",
        [string]$errorMessage = ""
    )
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $username = $env:USERNAME
        $computername = $env:COMPUTERNAME
        $logEntry = "[$timestamp] [$level] $username@$computername`n"
        $logEntry += "  Action: $action`n"
        if ($details)      { $logEntry += "  Details: $details`n" }
        if ($errorMessage) { $logEntry += "  Error: $errorMessage`n" }
        $logEntry += "  $("="*70)`n"
        Add-Content -Path $auditLogFile -Value $logEntry -ErrorAction SilentlyContinue
    } catch {}
}

function Write-VerboseLog {
    param (
        [string]$message,
        [string]$level = "INFO"
    )
    if (-not $script:verboseMode) { return }
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $script:verboseLogFile -Value "[$timestamp] [$level] $message" -ErrorAction SilentlyContinue
        Write-Host "  [VERBOSE] $message" -ForegroundColor DarkGray
    } catch {}
}

function Write-ActivityLog {
    param ([string]$message)
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $script:verboseLogFile -Value "[$timestamp] [ACTIVITY] $message" -ErrorAction SilentlyContinue
    } catch {}
}

function Get-ToolkitVersion {
    $toolkitVersion = "Unknown"
    $launcherPath = Join-Path $installPath "launch_menu.ps1"
    if (Test-Path $launcherPath) {
        try {
            $launcherContent = Get-Content $launcherPath -Raw -ErrorAction Stop
            if ($launcherContent -match 'Version:\s*(\d+\.\d+\.\d+)') {
                $toolkitVersion = $matches[1]
            }
        } catch {}
    }
    return $toolkitVersion
}

function Format-FileSize {
    param ([long]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N2} MB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N0} KB" -f ($Bytes / 1KB)) }
    return ("{0} B" -f $Bytes)
}

function Read-UserCommand {
    param ([string]$Prompt = "  Select an option")
    Write-Host ""
    Write-Host "$Prompt`: " -NoNewline -ForegroundColor White
    $response = Read-Host
    if ($null -eq $response) { return "" }
    return $response.Trim()
}

function Wait-ForKeyPress {
    # Waits for a single key without requiring Enter. Falls back to a timed pause
    # when no interactive console is attached (for example, redirected output).
    try {
        if ($Host.UI.RawUI -and (-not [System.Console]::IsInputRedirected)) {
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
    } catch {}
    Start-Sleep -Seconds 2
}

function Get-ConsolePageSize {
    $pageSize = 40
    try {
        $height = $Host.UI.RawUI.WindowSize.Height
        if ($height -gt 20) { $pageSize = $height - 16 }
    } catch {}
    if ($pageSize -lt 12) { $pageSize = 12 }
    if ($pageSize -gt 60) { $pageSize = 60 }
    return $pageSize
}

# ---------------------------------------------------------------------------
# Log location discovery
# ---------------------------------------------------------------------------

function Get-LogSourceDefinitions {
    $sources = New-Object System.Collections.ArrayList

    $programData = $env:ProgramData
    if (-not $programData) { $programData = "C:\ProgramData" }

    # ShadowProtect SPX service and backup job logs
    [void]$sources.Add([PSCustomObject]@{
        Source      = "SPX Service"
        Path        = (Join-Path $programData "StorageCraft\spx\log")
        Description = "ShadowProtect SPX service and backup job logs"
    })

    # ShadowProtect SPX GUI and context menu logs (current user)
    if ($env:LOCALAPPDATA) {
        [void]$sources.Add([PSCustomObject]@{
            Source      = "SPX GUI"
            Path        = (Join-Path $env:LOCALAPPDATA "StorageCraft\spx-gui\log")
            Description = "ShadowProtect SPX GUI and context menu logs (current user)"
        })
    }

    # ShadowProtect SPX GUI logs for other local profiles (only if they exist)
    $usersRoot = Join-Path $env:SystemDrive "Users"
    if (Test-Path -LiteralPath $usersRoot) {
        foreach ($userProfile in (Get-ChildItem -LiteralPath $usersRoot -Directory -ErrorAction SilentlyContinue)) {
            $guiPath = Join-Path $userProfile.FullName "AppData\Local\StorageCraft\spx-gui\log"
            if ((Test-Path -LiteralPath $guiPath) -and ($guiPath -notlike "$env:LOCALAPPDATA*")) {
                [void]$sources.Add([PSCustomObject]@{
                    Source      = "SPX GUI"
                    Path        = $guiPath
                    Description = "ShadowProtect SPX GUI logs ($($userProfile.Name) profile)"
                })
            }
        }
    }

    # ImageManager logs (both common install roots, plus ProgramData fallback)
    foreach ($programFiles in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($programFiles) {
            $imPath = Join-Path $programFiles "StorageCraft\ImageManager\Logs"
            [void]$sources.Add([PSCustomObject]@{
                Source      = "ImageManager"
                Path        = $imPath
                Description = "ImageManager verification, consolidation, and retention logs"
            })
        }
    }
    [void]$sources.Add([PSCustomObject]@{
        Source      = "ImageManager"
        Path        = (Join-Path $programData "StorageCraft\ImageManager\Logs")
        Description = "ImageManager logs (ProgramData location)"
    })

    return $sources
}

function Get-LogFileEntries {
    param (
        [string]$Path,
        [string]$Source,
        [string]$Description
    )

    $entries = @()
    if (-not $Path) { return $entries }
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-VerboseLog "Path not present: $Path"
        return $entries
    }

    try {
        $files = Get-ChildItem -LiteralPath $Path -File -ErrorAction Stop
        foreach ($file in $files) {
            if ($file.Extension -match '^\.(log|txt|out|err)$') {
                $entries += [PSCustomObject]@{
                    Source      = $Source
                    Description = $Description
                    Name        = $file.Name
                    FullName    = $file.FullName
                    Directory   = $file.DirectoryName
                    LastWrite   = $file.LastWriteTime
                    SizeBytes   = $file.Length
                    SizeDisplay = (Format-FileSize -Bytes $file.Length)
                }
            }
        }
        Write-VerboseLog "Found $($entries.Count) log file(s) in $Path"
    } catch {
        Write-VerboseLog "Unable to enumerate $Path : $($_.Exception.Message)" "ERROR"
    }

    return $entries
}

function Get-StorageCraftLogInventory {
    $sources = Get-LogSourceDefinitions
    $files = @()
    $status = @()
    $seen = @{}

    foreach ($source in $sources) {
        $exists = Test-Path -LiteralPath $source.Path
        $count = 0

        foreach ($entry in (Get-LogFileEntries -Path $source.Path -Source $source.Source -Description $source.Description)) {
            if (-not $seen.ContainsKey($entry.FullName)) {
                $seen[$entry.FullName] = $true
                $files += $entry
                $count++
            }
        }

        $status += [PSCustomObject]@{
            Source      = $source.Source
            Path        = $source.Path
            Description = $source.Description
            Exists      = $exists
            FileCount   = $count
        }
    }

    return [PSCustomObject]@{ Files = $files; Sources = $status }
}

# ---------------------------------------------------------------------------
# File reading helpers (streaming so large logs stay memory safe)
# ---------------------------------------------------------------------------

function Get-LogLineCount {
    param ([string]$Path)
    $count = 0
    try {
        $reader = [System.IO.File]::OpenText($Path)
        try {
            while ($null -ne $reader.ReadLine()) { $count++ }
        } finally {
            $reader.Close()
        }
    } catch {
        Write-VerboseLog "Line count failed for $Path : $($_.Exception.Message)" "ERROR"
        return -1
    }
    return $count
}

function Get-LogPage {
    param (
        [string]$Path,
        [int]$StartLine,
        [int]$LineCount
    )

    $lines = @()
    if ($LineCount -le 0) { return $lines }

    try {
        $reader = [System.IO.File]::OpenText($Path)
        try {
            $index = 0
            $endLine = $StartLine + $LineCount - 1
            while ($null -ne ($line = $reader.ReadLine())) {
                $index++
                if ($index -ge $StartLine) { $lines += $line }
                if ($index -ge $endLine) { break }
            }
        } finally {
            $reader.Close()
        }
    } catch {
        Write-VerboseLog "Page read failed for $Path : $($_.Exception.Message)" "ERROR"
    }

    return $lines
}

function Find-LogMatches {
    param (
        [string]$Path,
        [string]$Pattern,
        [int]$MaxMatches = 200
    )

    $matches = @()
    if (-not $Pattern) { return $matches }

    try {
        $reader = [System.IO.File]::OpenText($Path)
        try {
            $index = 0
            while ($null -ne ($line = $reader.ReadLine())) {
                $index++
                if ($line.IndexOf($Pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $matches += [PSCustomObject]@{ LineNumber = $index; Text = $line }
                    if ($matches.Count -ge $MaxMatches) { break }
                }
            }
        } finally {
            $reader.Close()
        }
    } catch {
        Write-VerboseLog "Search failed for $Path : $($_.Exception.Message)" "ERROR"
    }

    return $matches
}

function Expand-WrappedLine {
    param (
        [string]$Line,
        [int]$Width
    )

    if (-not $Line) { return @("") }
    if ($Width -lt 10) { $Width = 10 }
    if ($Line.Length -le $Width) { return @($Line) }

    $rows = @()
    $remaining = $Line
    while ($remaining.Length -gt $Width) {
        $chunk = $remaining.Substring(0, $Width)
        # Prefer breaking on whitespace so words are not split mid-token
        $breakAt = $chunk.LastIndexOf(" ")
        if ($breakAt -gt 0) {
            $rows += $chunk.Substring(0, $breakAt).TrimEnd()
            $remaining = $remaining.Substring($breakAt + 1).TrimStart()
        } else {
            $rows += $chunk
            $remaining = $remaining.Substring($Width)
        }
    }
    if ($remaining.Length -gt 0) { $rows += $remaining }
    return $rows
}

function Open-InNotepad {
    param ([string]$Path)
    try {
        Start-Process -FilePath "notepad.exe" -ArgumentList "`"$Path`"" -ErrorAction Stop
        return $true
    } catch {
        Write-VerboseLog "Notepad launch failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Open-InExplorer {
    param ([string]$Path, [switch]$SelectFile)
    try {
        if ($SelectFile) {
            Start-Process -FilePath "explorer.exe" -ArgumentList "/select,`"$Path`"" -ErrorAction Stop
        } else {
            Start-Process -FilePath "explorer.exe" -ArgumentList "`"$Path`"" -ErrorAction Stop
        }
        return $true
    } catch {
        Write-VerboseLog "Explorer launch failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Export-LogCopy {
    param ([PSCustomObject]$Entry)

    try {
        if (-not (Test-Path $exportDirectory)) {
            New-Item -ItemType Directory -Path $exportDirectory -Force | Out-Null
        }
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $targetName = ("{0}-{1}.txt" -f [System.IO.Path]::GetFileNameWithoutExtension($Entry.Name), $stamp)
        $targetPath = Join-Path $exportDirectory $targetName
        Copy-Item -LiteralPath $Entry.FullName -Destination $targetPath -Force -ErrorAction Stop
        return $targetPath
    } catch {
        Write-VerboseLog "Export failed: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# ---------------------------------------------------------------------------
# Log library display
# ---------------------------------------------------------------------------

function Get-FilteredLogFiles {
    param (
        [array]$Files,
        [string]$TypeFilter,
        [string]$NameFilter,
        [string]$SortMode
    )

    $results = $Files

    if ($TypeFilter -and $TypeFilter -ne "All") {
        $results = $results | Where-Object { $_.Source -eq $TypeFilter }
    }

    if ($NameFilter) {
        $results = $results | Where-Object { $_.Name -like "*$NameFilter*" }
    }

    switch ($SortMode) {
        "Name" { $results = $results | Sort-Object -Property Name }
        "Size" { $results = $results | Sort-Object -Property SizeBytes -Descending }
        default { $results = $results | Sort-Object -Property LastWrite -Descending }
    }

    return @($results)
}

function Show-LogLibraryHeader {
    param (
        [array]$Sources,
        [array]$Files,
        [string]$TypeFilter,
        [string]$SortMode,
        [string]$NameFilter,
        [int]$Page,
        [int]$PageCount,
        [int]$TotalFiltered
    )

    $toolkitVersion = Get-ToolkitVersion

    Write-Host ""
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host "                     SUPERIOR NETWORKS LLC                        " -ForegroundColor White
    Write-Host "     StorageCraft Log Viewer - Toolkit v$toolkitVersion" -ForegroundColor Cyan
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  Log Search Paths:" -ForegroundColor White
    foreach ($source in $Sources) {
        $marker = if ($source.Exists) { "[OK]  " } else { "[MISS]" }
        $markerColor = if ($source.Exists) { "Green" } else { "DarkGray" }
        Write-Host "    $marker " -NoNewline -ForegroundColor $markerColor
        Write-Host ("{0,-15} {1}" -f $source.Source, $source.Path) -NoNewline -ForegroundColor Gray
        if ($source.Exists) {
            Write-Host ("  ({0} file(s))" -f $source.FileCount) -ForegroundColor DarkGray
        } else {
            Write-Host "  (not present)" -ForegroundColor DarkGray
        }
    }
    Write-Host ""

    $filterLabel = if ($TypeFilter -eq "All") { "All sources" } else { $TypeFilter }
    Write-Host ("  Log Library: {0} file(s) | Source: {1} | Sort: {2}" -f $TotalFiltered, $filterLabel, $SortMode) -NoNewline -ForegroundColor White
    if ($NameFilter) {
        Write-Host (" | Name filter: {0}" -f $NameFilter) -NoNewline -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host ""

    if ($TotalFiltered -eq 0) {
        Write-Host "  No log files matched the current view." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  StorageCraft log locations may be empty if SPX or ImageManager has not" -ForegroundColor Gray
        Write-Host "  written logs yet, or if the toolkit is not running with sufficient rights." -ForegroundColor Gray
        Write-Host ""
        return
    }

    Write-Host ("   {0,4}  {1,-14} {2,-19} {3,10}  {4}" -f "#", "Source", "Date Modified", "Size", "File Name") -ForegroundColor White
    Write-Host ("   {0,4}  {1,-14} {2,-19} {3,10}  {4}" -f "----", "--------------", "-------------------", "----------", "----------------------------------------") -ForegroundColor DarkGray

    $pageSize = Get-ConsolePageSize
    $startIndex = (($Page - 1) * $pageSize)
    $pageFiles = $Files | Select-Object -Skip $startIndex -First $pageSize

    $number = $startIndex
    foreach ($file in $pageFiles) {
        $number++
        $dateText = $file.LastWrite.ToString("yyyy-MM-dd HH:mm:ss")
        Write-Host ("   {0,4}  " -f $number) -NoNewline -ForegroundColor Yellow
        Write-Host ("{0,-14} " -f $file.Source) -NoNewline -ForegroundColor Cyan
        Write-Host ("{0,-19} " -f $dateText) -NoNewline -ForegroundColor Gray
        Write-Host ("{0,10}  " -f $file.SizeDisplay) -NoNewline -ForegroundColor Green
        Write-Host $file.Name -ForegroundColor White
    }

    Write-Host ""
    if ($PageCount -gt 1) {
        Write-Host ("  Page {0} of {1}" -f $Page, $PageCount) -ForegroundColor Gray
    }
    Write-Host ""
}

function Show-LogLibraryFooter {
    Write-Host "  Select a file number to open it in the log viewer." -ForegroundColor White
    Write-Host "    [N] Next page   [P] Previous page   [S] Sort (Date/Name/Size)   [T] Filter by source" -ForegroundColor Gray
    Write-Host "    [L] Filter by file name   [C] Clear filters   [F] Find text across all logs" -ForegroundColor Gray
    Write-Host "    [O] Open a log folder in Explorer   [V] Verbose mode   [R] Refresh   [B] Back" -ForegroundColor Gray
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Log viewer (pager)
# ---------------------------------------------------------------------------

function Show-LogFileContent {
    param ([PSCustomObject]$Entry)

    Write-ActivityLog "Opened log: $($Entry.FullName)"
    Write-VerboseLog "Opening log file: $($Entry.FullName)"

    Clear-Host
    Write-Host ""
    Write-Host "  Counting lines in $($Entry.Name)..." -ForegroundColor Gray
    $totalLines = Get-LogLineCount -Path $Entry.FullName

    if ($totalLines -le 0) {
        Clear-Host
        Write-Host ""
        Write-Host "  === $($Entry.Name) ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  No readable content was found (the file may be empty or locked)." -ForegroundColor Yellow
        Write-Host "  Path: $($Entry.FullName)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Press any key to return to the log library..." -ForegroundColor Gray
        Wait-ForKeyPress
        return
    }

    $pageSize = Get-ConsolePageSize
    $pageCount = [Math]::Ceiling($totalLines / $pageSize)
    $page = 1
    $highlight = ""
    $wrapLines = $false
    $lastSearch = ""

    while ($true) {
        $startLine = (($page - 1) * $pageSize) + 1
        $endLine = [Math]::Min($page * $pageSize, $totalLines)
        $lines = Get-LogPage -Path $Entry.FullName -StartLine $startLine -LineCount $pageSize

        Clear-Host
        Write-Host ""
        Write-Host "  =================================================================" -ForegroundColor Cyan
        Write-Host "     StorageCraft Log Viewer: $($Entry.Name)" -ForegroundColor White
        Write-Host "  =================================================================" -ForegroundColor Cyan
        Write-Host "  Source:   " -NoNewline -ForegroundColor Gray
        Write-Host $Entry.Source -ForegroundColor Cyan
        Write-Host "  Path:     " -NoNewline -ForegroundColor Gray
        Write-Host $Entry.FullName -ForegroundColor Gray
        Write-Host "  Size:     " -NoNewline -ForegroundColor Gray
        Write-Host ("{0}   Modified: {1}   Lines: {2}" -f $Entry.SizeDisplay, $Entry.LastWrite.ToString("yyyy-MM-dd HH:mm:ss"), $totalLines) -ForegroundColor Gray
        if ($highlight) {
            Write-Host "  Search:   " -NoNewline -ForegroundColor Gray
            Write-Host ("matches for '{0}' are marked below" -f $highlight) -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host ("  --- Lines {0}-{1} of {2} (page {3} of {4}) ---" -f $startLine, $endLine, $totalLines, $page, $pageCount) -ForegroundColor DarkGray
        Write-Host ""

        $lineNumber = $startLine
        foreach ($line in $lines) {
            $isMatch = $false
            if ($highlight -and $line) {
                $isMatch = ($line.IndexOf($highlight, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
            }

            $displayRows = @($line)
            if ($wrapLines) {
                $wrapWidth = 100
                try {
                    $wrapWidth = $Host.UI.RawUI.WindowSize.Width - 14
                } catch {}
                $displayRows = Expand-WrappedLine -Line $line -Width $wrapWidth
            }

            $rowIndex = 0
            foreach ($row in $displayRows) {
                $prefix = if ($rowIndex -eq 0) { ("{0,6} | " -f $lineNumber) } else { "         | " }
                if ($isMatch) {
                    Write-Host $prefix -NoNewline -ForegroundColor DarkGray
                    Write-Host $row -ForegroundColor Yellow
                } else {
                    Write-Host $prefix -NoNewline -ForegroundColor DarkGray
                    Write-Host $row -ForegroundColor White
                }
                $rowIndex++
            }
            $lineNumber++
        }

        Write-Host ""
        Write-Host "  [N] Next page   [P] Previous page   [G] Go to line   [H] Start of log   [E] End of log" -ForegroundColor Gray
        Write-Host "  [F] Find text   [A] Jump to next match   [W] Toggle line wrap   [O] Open in Notepad" -ForegroundColor Gray
        Write-Host "  [D] Open folder   [X] Export a copy   [I] File details   [B] Back to log library" -ForegroundColor Gray
        if ($wrapLines) {
            Write-Host "  Line wrap: ON" -ForegroundColor Yellow
        }

        $command = Read-UserCommand -Prompt "  Command"

        switch ($command.ToUpper()) {
            "N" {
                if ($page -lt $pageCount) { $page++ } else { Write-Host "  Already on the last page." -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
            }
            "P" {
                if ($page -gt 1) { $page-- } else { Write-Host "  Already on the first page." -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
            }
            "H" {
                $page = 1
            }
            "E" {
                $page = $pageCount
            }
            "G" {
                $target = Read-UserCommand -Prompt "  Jump to line number"
                $targetLine = 0
                if ([int]::TryParse($target, [ref]$targetLine)) {
                    if ($targetLine -ge 1 -and $targetLine -le $totalLines) {
                        $page = [Math]::Ceiling($targetLine / $pageSize)
                        Write-VerboseLog "Jumped to line $targetLine in $($Entry.Name)"
                    } else {
                        Write-Host "  Line number is outside the file (1-$totalLines)." -ForegroundColor Yellow
                        Start-Sleep -Seconds 2
                    }
                } else {
                    Write-Host "  That is not a valid line number." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                }
            }
            "F" {
                $pattern = Read-UserCommand -Prompt "  Text to find"
                if ($pattern) {
                    $lastSearch = $pattern
                    Write-Host "  Searching $($Entry.Name)..." -ForegroundColor Gray
                    $matches = Find-LogMatches -Path $Entry.FullName -Pattern $pattern -MaxMatches 500
                    $highlight = $pattern
                    Write-ActivityLog "Searched '$pattern' in $($Entry.Name) - $($matches.Count) match(es)"

                    if ($matches.Count -eq 0) {
                        Write-Host "  No matches found for '$pattern' in this file." -ForegroundColor Yellow
                        $highlight = ""
                        Start-Sleep -Seconds 2
                    } else {
                        Clear-Host
                        Write-Host ""
                        Write-Host "  === Matches for '$pattern' in $($Entry.Name) ===" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host ("  Found {0} matching line(s){1}" -f $matches.Count, $(if ($matches.Count -ge 500) { " (showing first 500)" } else { "" })) -ForegroundColor White
                        Write-Host ""
                        $shown = 0
                        foreach ($match in $matches) {
                            if ($shown -ge 25) {
                                Write-Host ("  ... and {0} more matching line(s)" -f ($matches.Count - $shown)) -ForegroundColor DarkGray
                                break
                            }
                            Write-Host ("  {0,7} | " -f $match.LineNumber) -NoNewline -ForegroundColor DarkGray
                            Write-Host $match.Text -ForegroundColor Yellow
                            $shown++
                        }
                        Write-Host ""
                        $selection = Read-UserCommand -Prompt "  Match number to jump to (Enter to stay)"
                        $matchIndex = 0
                        if ([int]::TryParse($selection, [ref]$matchIndex)) {
                            if ($matchIndex -ge 1 -and $matchIndex -le $matches.Count) {
                                $jumpLine = $matches[$matchIndex - 1].LineNumber
                                $page = [Math]::Ceiling($jumpLine / $pageSize)
                                Write-VerboseLog "Jumped to match $matchIndex (line $jumpLine)"
                            } else {
                                Write-Host "  Match number is outside the list (1-$($matches.Count))." -ForegroundColor Yellow
                                Start-Sleep -Seconds 2
                            }
                        }
                    }
                }
            }
            "A" {
                if (-not $highlight) {
                    Write-Host "  Run a find ([F]) first, or press [A] after a search to walk matches." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                } else {
                    $fromLine = ($page * $pageSize) + 1
                    $matches = Find-LogMatches -Path $Entry.FullName -Pattern $highlight -MaxMatches 500
                    $nextMatch = $matches | Where-Object { $_.LineNumber -ge $fromLine } | Select-Object -First 1
                    if ($nextMatch) {
                        $page = [Math]::Ceiling($nextMatch.LineNumber / $pageSize)
                        Write-VerboseLog "Advanced to next match at line $($nextMatch.LineNumber)"
                    } else {
                        Write-Host "  No further matches after the current page." -ForegroundColor Yellow
                        Start-Sleep -Seconds 2
                    }
                }
            }
            "W" {
                $wrapLines = -not $wrapLines
            }
            "O" {
                if (Open-InNotepad -Path $Entry.FullName) {
                    Write-ActivityLog "Opened $($Entry.Name) in Notepad"
                    Write-Host "  Opened in Notepad." -ForegroundColor Green
                } else {
                    Write-Host "  Unable to launch Notepad." -ForegroundColor Red
                }
                Start-Sleep -Seconds 1
            }
            "D" {
                if (Open-InExplorer -Path $Entry.Directory) {
                    Write-Host "  Opened folder: $($Entry.Directory)" -ForegroundColor Green
                } else {
                    Write-Host "  Unable to open the folder." -ForegroundColor Red
                }
                Start-Sleep -Seconds 1
            }
            "X" {
                $exportedPath = Export-LogCopy -Entry $Entry
                if ($exportedPath) {
                    Write-ActivityLog "Exported copy: $exportedPath"
                    Write-Host "  Copy exported to: $exportedPath" -ForegroundColor Green
                } else {
                    Write-Host "  Export failed. See the verbose log for details." -ForegroundColor Red
                }
                Start-Sleep -Seconds 2
            }
            "I" {
                Clear-Host
                Write-Host ""
                Write-Host "  === File Details ===" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "  File Name:    " -NoNewline -ForegroundColor Gray
                Write-Host $Entry.Name -ForegroundColor White
                Write-Host "  Full Path:    " -NoNewline -ForegroundColor Gray
                Write-Host $Entry.FullName -ForegroundColor White
                Write-Host "  Source:       " -NoNewline -ForegroundColor Gray
                Write-Host $Entry.Source -ForegroundColor White
                Write-Host "  Purpose:      " -NoNewline -ForegroundColor Gray
                Write-Host $Entry.Description -ForegroundColor White
                Write-Host "  Size:         " -NoNewline -ForegroundColor Gray
                Write-Host ("{0} ({1:N0} bytes)" -f $Entry.SizeDisplay, $Entry.SizeBytes) -ForegroundColor White
                Write-Host "  Created:      " -NoNewline -ForegroundColor Gray
                try {
                    Write-Host (Get-Item -LiteralPath $Entry.FullName).CreationTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor White
                } catch { Write-Host "Unavailable" -ForegroundColor DarkGray }
                Write-Host "  Modified:     " -NoNewline -ForegroundColor Gray
                Write-Host $Entry.LastWrite.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor White
                Write-Host "  Total Lines:  " -NoNewline -ForegroundColor Gray
                Write-Host $totalLines -ForegroundColor White
                Write-Host "  Last Search:  " -NoNewline -ForegroundColor Gray
                Write-Host $(if ($lastSearch) { $lastSearch } else { "(none)" }) -ForegroundColor White
                Write-Host ""
                Write-Host "  Press any key to return to the log..." -ForegroundColor Gray
                Wait-ForKeyPress
            }
            "B" {
                return
            }
            default {
                Write-Host "  Invalid command. Use the letters shown above." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Search across every discovered log
# ---------------------------------------------------------------------------

function Search-AllLogs {
    param ([array]$Files)

    if ($Files.Count -eq 0) {
        Write-Host "  No log files are available to search." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }

    $pattern = Read-UserCommand -Prompt "  Text to find across all logs"
    if (-not $pattern) { return }

    Write-ActivityLog "Searched '$pattern' across $($Files.Count) log file(s)"
    Write-VerboseLog "Cross-log search for '$pattern' across $($Files.Count) file(s)"

    Clear-Host
    Write-Host ""
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host "     Searching all StorageCraft logs for: $pattern" -ForegroundColor White
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host ""

    $hits = @()
    foreach ($file in $Files) {
        Write-Host ("  Scanning {0,-45}" -f $file.Name) -NoNewline -ForegroundColor Gray
        $matches = Find-LogMatches -Path $file.FullName -Pattern $pattern -MaxMatches 20
        if ($matches.Count -gt 0) {
            Write-Host (" {0} match(es)" -f $matches.Count) -ForegroundColor Yellow
            $hits += [PSCustomObject]@{ File = $file; Matches = $matches }
        } else {
            Write-Host " no match" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    if ($hits.Count -eq 0) {
        Write-Host "  No matches found in any discovered log." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Press any key to return to the log library..." -ForegroundColor Gray
        Wait-ForKeyPress
        return
    }

    Write-Host ("  Matches found in {0} file(s):" -f $hits.Count) -ForegroundColor White
    Write-Host ""
    Write-Host ("   {0,4}  {1,-19} {2,-30} {3}" -f "#", "Date Modified", "File Name", "Matches") -ForegroundColor White
    Write-Host ("   {0,4}  {1,-19} {2,-30} {3}" -f "----", "-------------------", "------------------------------", "-------") -ForegroundColor DarkGray

    $index = 0
    foreach ($hit in $hits) {
        $index++
        Write-Host ("   {0,4}  " -f $index) -NoNewline -ForegroundColor Yellow
        Write-Host ("{0,-19} " -f $hit.File.LastWrite.ToString("yyyy-MM-dd HH:mm:ss")) -NoNewline -ForegroundColor Gray
        Write-Host ("{0,-30} " -f $hit.File.Name) -NoNewline -ForegroundColor White
        Write-Host $hit.Matches.Count -ForegroundColor Yellow
    }

    Write-Host ""
    $selection = Read-UserCommand -Prompt "  Enter a number to open that log (Enter to return)"
    $selectionIndex = 0
    if ([int]::TryParse($selection, [ref]$selectionIndex)) {
        if ($selectionIndex -ge 1 -and $selectionIndex -le $hits.Count) {
            Show-LogFileContent -Entry $hits[$selectionIndex - 1].File
        } else {
            Write-Host "  Number is outside the list (1-$($hits.Count))." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

Write-AuditLog -action "StorageCraft Log Viewer" -details "Log viewer opened"
Write-ActivityLog "StorageCraft Log Viewer started"

$inventory = $null
$needRefresh = $true
$sortMode = "Date"
$typeFilter = "All"
$nameFilter = ""
$page = 1

while ($true) {
    if ($needRefresh) {
        Clear-Host
        Write-Host ""
        Write-Host "  Scanning StorageCraft log locations..." -ForegroundColor Cyan
        Write-VerboseLog "Refreshing log inventory"
        $inventory = Get-StorageCraftLogInventory
        $needRefresh = $false
        $page = 1
        Write-VerboseLog "Inventory complete: $($inventory.Files.Count) log file(s) discovered"
    }

    $files = Get-FilteredLogFiles -Files $inventory.Files -TypeFilter $typeFilter -NameFilter $nameFilter -SortMode $sortMode
    $pageSize = Get-ConsolePageSize
    $pageCount = [Math]::Max(1, [Math]::Ceiling($files.Count / $pageSize))
    if ($page -gt $pageCount) { $page = $pageCount }
    if ($page -lt 1) { $page = 1 }

    Clear-Host
    Write-Host ""
    Show-LogLibraryHeader -Sources $inventory.Sources -Files $files -TypeFilter $typeFilter -SortMode $sortMode -NameFilter $nameFilter -Page $page -PageCount $pageCount -TotalFiltered $files.Count
    Show-LogLibraryFooter

    $command = Read-UserCommand -Prompt "  Select an option"
    if (-not $command) { continue }

    $upperCommand = $command.ToUpper()

    # Numeric selection opens the chosen log
    $selectedNumber = 0
    if ([int]::TryParse($command, [ref]$selectedNumber)) {
        if ($selectedNumber -ge 1 -and $selectedNumber -le $files.Count) {
            $entry = $files[$selectedNumber - 1]
            Write-AuditLog -action "StorageCraft Log Viewer" -details "Viewed log: $($entry.Name)"
            Show-LogFileContent -Entry $entry
        } else {
            Write-Host ("  Number must be between 1 and {0}." -f $files.Count) -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
        continue
    }

    switch ($upperCommand) {
        "N" {
            if ($page -lt $pageCount) { $page++ } else { Write-Host "  Already on the last page." -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
        }
        "P" {
            if ($page -gt 1) { $page-- } else { Write-Host "  Already on the first page." -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
        }
        "S" {
            Write-Host ""
            Write-Host "  Sort log library by:" -ForegroundColor White
            Write-Host "    [D] Date modified (newest first)" -ForegroundColor Gray
            Write-Host "    [N] File name" -ForegroundColor Gray
            Write-Host "    [Z] File size (largest first)" -ForegroundColor Gray
            $sortChoice = (Read-UserCommand -Prompt "  Sort option").ToUpper()
            switch ($sortChoice) {
                "N" { $sortMode = "Name" }
                "Z" { $sortMode = "Size" }
                default { $sortMode = "Date" }
            }
            Write-AuditLog -action "StorageCraft Log Viewer" -details "Sort changed to $sortMode"
            $page = 1
        }
        "T" {
            Write-Host ""
            Write-Host "  Filter by log source:" -ForegroundColor White
            Write-Host "    [A] All sources" -ForegroundColor Gray
            Write-Host "    [S] SPX Service logs" -ForegroundColor Gray
            Write-Host "    [G] SPX GUI logs" -ForegroundColor Gray
            Write-Host "    [I] ImageManager logs" -ForegroundColor Gray
            $typeChoice = (Read-UserCommand -Prompt "  Source filter").ToUpper()
            switch ($typeChoice) {
                "S" { $typeFilter = "SPX Service" }
                "G" { $typeFilter = "SPX GUI" }
                "I" { $typeFilter = "ImageManager" }
                default { $typeFilter = "All" }
            }
            Write-AuditLog -action "StorageCraft Log Viewer" -details "Source filter set to $typeFilter"
            $page = 1
        }
        "L" {
            $nameFilter = Read-UserCommand -Prompt "  File name contains"
            Write-AuditLog -action "StorageCraft Log Viewer" -details "Name filter set to '$nameFilter'"
            $page = 1
        }
        "C" {
            $typeFilter = "All"
            $nameFilter = ""
            $sortMode = "Date"
            $page = 1
            Write-Host "  Filters cleared." -ForegroundColor Green
            Start-Sleep -Seconds 1
        }
        "F" {
            Search-AllLogs -Files $files
        }
        "O" {
            Write-Host ""
            Write-Host "  Select a folder to open in Explorer:" -ForegroundColor White
            $folderIndex = 0
            $folderList = @()
            foreach ($source in $inventory.Sources) {
                if ($source.Exists) {
                    $folderIndex++
                    $folderList += $source
                    Write-Host ("    [{0}] {1} - {2}" -f $folderIndex, $source.Source, $source.Path) -ForegroundColor Gray
                }
            }
            if ($folderIndex -eq 0) {
                Write-Host "  No StorageCraft log folders were found on this system." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            } else {
                $folderChoice = Read-UserCommand -Prompt "  Folder number"
                $folderNumber = 0
                if ([int]::TryParse($folderChoice, [ref]$folderNumber) -and $folderNumber -ge 1 -and $folderNumber -le $folderList.Count) {
                    if (Open-InExplorer -Path $folderList[$folderNumber - 1].Path) {
                        Write-AuditLog -action "StorageCraft Log Viewer" -details "Opened folder: $($folderList[$folderNumber - 1].Path)"
                        Write-Host "  Opened folder in Explorer." -ForegroundColor Green
                    } else {
                        Write-Host "  Unable to open the folder." -ForegroundColor Red
                    }
                    Start-Sleep -Seconds 1
                }
            }
        }
        "V" {
            $script:verboseMode = -not $script:verboseMode
            if ($script:verboseMode) {
                Write-Host "  Verbose troubleshooting mode: ON" -ForegroundColor Yellow
                Write-VerboseLog "Verbose mode enabled"
            } else {
                Write-Host "  Verbose troubleshooting mode: OFF" -ForegroundColor Gray
            }
            Start-Sleep -Seconds 1
        }
        "R" {
            $needRefresh = $true
            Write-AuditLog -action "StorageCraft Log Viewer" -details "Log inventory refreshed"
        }
        "B" {
            Write-AuditLog -action "StorageCraft Log Viewer" -details "User returned to StorageCraft Troubleshooter"
            Write-ActivityLog "Log viewer closed"
            Clear-Host
            exit 0
        }
        default {
            Write-Host "  Invalid selection. Enter a file number or one of the listed letters." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}
