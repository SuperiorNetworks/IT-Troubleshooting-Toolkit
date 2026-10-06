<#
Name: project_planner.ps1
Version: 3.18.3
Purpose: Scan a file share or folder and produce a complete, offline planning report for a migration project.
Author: Dwain Henderson Jr. | Superior Networks LLC
Contact: (937) 985-2480 | dhenderson@superiornetworks.biz
Copyright: 2026, Superior Networks LLC
Path: C:\ITTools\Scripts\project_planner.ps1

What This Script Does:
  - Opens a start screen (client, project, ticket, folder to scan, save report to, Scan, Open previous report)
  - Scans every folder and file inside the folder to scan (metadata only; OneDrive cloud-only files are never downloaded)
  - Writes a full capture (capture.json) of every folder and file for offline exploration
  - Calculates planning metrics: size, counts, file types, dates, growth rate, size buckets, depth, path lengths
  - Flags migration problems: characters that break web links, long paths, trailing dots/spaces, case collisions,
    duplicate names, junk files, zero-byte files, bad dates, Azure Blob name and URL limits
  - Optional: checks an MRPeasy "export file links" CSV against the scan and drafts the old,new link update CSV for Azure Blob
  - Optional: MD5 hashes of local files (true duplicates) and permissions for the top two folder levels
  - Builds a self-contained report.html (brand shell, Help Guide), CSVs, summary.json, an on-screen report, and a zip
  - Can rebuild the report later from capture.json without rescanning (-FromCapture)

Input:
  - Start screen fields, or parameters: -Client -Project -Ticket -Path -ReportPath (default C:\ITTools\Reports)
  - Optional: -MrpLinks (MRPeasy Settings > Database Maintenance > Export file links CSV), -BlobBaseUrl, -HashLocal, -IncludeAcl
  - Optional: -FromCapture <capture.json> to rebuild a report; -NoGui for unattended runs
  - Settings (last values, recent reports): %APPDATA%\SuperiorNetworks\ProjectPlanner\settings.json

Output:
  - <Save report to folder>\<client>-<ticket>-<yyyyMMdd-HHmm>\ with report.html, capture.json, summary.json, CSVs, device-info.txt
  - <same name>.zip next to that folder
  - If -MrpLinks is used: mrp-link-review.csv, mrp-link-update-DRAFT.csv, mrp-unlinked-pdfs.csv

Dependencies:
  - Windows PowerShell 5.1 (built in) or PowerShell 7; no modules, no admin rights
  - System.Windows.Forms / System.Drawing for the start screen (Windows only)
  - System.Web.Extensions (JavaScriptSerializer) to read capture.json in Windows PowerShell 5.1
  - System.IO.Compression.FileSystem (.NET 4.5+) for the zip

Change Log:
  2026-10-06 v1.0.0 - Initial release (Dwain Henderson Jr)
  2026-10-06 v3.18.0 - Added to IT Troubleshooting Toolkit (launcher option 7); version follows the toolkit (Dwain Henderson Jr)
                      Fix: a progress-bar failure (no real console, e.g. SSH or RMM) no longer marks a folder
                      as unreadable and skips its files. Zip uses .NET ZipFile instead of Compress-Archive.
  2026-10-06 v3.18.1 - Reports default to C:\ITTools\Reports (created if missing; also used by -NoGui when
                      -ReportPath is not given). Window title/footer show the header version, not 1.0.0 (Dwain Henderson Jr)
  2026-10-06 v3.18.2 - Progress updates every second (hashing a big share looked frozen); shows the file being
                      hashed when it is 50 MB+. Hashing uses .NET MD5 (faster, works on long paths in PS 5.0);
                      hash failures and FIPS mode are reported instead of silently skipped (Dwain Henderson Jr)
  2026-10-06 v3.18.3 - Report location shown everywhere: "REPORT SAVED" block in the console, folder and zip in
                      the Scan complete box, "Report saved to" bar (with Copy path) in report.html. Start-screen
                      runs keep the window open until Enter. Plain labels: "Folder to scan" (with a read-only
                      hint) and "Save report to" instead of Parent path / Report path. New Scan complete window
                      (Open report, Open folder, Email via Outlook with the zip attached or Gmail); report.html
                      gets Open folder and Outlook/Gmail email buttons (Dwain Henderson Jr)
#>

<#
.SYNOPSIS
  Project Planner: scan a folder or share and build an offline planning report.
.EXAMPLE
  Double-click run_project_planner.cmd (opens the start screen).
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\project_planner.ps1 -NoGui -Client "Acme" -Project "File server to Azure" -Ticket 12345 -Path "D:\Shares\Design"
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\project_planner.ps1 -NoGui -FromCapture "C:\Temp\Acme-12345-20261008-0914\capture.json" -MrpLinks "C:\Temp\file-links.csv" -BlobBaseUrl "https://acmedrawings.blob.core.windows.net/drawings"
#>
[CmdletBinding()]
param(
    [string] $Client,
    [string] $Project,
    [string] $Ticket,
    [string] $Path,
    [string] $ReportPath,
    [string] $MrpLinks,
    [string] $BlobBaseUrl,
    [switch] $HashLocal,
    [switch] $IncludeAcl,
    [string] $FromCapture,
    [switch] $NoGui,
    [switch] $NoZip,
    [switch] $OpenReport
)

$ErrorActionPreference = 'Continue'
$ToolName = 'Project Planner'
# Version comes from the Version: line in this file's header (toolkit version); the value here is
# only a fallback if the header can't be read.
$ToolVersion = '3.18.3'
try {
    foreach ($hdrLine in (Get-Content -LiteralPath $PSCommandPath -TotalCount 10 -ErrorAction Stop)) {
        if ($hdrLine -match '^Version:\s*(\d+\.\d+\.\d+)') { $ToolVersion = $matches[1]; break }
    }
} catch {}
$IsWin = ($env:OS -eq 'Windows_NT')
# Default report folder: next to the toolkit, outside C:\ITTools\Scripts so updates never touch reports
$DefaultReportPath = 'C:\ITTools\Reports'
# Where the Email buttons send the report
$ReportEmailTo = 'dhenderson@superiornetworks.biz'
$CloudMask = 0x1000 -bor 0x400000 -bor 0x40000   # Offline / RecallOnDataAccess / RecallOnOpen (OneDrive cloud-only)
$Inv = [Globalization.CultureInfo]::InvariantCulture
$LogoBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAPIAAACACAYAAAAxgjRuAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAA4JpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuNi1jMDE0IDc5LjE1Njc5NywgMjAxNC8wOC8yMC0wOTo1MzowMiAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wTU09Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9tbS8iIHhtbG5zOnN0UmVmPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvc1R5cGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0ieG1wLmRpZDoxRTA3OUU0RTBBMjA2ODExOEE2REEwRDZCNEUzRjkwRiIgeG1wTU06RG9jdW1lbnRJRD0ieG1wLmRpZDo4OEMzQzJFMTg3RDAxMUU1OTE5QkQ5OUVFRUExMzk2RCIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDo4OEMzQzJFMDg3RDAxMUU1OTE5QkQ5OUVFRUExMzk2RCIgeG1wOkNyZWF0b3JUb29sPSJBZG9iZSBQaG90b3Nob3AgQ0MgMjAxNCAoTWFjaW50b3NoKSI+IDx4bXBNTTpEZXJpdmVkRnJvbSBzdFJlZjppbnN0YW5jZUlEPSJ4bXAuaWlkOjg0NWVlNzk3LWJkODAtZmQ0MS1iYTU0LTc3MjQ5YmI4NzU4ZiIgc3RSZWY6ZG9jdW1lbnRJRD0iYWRvYmU6ZG9jaWQ6cGhvdG9zaG9wOjI1YjljOWNmLWM3NGQtMTE3OC1hZjM4LWYw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'

class PPFolder {
    [string] $Rel; [string] $Name; [int] $Parent; [int] $Depth
    [datetime] $Created; [datetime] $Modified
    [int] $DirectFiles; [int] $SubDirs; [bool] $Reparse; [string] $Error
    [long] $RecBytes; [int] $RecFiles; [datetime] $Newest; [int] $Pdf; [int] $Ard; [string] $Issues
}
class PPFile {
    [string] $Rel; [string] $Name; [string] $Ext; [int] $Dir; [long] $Size
    [datetime] $Created; [datetime] $Modified; [int] $Attr; [string] $Hash; [string] $Issues
}

# =====================================================================================
# Helpers
# =====================================================================================
function Get-JStr([string] $s) {
    if ($null -eq $s) { return 'null' }
    $s = $s.Replace('\', '\\').Replace('"', '\"').Replace('</', '<\/')
    if ($s -match '[\x00-\x1f\u2028\u2029]') {
        $s = [regex]::Replace($s, '[\x00-\x1f\u2028\u2029]', { param($m) '\u{0:x4}' -f [int][char]$m.Value })
    }
    return '"' + $s + '"'
}

function ConvertTo-PPJson($v) {
    if ($null -eq $v) { return 'null' }
    if ($v -is [string]) { return (Get-JStr $v) }
    if ($v -is [bool]) { if ($v) { return 'true' } else { return 'false' } }
    if ($v -is [datetime]) { return (Get-JStr $v.ToString('s')) }
    if ($v -is [enum] -or $v -is [char]) { return (Get-JStr ([string]$v)) }
    if ($v -is [ValueType]) { return [Convert]::ToString($v, $Inv) }
    if ($v -is [System.Collections.IDictionary]) {
        $parts = foreach ($k in $v.Keys) { (Get-JStr ([string]$k)) + ':' + (ConvertTo-PPJson $v[$k]) }
        return '{' + (@($parts) -join ',') + '}'
    }
    if ($v -is [System.Collections.IEnumerable]) {
        $parts = foreach ($x in $v) { ConvertTo-PPJson $x }
        return '[' + (@($parts) -join ',') + ']'
    }
    if ($v -is [System.Management.Automation.PSCustomObject]) {
        $parts = foreach ($p in $v.PSObject.Properties) { (Get-JStr $p.Name) + ':' + (ConvertTo-PPJson $p.Value) }
        return '{' + (@($parts) -join ',') + '}'
    }
    return (Get-JStr ([string]$v))
}

# Name "shape": digits become 9 (length kept), letter runs become A. "12372 Rev B" -> "99999 A A"
function Get-Shape([string] $s) { ($s -creplace '[0-9]', '9') -creplace '[A-Za-z]+', 'A' }

function Get-PPBlobUrl([string] $base, [string] $rel) {
    $enc = (@($rel.Split('/')) | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    if ($base) { return $base.TrimEnd('/') + '/' + $enc }
    return $enc
}

function Get-SafeName([string] $s) {
    $t = ($s -replace '[^A-Za-z0-9._-]+', '-').Trim('-')
    if (-not $t) { $t = 'scan' }
    return $t
}

function Format-Bytes([double] $b) {
    if ($b -ge 1TB) { return '{0:N2} TB' -f ($b / 1TB) }
    if ($b -ge 1GB) { return '{0:N2} GB' -f ($b / 1GB) }
    if ($b -ge 1MB) { return '{0:N1} MB' -f ($b / 1MB) }
    if ($b -ge 1KB) { return '{0:N0} KB' -f ($b / 1KB) }
    return '{0:N0} B' -f $b
}

function Get-SettingsPath {
    if ($IsWin -and $env:APPDATA) { return (Join-Path $env:APPDATA 'SuperiorNetworks\ProjectPlanner\settings.json') }
    return (Join-Path $HOME '.config/project-planner/settings.json')
}

function Get-PPSettings {
    $s = @{ last = @{}; recent = @() }
    try {
        $p = Get-SettingsPath
        if (Test-Path -LiteralPath $p) {
            $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
            if ($j.last) { foreach ($pr in $j.last.PSObject.Properties) { $s.last[$pr.Name] = $pr.Value } }
            if ($j.recent) { $s.recent = @($j.recent | ForEach-Object { @{ label = $_.label; path = $_.path } }) }
        }
    } catch {}
    return $s
}

function Save-PPSettings($s) {
    try {
        $p = Get-SettingsPath
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null
        [IO.File]::WriteAllText($p, (ConvertTo-PPJson $s))
    } catch {}
}

function Add-PPRecent($s, [string] $label, [string] $htmlPath) {
    $list = @(@{ label = $label; path = $htmlPath }) + @($s.recent | Where-Object { $_.path -ne $htmlPath })
    $s.recent = @($list | Select-Object -First 10)
}

function Open-PPFile([string] $p) {
    if (-not (Test-Path -LiteralPath $p)) { Write-Warning "Not found: $p"; return }
    try {
        if ($IsWin) { Start-Process -FilePath $p }
        elseif ($IsMacOS) { & open $p }
        else { & xdg-open $p 2>$null }
    } catch { Write-Warning "Could not open $p : $_" }
}

# Opens a folder, URL or mailto: link through Explorer, so it runs as the signed-in user even when
# Project Planner runs as administrator (an elevated browser or mail app causes problems).
function Open-PPAsUser([string] $target) {
    try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $target + '"') } catch { Write-Warning "Could not open $target : $_" }
}

# Opens File Explorer on the folder with the zip (or report folder) selected
function Show-PPInFolder([string] $item) {
    if (-not $IsWin) { Open-PPFile (Split-Path -Parent $item); return }
    try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"' + $item + '"') } catch { Write-Warning "Could not open Explorer: $_" }
}

# Subject, bodies and links for emailing the report zip to Superior Networks
function Get-PPMailInfo($meta, [string] $zip) {
    $client = [string]$meta.client
    $subject = "Project Planner report - $client" + $(if ($meta.ticket) { " - Ticket #$($meta.ticket)" } else { '' })
    $when = ([string]$meta.scanStarted).Replace('T', ' ')
    $nl = "`r`n"
    $base = "Hi Dwain,$nl$($nl)Here is the Project Planner report for $client ($($meta.project)).$nl" +
            "Folder scanned: $($meta.root)$($nl)Computer: $($meta.computer)$($nl)Scanned: $when$nl"
    $attached = $base + "$($nl)The report zip is attached.$nl"
    $manual = $base + "$($nl)Please attach this file before sending:$nl$zip$nl"
    $e = { param($t) [Uri]::EscapeDataString([string]$t) }
    return @{
        To = $ReportEmailTo; Subject = $subject; BodyAttached = $attached; BodyManual = $manual
        Mailto = 'mailto:' + $ReportEmailTo + '?subject=' + (& $e $subject) + '&body=' + (& $e $manual)
        Gmail = 'https://mail.google.com/mail/?view=cm&fs=1&to=' + (& $e $ReportEmailTo) + '&su=' + (& $e $subject) + '&body=' + (& $e $manual)
    }
}

# Desktop Outlook: new email with the zip attached. Returns $true if Outlook took it.
# Tries Outlook automation first, then the outlook.exe /a switch. New Outlook and Outlook on
# the web can't be automated, so the caller falls back to a filled-in email plus Explorer.
function Send-PPOutlookMail($mail, [string] $zip) {
    if (-not $IsWin) { return $false }
    try {
        $ol = New-Object -ComObject Outlook.Application -ErrorAction Stop
        $m = $ol.CreateItem(0)
        $m.To = $mail.To; $m.Subject = $mail.Subject; $m.Body = $mail.BodyAttached
        if ($zip) { [void]$m.Attachments.Add($zip) }
        $m.Display()
        return $true
    } catch {}
    $exe = $null
    try { $exe = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE' -ErrorAction Stop).'(default)' } catch {}
    if ($exe -and (Test-Path -LiteralPath $exe) -and $zip) {
        try {
            Start-Process -FilePath $exe -ArgumentList @('/c', 'ipm.note', '/m', ('"' + $mail.To + '?subject=' + [Uri]::EscapeDataString($mail.Subject) + '"'), '/a', ('"' + $zip + '"')) -ErrorAction Stop
            return $true
        } catch {}
    }
    return $false
}

# Small Outlook / Gmail icons for the buttons. Uses the real Outlook icon when Outlook is
# installed; otherwise draws a simple envelope.
function New-PPMailIcon([string] $kind) {
    $bmp = New-Object System.Drawing.Bitmap(20, 20)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
    $pt = { param($x, $y) New-Object System.Drawing.Point($x, $y) }
    if ($kind -eq 'outlook') {
        $exe = $null
        try { $exe = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE' -ErrorAction Stop).'(default)' } catch {}
        if ($exe -and (Test-Path -LiteralPath $exe)) {
            try { $ico = [System.Drawing.Icon]::ExtractAssociatedIcon($exe); $g.DrawImage($ico.ToBitmap(), 0, 0, 20, 20); $g.Dispose(); return $bmp } catch {}
        }
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(10, 100, 200))), 1, 3, 18, 14)
        $g.DrawLines((New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)), [System.Drawing.Point[]]@((& $pt 3 6), (& $pt 10 11), (& $pt 17 6)))
    } else {
        $g.FillRectangle([System.Drawing.Brushes]::White, 1, 3, 18, 14)
        $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(197, 34, 31), 1)), 1, 3, 18, 14)
        $g.DrawLines((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(234, 67, 53), 2.5)), [System.Drawing.Point[]]@((& $pt 3 5), (& $pt 10 11), (& $pt 17 5)))
    }
    $g.Dispose()
    return $bmp
}

# "Scan complete" window: where the report is, open it, open the folder, email the zip
function Show-PPDoneForm([string] $report, [string] $outDir, [string] $zip, $mail) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $black = [System.Drawing.ColorTranslator]::FromHtml('#1a1a1a')
    $muted = [System.Drawing.ColorTranslator]::FromHtml('#7a7974')
    $f = New-Object System.Windows.Forms.Form
    $f.Text = "$ToolName - Scan complete"; $f.StartPosition = 'CenterScreen'; $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.Font = New-Object System.Drawing.Font('Arial', 9); $f.BackColor = [System.Drawing.Color]::White; $f.TopMost = $true
    $f.ClientSize = New-Object System.Drawing.Size(600, 330)
    $add = { param($c, $x, $y, $w, $h) $c.Location = New-Object System.Drawing.Point($x, $y); $c.Size = New-Object System.Drawing.Size($w, $h); $f.Controls.Add($c); $c }
    $btn = { param([string] $t, $x, $y, $w) $b = New-Object System.Windows.Forms.Button; $b.Text = $t; $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderColor = $black; & $add $b $x $y $w 30 }

    $h = New-Object System.Windows.Forms.Label; $h.Text = 'Scan complete'; $h.Font = New-Object System.Drawing.Font('Arial', 13, [System.Drawing.FontStyle]::Bold); [void](& $add $h 16 12 560 26)
    $l1 = New-Object System.Windows.Forms.Label; $l1.Text = 'Report saved to:'; [void](& $add $l1 16 48 560 18)
    $tb = New-Object System.Windows.Forms.TextBox; $tb.Text = $outDir; $tb.ReadOnly = $true; $tb.BackColor = [System.Drawing.Color]::White; [void](& $add $tb 16 68 568 24)
    $zipText = 'No zip was created.'
    $big = $false
    if ($zip -and (Test-Path -LiteralPath $zip)) {
        $len = (Get-Item -LiteralPath $zip).Length
        $zipText = "Zip to send back: $(Split-Path -Leaf $zip)  ($(Format-Bytes $len))"
        $big = ($len -gt 20MB)
    }
    $l2 = New-Object System.Windows.Forms.Label; $l2.Text = $zipText; $l2.ForeColor = $muted; [void](& $add $l2 16 96 568 18)

    $bReport = & $btn 'Open report' 16 124 130
    $bFolder = & $btn 'Open folder' 154 124 130
    $bReport.Add_Click({ Open-PPFile $report })
    $bFolder.Add_Click({ if ($zip -and (Test-Path -LiteralPath $zip)) { Show-PPInFolder $zip } else { Show-PPInFolder $report } })

    $l3 = New-Object System.Windows.Forms.Label; $l3.Text = 'Email the report to Superior Networks:'; $l3.Font = New-Object System.Drawing.Font('Arial', 9, [System.Drawing.FontStyle]::Bold); [void](& $add $l3 16 172 568 18)
    $bOutlook = & $btn 'Outlook' 16 194 130
    $bGmail = & $btn 'Gmail' 154 194 130
    foreach ($pair in @(@($bOutlook, 'outlook'), @($bGmail, 'gmail'))) {
        try { $pair[0].Image = New-PPMailIcon $pair[1]; $pair[0].ImageAlign = 'MiddleLeft'; $pair[0].TextImageRelation = 'ImageBeforeText'; $pair[0].Padding = New-Object System.Windows.Forms.Padding(8, 0, 8, 0) } catch {}
    }
    $status = New-Object System.Windows.Forms.Label; $status.ForeColor = $muted
    $status.Text = $(if ($big) { 'The zip is over 20 MB. Email may refuse it; if so, share it with a OneDrive or Google Drive link instead.' } else { 'Outlook attaches the zip for you. Gmail opens in your browser with the folder next to it: drag the zip into the email.' })
    if ($big) { $status.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#a13544') }
    [void](& $add $status 16 232 568 36)
    if (-not $zip) { $bOutlook.Enabled = $false; $bGmail.Enabled = $false }
    $bOutlook.Add_Click({
        if (Send-PPOutlookMail $mail $zip) {
            $status.ForeColor = $muted; $status.Text = 'An Outlook email is open with the zip attached. Check it, then click Send.'
        } else {
            Open-PPAsUser $mail.Mailto; Show-PPInFolder $zip
            $status.ForeColor = $muted; $status.Text = "Outlook couldn't attach the file by itself. An email is open: drag the zip from the folder window into it, then click Send."
        }
    })
    $bGmail.Add_Click({
        Open-PPAsUser $mail.Gmail; Show-PPInFolder $zip
        $status.ForeColor = $muted; $status.Text = 'Gmail is open in your browser. Drag the zip from the folder window into the email, then click Send.'
    })
    $bClose = & $btn 'Close' 454 284 130
    $bClose.BackColor = $black; $bClose.ForeColor = [System.Drawing.Color]::White
    $bClose.Add_Click({ $f.Close() })
    $f.AcceptButton = $bClose; $f.CancelButton = $bClose
    $f.Add_Shown({ $f.TopMost = $false; $f.Activate() })
    [void]$f.ShowDialog()
}

# Returns a list of problems with the inputs (empty list = OK)
function Test-PPInputs($v) {
    $err = New-Object System.Collections.Generic.List[string]
    if (-not $v.Client) { $err.Add('Client name is required.') }
    if (-not $v.Project) { $err.Add('Project description is required.') }
    if ($v.Ticket -and $v.Ticket -notmatch '^\d+$') { $err.Add('Ticket # should be digits only.') }
    if (-not $v.Path) { $err.Add('Choose a folder to scan.') }
    elseif (-not (Test-Path -LiteralPath $v.Path -PathType Container)) { $err.Add("Folder to scan not found: $($v.Path)") }
    if (-not $v.ReportPath) { $err.Add('Choose where to save the report.') }
    elseif (-not (Test-Path -LiteralPath $v.ReportPath -PathType Container)) { $err.Add("Report folder not found: $($v.ReportPath)") }
    else {
        try {
            $t = Join-Path $v.ReportPath ('.pp-write-test-' + [guid]::NewGuid().ToString('N'))
            [IO.File]::WriteAllText($t, 'x'); Remove-Item -LiteralPath $t -Force
        } catch { $err.Add("Can't save to this folder: $($v.ReportPath)") }
        if ($v.Path -and (Test-Path -LiteralPath $v.Path)) {
            $src = (Resolve-Path -LiteralPath $v.Path).ProviderPath.TrimEnd('\', '/')
            $dst = (Resolve-Path -LiteralPath $v.ReportPath).ProviderPath.TrimEnd('\', '/')
            if ($dst -ieq $src -or $dst.StartsWith($src + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                $err.Add('Save the report outside the folder being scanned.')
            }
        }
    }
    if ($v.MrpLinks -and -not (Test-Path -LiteralPath $v.MrpLinks -PathType Leaf)) { $err.Add("MRPeasy links CSV not found: $($v.MrpLinks)") }
    if ($v.BlobBaseUrl -and $v.BlobBaseUrl -notmatch '^https://') { $err.Add('Blob base URL should start with https://') }
    return ,$err
}

# =====================================================================================
# Device info (Windows only parts are skipped elsewhere)
# =====================================================================================
function Get-PPDeviceInfo([string] $root) {
    $dev = New-Object System.Collections.Generic.List[string]
    $lib = ''
    $dev.Add("$ToolName v$ToolVersion")
    $dev.Add("Collected: $((Get-Date).ToString('s'))")
    $dev.Add("PowerShell: $($PSVersionTable.PSVersion)")
    $dev.Add("Scan root: $root")
    if ($IsWin) {
        try { $os = Get-CimInstance Win32_OperatingSystem; $dev.Add("OS: $($os.Caption) $($os.Version) build $($os.BuildNumber)") } catch { $dev.Add('OS: (unavailable)') }
        $dev.Add("Computer name: $env:COMPUTERNAME   User: $env:USERNAME   Domain: $env:USERDOMAIN")
        $dev.Add('')
        $dev.Add('--- Entra / Intune join state (dsregcmd /status, selected lines) ---')
        try { dsregcmd /status 2>$null | Where-Object { $_ -match 'AzureAdJoined|EnterpriseJoined|DomainJoined|DeviceAuthStatus|TenantName|MdmUrl|WorkplaceJoined' } | ForEach-Object { $dev.Add($_.Trim()) } } catch { $dev.Add('(dsregcmd not available)') }
        $dev.Add('')
        $dev.Add('--- Mapped drives and shares ---')
        try { Get-SmbMapping -ErrorAction Stop | ForEach-Object { $dev.Add("$($_.LocalPath)  ->  $($_.RemotePath)  [$($_.Status)]") } } catch { $dev.Add('(none or unavailable)') }
        try { Get-PSDrive -PSProvider FileSystem | ForEach-Object { $dev.Add("Drive $($_.Name): used $([math]::Round($_.Used/1GB,1)) GB, free $([math]::Round($_.Free/1GB,1)) GB  $($_.DisplayRoot)") } } catch {}
        $dev.Add('')
        $dev.Add('--- SharePoint / OneDrive libraries synced on this PC (folder -> library URL) ---')
        try {
            Get-ChildItem 'HKCU:\Software\SyncEngines\Providers\OneDrive' -ErrorAction Stop | ForEach-Object {
                $p = Get-ItemProperty -LiteralPath $_.PSPath
                if ($p.MountPoint) {
                    $dev.Add("$($p.MountPoint)  ->  $($p.UrlNamespace)  [LibraryType: $($p.LibraryType)]")
                    if ($root.StartsWith($p.MountPoint.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) { $lib = $p.UrlNamespace }
                }
            }
        } catch { $dev.Add('(none found)') }
        $dev.Add("Scan root syncs from: $(if ($lib) { $lib } else { '(not a synced library, or not found)' })")
        $dev.Add('')
        $dev.Add('--- Installed CAD / PDF software ---')
        $apps = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match 'Artios|Esko|Acrobat|Bluebeam|AutoCAD|SolidWorks|PDF' } | Sort-Object DisplayName -Unique
        if ($apps) { $apps | ForEach-Object { $dev.Add("$($_.DisplayName)  $($_.DisplayVersion)") } } else { $dev.Add('(none found)') }
    } else {
        $dev.Add("Computer: $([Environment]::MachineName)   User: $([Environment]::UserName)")
        $dev.Add('(not Windows: join state, mapped drives, sync libraries and installed apps skipped)')
    }
    return @{ lines = $dev; library = $lib }
}

# =====================================================================================
# Scan
# =====================================================================================
function Test-PPLink([string] $p) {
    try { $i = Get-Item -LiteralPath $p -Force -ErrorAction Stop; return ($i.LinkType -eq 'Junction' -or $i.LinkType -eq 'SymbolicLink') } catch { return $false }
}

function Invoke-PPScan([string] $root, [bool] $doHash) {
    $rootFull = (Resolve-Path -LiteralPath $root).ProviderPath
    if ($rootFull.Length -gt 3) { $rootFull = $rootFull.TrimEnd('\', '/') }
    $scanRoot = $rootFull
    if ($IsWin -and -not $rootFull.StartsWith('\\?\')) {
        $try = if ($rootFull.StartsWith('\\')) { '\\?\UNC\' + $rootFull.Substring(2) } else { '\\?\' + $rootFull }
        try { if ((New-Object IO.DirectoryInfo $try).Exists) { $scanRoot = $try } } catch {}
    }
    $cut = $scanRoot.TrimEnd('\', '/').Length
    $folders = New-Object 'System.Collections.Generic.List[PPFolder]'
    $files = New-Object 'System.Collections.Generic.List[PPFile]'
    $errors = New-Object 'System.Collections.Generic.List[string]'
    $stack = New-Object 'System.Collections.Generic.Stack[object]'
    $stack.Push(@($scanRoot, -1, 0, $false))
    $count = 0
    $rootName = Split-Path -Leaf $rootFull
    if (-not $rootName) { $rootName = $rootFull }
    Write-Host "Scanning $rootFull ..." -ForegroundColor Cyan
    # Hashing reads every file. Use .NET MD5 directly (faster than Get-FileHash, and works on every
    # path the scan can read). Windows in FIPS mode blocks MD5: say so and scan without hashes.
    $md5 = $null; $hashFails = 0
    if ($doHash) {
        try { $md5 = [Security.Cryptography.MD5]::Create() } catch { $md5 = $null }
        if ($md5) { Write-Host "Hash local files is on: every file is read, so a large share can take a long time." -ForegroundColor Yellow }
        else { Write-Host "Hash local files skipped: MD5 is not allowed on this PC (FIPS mode)." -ForegroundColor Yellow; $errors.Add('(hash) MD5 not allowed on this PC (FIPS mode); scanned without hashes') }
    }
    # Progress updates once a second (not every N items), so slow hashing never looks frozen
    $tick = [Diagnostics.Stopwatch]::StartNew()
    while ($stack.Count -gt 0) {
        $item = $stack.Pop()
        $dirPath = [string]$item[0]
        $di = New-Object IO.DirectoryInfo $dirPath
        $fo = [PPFolder]::new()
        $rel = if ($dirPath.Length -gt $cut) { $dirPath.Substring($cut).TrimStart('\', '/').Replace('\', '/') } else { '' }
        $fo.Rel = $rel
        $fo.Name = if ($rel) { $di.Name } else { $rootName }
        $fo.Parent = [int]$item[1]; $fo.Depth = [int]$item[2]
        try { $fo.Created = $di.CreationTime; $fo.Modified = $di.LastWriteTime } catch {}
        $idx = $folders.Count
        $folders.Add($fo)
        if ($item[3]) { $fo.Reparse = $true; continue }
        if ($fo.Depth -ge 200) { $fo.Error = 'Stopped: deeper than 200 levels'; $errors.Add("$rel : stopped at 200 levels"); continue }
        $subs = New-Object System.Collections.Generic.List[object]
        try {
            foreach ($e in $di.EnumerateFileSystemInfos()) {
                $count++
                # Progress is display only. It can throw without a real console (SSH, RMM), and that
                # must not be counted as a folder read error, so it gets its own try/catch.
                if ($tick.ElapsedMilliseconds -ge 1000) { $tick.Restart(); try { Write-Progress -Activity "$ToolName scan" -Status ("{0:N0} items, {1:N0} files" -f $count, $files.Count) -CurrentOperation $rel } catch {} }
                $attr = [int]$e.Attributes
                if ($e -is [IO.DirectoryInfo]) {
                    $fo.SubDirs++
                    $isLink = $false
                    if (($attr -band 0x400) -and -not ($attr -band $CloudMask)) { $isLink = Test-PPLink $e.FullName }
                    $subs.Add(@($e.FullName, $idx, ($fo.Depth + 1), $isLink))
                } else {
                    $f = [PPFile]::new()
                    $f.Rel = if ($rel) { $rel + '/' + $e.Name } else { $e.Name }
                    $f.Name = $e.Name
                    $f.Ext = $e.Extension.ToLowerInvariant()
                    $f.Dir = $idx
                    $f.Size = $e.Length
                    $f.Created = $e.CreationTime
                    $f.Modified = $e.LastWriteTime
                    $f.Attr = $attr
                    if ($md5 -and -not ($attr -band $CloudMask)) {
                        if ($e.Length -ge 50MB) {
                            $tick.Restart()
                            try { Write-Progress -Activity "$ToolName scan" -Status ("{0:N0} items, {1:N0} files" -f $count, $files.Count) -CurrentOperation ("Hashing {0} ({1:N0} MB)" -f $f.Rel, ($e.Length / 1MB)) } catch {}
                        }
                        $fs = $null
                        try {
                            $fs = New-Object IO.FileStream($e.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
                            $f.Hash = [BitConverter]::ToString($md5.ComputeHash($fs)).Replace('-', '')
                        } catch { $hashFails++ } finally { if ($fs) { $fs.Dispose() } }
                    }
                    $files.Add($f)
                    $fo.DirectFiles++
                }
            }
        } catch {
            $fo.Error = $_.Exception.Message
            $errors.Add("$(if ($rel) { $rel } else { '(root)' }) : $($_.Exception.Message)")
        }
        for ($i = $subs.Count - 1; $i -ge 0; $i--) { $stack.Push($subs[$i]) }
    }
    try { Write-Progress -Activity "$ToolName scan" -Completed } catch {}
    if ($md5) { $md5.Dispose() }
    if ($hashFails) { $errors.Add("(hash) $hashFails file(s) could not be read for hashing (locked or access denied)"); Write-Host "Could not hash $hashFails file(s) (locked or access denied)." -ForegroundColor Yellow }
    return @{ root = $rootFull; folders = $folders; files = $files; errors = $errors }
}

function Get-PPAcl($scan) {
    $rows = New-Object System.Collections.Generic.List[object]
    if (-not $IsWin) { return $rows }
    foreach ($fo in $scan.folders) {
        if ($fo.Depth -gt 2 -or $fo.Reparse) { continue }
        $full = if ($fo.Rel) { Join-Path $scan.root ($fo.Rel.Replace('/', '\')) } else { $scan.root }
        try {
            $acl = Get-Acl -LiteralPath $full -ErrorAction Stop
            foreach ($a in $acl.Access) {
                $rows.Add([pscustomobject]@{ Folder = $(if ($fo.Rel) { $fo.Rel } else { '(root)' }); Depth = $fo.Depth; Identity = [string]$a.IdentityReference; Rights = [string]$a.FileSystemRights; Type = [string]$a.AccessControlType; Inherited = $a.IsInherited; Owner = $acl.Owner })
            }
        } catch { $rows.Add([pscustomobject]@{ Folder = $fo.Rel; Depth = $fo.Depth; Identity = '(error)'; Rights = $_.Exception.Message; Type = ''; Inherited = ''; Owner = '' }) }
    }
    return $rows
}

# =====================================================================================
# Capture file (write / read)
# =====================================================================================
function Write-PPCapture($cap, [string] $file) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    $w = New-Object System.IO.StreamWriter($file, $false, $enc)
    try {
        $w.Write('{"tool":' + (Get-JStr $ToolName) + ',"version":' + (Get-JStr $ToolVersion))
        $w.Write(',"meta":' + (ConvertTo-PPJson $cap.meta))
        $w.Write(',"device":' + (ConvertTo-PPJson @($cap.device)))
        $w.Write(',"errors":' + (ConvertTo-PPJson @($cap.errors)))
        $w.Write(',"acl":' + (ConvertTo-PPJson @($cap.acl)))
        $w.Write(",`n" + '"folders":[')
        $first = $true
        foreach ($fo in $cap.folders) {
            if (-not $first) { $w.Write(',') }; $first = $false
            $w.Write("`n" + '{"p":' + (Get-JStr $fo.Rel) + ',"n":' + (Get-JStr $fo.Name) + ',"pa":' + $fo.Parent + ',"d":' + $fo.Depth +
                ',"c":' + (Get-JStr $fo.Created.ToString('s')) + ',"m":' + (Get-JStr $fo.Modified.ToString('s')) +
                ',"df":' + $fo.DirectFiles + ',"sd":' + $fo.SubDirs + ',"rp":' + $(if ($fo.Reparse) { '1' } else { '0' }) +
                ',"er":' + $(if ($fo.Error) { Get-JStr $fo.Error } else { 'null' }) + '}')
        }
        $w.Write("`n],`n" + '"files":[')
        $first = $true
        foreach ($f in $cap.files) {
            if (-not $first) { $w.Write(',') }; $first = $false
            $w.Write("`n" + '{"p":' + (Get-JStr $f.Rel) + ',"n":' + (Get-JStr $f.Name) + ',"d":' + $f.Dir + ',"s":' + $f.Size +
                ',"c":' + (Get-JStr $f.Created.ToString('s')) + ',"m":' + (Get-JStr $f.Modified.ToString('s')) + ',"a":' + $f.Attr +
                ',"h":' + $(if ($f.Hash) { Get-JStr $f.Hash } else { 'null' }) + '}')
        }
        $w.Write("`n]}`n")
    } finally { $w.Dispose() }
}

function Read-PPCapture([string] $file) {
    Write-Host "Reading capture $file ..." -ForegroundColor Cyan
    $text = [IO.File]::ReadAllText($file)
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $j = $text | ConvertFrom-Json -AsHashtable
    } else {
        Add-Type -AssemblyName System.Web.Extensions
        $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $ser.MaxJsonLength = [int]::MaxValue
        $ser.RecursionLimit = 100
        $j = $ser.DeserializeObject($text)
    }
    $folders = New-Object 'System.Collections.Generic.List[PPFolder]'
    $files = New-Object 'System.Collections.Generic.List[PPFile]'
    foreach ($x in $j['folders']) {
        $fo = [PPFolder]::new()
        $fo.Rel = [string]$x['p']; $fo.Name = [string]$x['n']; $fo.Parent = [int]$x['pa']; $fo.Depth = [int]$x['d']
        $fo.Created = [datetime]::Parse([string]$x['c'], $Inv); $fo.Modified = [datetime]::Parse([string]$x['m'], $Inv)
        $fo.DirectFiles = [int]$x['df']; $fo.SubDirs = [int]$x['sd']; $fo.Reparse = ([int]$x['rp'] -eq 1); $fo.Error = [string]$x['er']
        $folders.Add($fo)
    }
    foreach ($x in $j['files']) {
        $f = [PPFile]::new()
        $f.Rel = [string]$x['p']; $f.Name = [string]$x['n']; $f.Dir = [int]$x['d']; $f.Size = [long]$x['s']
        $f.Ext = [IO.Path]::GetExtension($f.Name).ToLowerInvariant()
        $f.Created = [datetime]::Parse([string]$x['c'], $Inv); $f.Modified = [datetime]::Parse([string]$x['m'], $Inv)
        $f.Attr = [int]$x['a']; $f.Hash = [string]$x['h']
        $files.Add($f)
    }
    $meta = [ordered]@{}
    foreach ($k in $j['meta'].Keys) { $meta[$k] = $j['meta'][$k] }
    $acl = @(foreach ($a in @($j['acl'])) { if ($a) { New-Object psobject -Property $a } })
    return @{ meta = $meta; device = @($j['device']); errors = @($j['errors']); acl = $acl; folders = $folders; files = $files }
}

# =====================================================================================
# Analysis
# =====================================================================================
$IssueDefs = [ordered]@{
    TRAILING_DOT_SPACE  = @('High', 'Name ends with a dot or space. Blob names cannot end a segment with a dot, and Windows tools struggle with these.', 'Rename before migrating.')
    CONTROL_CHAR        = @('High', 'Name contains control characters. Not allowed in Blob names.', 'Rename before migrating.')
    BLOB_NAME_TOO_LONG  = @('High', 'Blob name (path in the container) is over 1,024 characters.', 'Shorten folder or file names.')
    TOO_MANY_SEGMENTS   = @('High', 'More than 254 path segments (Blob limit without hierarchical namespace).', 'Flatten the folder structure.')
    URL_TOO_LONG        = @('High', 'Planned web link is over 2,048 characters.', 'Shorten folder or file names.')
    CASE_COLLISION      = @('High', 'Another item in the same folder differs only by upper/lower case. Blob links are case-sensitive.', 'Rename one of them.')
    ACCESS_DENIED       = @('High', 'Folder could not be read during the scan, so its contents are missing from this report.', 'Rescan with an account that has access.')
    URL_RESERVED        = @('Medium', 'Name contains characters that break web links unless encoded (# ? % & + ; = @ , and similar).', 'The tool encodes them; avoid them in new names.')
    NON_ASCII           = @('Medium', 'Name contains non-ASCII characters (accents, smart quotes, symbols).', 'Check the link opens on an iPad/browser; rename if not.')
    LEADING_SPACE       = @('Medium', 'Name starts with a space.', 'Rename before migrating.')
    LONG_PATH           = @('Medium', 'Full path is over 260 characters. Many Windows tools fail on these.', 'Shorten folder or file names.')
    DUP_NAME            = @('Medium', 'The same file name exists in more than one folder. Matching by file name alone is ambiguous.', 'Match on folder + name, or rename.')
    BAD_DATE            = @('Medium', 'Modified date is before 1980 or in the future.', 'Ignore for date stats; check the file if it matters.')
    REPARSE_POINT       = @('Medium', 'Junction or symbolic link. Not followed by the scan.', 'Decide if its target needs migrating separately.')
    LIKELY_DUPLICATE    = @('Low', 'Same name and size as a file in another folder (probably a copy).', 'Review before migrating to save space.')
    DUP_CONTENT         = @('Low', 'Same content (MD5) as another file.', 'Review before migrating to save space.')
    SPACE               = @('Info', 'Name contains spaces. Fine when encoded (%20), but hand-typed links break.', 'No action needed if links are generated.')
    JUNK                = @('Info', 'System or temporary file (Thumbs.db, desktop.ini, ~$ lock files, .tmp, .DS_Store).', 'Exclude from the migration.')
    ZERO_BYTE           = @('Info', 'File is empty (0 bytes).', 'Review; often safe to skip.')
    CLOUD_ONLY          = @('Info', 'OneDrive cloud-only placeholder (not downloaded on this PC). Size and dates come from metadata.', 'Copying it downloads it first; plan bandwidth.')
    EMPTY_FOLDER        = @('Info', 'Folder has no files and no subfolders.', 'Review; often safe to skip.')
}

function Get-NameIssues([string] $name) {
    $l = New-Object System.Collections.Generic.List[string]
    if ($name.EndsWith('.') -or $name.EndsWith(' ')) { $l.Add('TRAILING_DOT_SPACE') }
    if ($name -match '[\x00-\x1f\x7f]') { $l.Add('CONTROL_CHAR') }
    if ($name -match '[#%?&+;=@,\[\]{}^`~!$''"<>|*]') { $l.Add('URL_RESERVED') }
    if ($name -match '[^\x00-\x7e]') { $l.Add('NON_ASCII') }
    if ($name.StartsWith(' ')) { $l.Add('LEADING_SPACE') }
    if ($name.Contains(' ')) { $l.Add('SPACE') }
    return ,$l
}

function Get-PPAnalysis($cap, [string] $mrpCsv, [string] $blobBase) {
    $files = $cap.files; $folders = $cap.folders; $meta = $cap.meta
    $now = [datetime]::Parse([string]$meta.scanStarted, $Inv)
    $rootLen = [int]$meta.rootLength
    $d90 = $now.AddDays(-90); $d365 = $now.AddDays(-365); $min = [datetime]'1980-01-01'; $max = $now.AddDays(1)
    $urlBaseLen = if ($blobBase) { $blobBase.TrimEnd('/').Length + 1 } else { 60 }
    $junkRe = '^(~\$.*|thumbs\.db|desktop\.ini|\.ds_store|~.*\.tmp|.*\.tmp)$'

    $totBytes = 0L; $cloud = 0; $hidden = 0; $system = 0; $zero = 0; $bad = 0; $copiedIn = 0; $junk = 0
    $oldM = $null; $newM = $null; $oldC = $null; $newC = $null
    $m90 = 0; $m365 = 0; $c90 = 0; $c365 = 0
    $over = @{ 200 = 0; 240 = 0; 256 = 0; 260 = 0 }
    $ext = @{}; $years = @{}; $months = @{}; $weekday = New-Object int[] 7; $hours = New-Object int[] 24
    $buckets = [ordered]@{ 'Under 100 KB' = @(0, 0L); '100 KB - 1 MB' = @(0, 0L); '1 - 10 MB' = @(0, 0L); '10 - 100 MB' = @(0, 0L); '100 MB - 1 GB' = @(0, 0L); '1 GB and over' = @(0, 0L) }
    $depthHist = @{}
    $nameCount = @{}; $nameSize = @{}; $hashCount = @{}
    $maxNameLen = 0; $maxPathLen = 0; $maxBlobLen = 0; $maxUrlLen = 0

    foreach ($fo in $folders) { $fo.RecBytes = 0; $fo.RecFiles = 0; $fo.Newest = [datetime]::MinValue; $fo.Pdf = 0; $fo.Ard = 0 }

    # pass 1: counts
    foreach ($f in $files) {
        $k = $f.Name.ToLowerInvariant()
        $nameCount[$k] = 1 + [int]$nameCount[$k]
        $ks = $k + '|' + $f.Size
        $nameSize[$ks] = 1 + [int]$nameSize[$ks]
        if ($f.Hash) { $hashCount[$f.Hash] = 1 + [int]$hashCount[$f.Hash] }
    }
    $caseSets = @{}
    foreach ($f in $files) {
        $k = [string]$f.Dir + '|' + $f.Name.ToLowerInvariant(); $caseSets[$k] = 1 + [int]$caseSets[$k]
    }
    foreach ($fo in $folders) {
        if ($fo.Parent -ge 0) { $k = [string]$fo.Parent + '|' + $fo.Name.ToLowerInvariant(); $caseSets[$k] = 1 + [int]$caseSets[$k] }
    }

    # pass 2: per file
    foreach ($f in $files) {
        $issues = Get-NameIssues $f.Name
        $totBytes += $f.Size
        $e = if ($f.Ext) { $f.Ext } else { '(none)' }
        if (-not $ext.ContainsKey($e)) { $ext[$e] = @(0, 0L) }
        $ext[$e][0]++; $ext[$e][1] += $f.Size
        if ($f.Attr -band $CloudMask) { $cloud++; $issues.Add('CLOUD_ONLY') }
        if ($f.Attr -band 0x2) { $hidden++ }
        if ($f.Attr -band 0x4) { $system++ }
        if ($f.Size -eq 0) { $zero++; $issues.Add('ZERO_BYTE') }
        if ($f.Name -match $junkRe) { $junk++; $issues.Add('JUNK') }
        $m = $f.Modified; $c = $f.Created
        if ($m -lt $min -or $m -gt $max) { $bad++; $issues.Add('BAD_DATE') }
        else {
            if (-not $oldM -or $m -lt $oldM) { $oldM = $m }
            if (-not $newM -or $m -gt $newM) { $newM = $m }
            $y = $m.Year; $years[$y] = 1 + [int]$years[$y]
            $ym = $m.ToString('yyyy-MM'); $months[$ym] = 1 + [int]$months[$ym]
            if ($m -ge $d90) { $m90++ }
            if ($m -ge $d365) { $m365++; $weekday[[int]$m.DayOfWeek]++; $hours[$m.Hour]++ }
        }
        if ($c -ge $min -and $c -le $max) {
            if (-not $oldC -or $c -lt $oldC) { $oldC = $c }
            if (-not $newC -or $c -gt $newC) { $newC = $c }
            if ($c -ge $d90) { $c90++ }
            if ($c -ge $d365) { $c365++ }
        }
        if ($c -gt $m.AddDays(1)) { $copiedIn++ }
        $b = $f.Size
        $bk = if ($b -lt 100KB) { 'Under 100 KB' } elseif ($b -lt 1MB) { '100 KB - 1 MB' } elseif ($b -lt 10MB) { '1 - 10 MB' } elseif ($b -lt 100MB) { '10 - 100 MB' } elseif ($b -lt 1GB) { '100 MB - 1 GB' } else { '1 GB and over' }
        $buckets[$bk][0]++; $buckets[$bk][1] += $b
        $fo = $folders[$f.Dir]
        $depthHist[$fo.Depth] = 1 + [int]$depthHist[$fo.Depth]
        $pathLen = $rootLen + 1 + $f.Rel.Length
        foreach ($t in 200, 240, 256, 260) { if ($pathLen -gt $t) { $over[$t]++ } }
        if ($pathLen -gt 260) { $issues.Add('LONG_PATH') }
        if ($f.Name.Length -gt $maxNameLen) { $maxNameLen = $f.Name.Length }
        if ($pathLen -gt $maxPathLen) { $maxPathLen = $pathLen }
        if ($f.Rel.Length -gt $maxBlobLen) { $maxBlobLen = $f.Rel.Length }
        if ($f.Rel.Length -gt 1024) { $issues.Add('BLOB_NAME_TOO_LONG') }
        if (($fo.Depth + 1) -gt 254) { $issues.Add('TOO_MANY_SEGMENTS') }
        $urlLen = $urlBaseLen + (Get-PPBlobUrl '' $f.Rel).Length
        if ($urlLen -gt $maxUrlLen) { $maxUrlLen = $urlLen }
        if ($urlLen -gt 2048) { $issues.Add('URL_TOO_LONG') }
        $lk = $f.Name.ToLowerInvariant()
        if ([int]$caseSets[[string]$f.Dir + '|' + $lk] -gt 1) { $issues.Add('CASE_COLLISION') }
        if (-not ($f.Name -match $junkRe)) {
            if ([int]$nameCount[$lk] -gt 1) { $issues.Add('DUP_NAME') }
            if ([int]$nameSize[$lk + '|' + $f.Size] -gt 1) { $issues.Add('LIKELY_DUPLICATE') }
        }
        if ($f.Hash -and [int]$hashCount[$f.Hash] -gt 1) { $issues.Add('DUP_CONTENT') }
        $f.Issues = ($issues -join ',')
        if ($f.Ext -eq '.pdf') { $fo.Pdf++ } elseif ($f.Ext -eq '.ard') { $fo.Ard++ }
        # roll up into folder chain
        $fi = $f.Dir
        while ($fi -ge 0) {
            $x = $folders[$fi]; $x.RecBytes += $f.Size; $x.RecFiles++
            if ($m -le $max -and $m -gt $x.Newest) { $x.Newest = $m }
            $fi = $x.Parent
        }
    }

    # per folder issues
    $empty = 0; $reparse = 0; $denied = 0; $maxDepth = 0
    foreach ($fo in $folders) {
        $issues = if ($fo.Parent -ge 0) { Get-NameIssues $fo.Name } else { New-Object System.Collections.Generic.List[string] }
        if ($fo.Parent -ge 0 -and [int]$caseSets[[string]$fo.Parent + '|' + $fo.Name.ToLowerInvariant()] -gt 1) { $issues.Add('CASE_COLLISION') }
        if ($fo.Reparse) { $reparse++; $issues.Add('REPARSE_POINT') }
        if ($fo.Error) { $denied++; $issues.Add('ACCESS_DENIED') }
        if (-not $fo.Reparse -and -not $fo.Error -and $fo.DirectFiles -eq 0 -and $fo.SubDirs -eq 0) { $empty++; $issues.Add('EMPTY_FOLDER') }
        if (($rootLen + 1 + $fo.Rel.Length) -gt 260) { $issues.Add('LONG_PATH') }
        if ($fo.Depth -gt $maxDepth) { $maxDepth = $fo.Depth }
        $fo.Issues = ($issues -join ',')
    }

    # issue counts
    $issueCounts = [ordered]@{}
    foreach ($k in $IssueDefs.Keys) { $issueCounts[$k] = 0 }
    foreach ($f in $files) { if ($f.Issues) { foreach ($c in $f.Issues.Split(',')) { $issueCounts[$c]++ } } }
    foreach ($fo in $folders) { if ($fo.Issues) { foreach ($c in $fo.Issues.Split(',')) { $issueCounts[$c]++ } } }

    # rates
    $spanDays = if ($oldM -and $newM) { [math]::Max(1, ($newM - $oldM).TotalDays) } else { 1 }
    $nGood = $files.Count - $bad
    $rates = [ordered]@{
        PerDay_AllTime   = [math]::Round($nGood / $spanDays, 2)
        PerMonth_AllTime = [math]::Round($nGood / $spanDays * 30.44, 1)
        PerYear_AllTime  = [math]::Round($nGood / $spanDays * 365.25, 0)
        PerDay_Last90    = [math]::Round($m90 / 90, 2)
        PerMonth_Last90  = [math]::Round($m90 / 90 * 30.44, 1)
        PerYear_Last365  = $m365
        PerWeek_Last90   = [math]::Round($m90 / 90 * 7, 1)
    }

    # drawing folders
    $draw = [ordered]@{ HasPdf = 0; MultiplePdfs = 0; ArdOnly = 0; NoPdfNoArd = 0; SinglePdfNameMatchesFolder = 0; SinglePdfNameDiffers = 0 }
    $pdfByDir = @{}
    foreach ($f in $files) { if ($f.Ext -eq '.pdf') { if (-not $pdfByDir.ContainsKey($f.Dir)) { $pdfByDir[$f.Dir] = $f.Name } } }
    for ($idx = 0; $idx -lt $folders.Count; $idx++) {
        $fo = $folders[$idx]
        if ($fo.DirectFiles -eq 0) { continue }
        if ($fo.Pdf -gt 1) { $draw.MultiplePdfs++ }
        elseif ($fo.Pdf -eq 1) {
            $draw.HasPdf++
            if ([IO.Path]::GetFileNameWithoutExtension([string]$pdfByDir[$idx]) -ieq $fo.Name) { $draw.SinglePdfNameMatchesFolder++ } else { $draw.SinglePdfNameDiffers++ }
        }
        elseif ($fo.Ard -gt 0) { $draw.ArdOnly++ }
        else { $draw.NoPdfNoArd++ }
    }

    # patterns
    $fileShapes = @{}; $folderShapes = @{}
    foreach ($f in $files) {
        $s = Get-Shape ([IO.Path]::GetFileNameWithoutExtension($f.Name))
        if (-not $fileShapes.ContainsKey($s)) { $fileShapes[$s] = @(0, (New-Object System.Collections.Generic.List[string])) }
        $fileShapes[$s][0]++; if ($fileShapes[$s][1].Count -lt 3) { $fileShapes[$s][1].Add($f.Name) }
    }
    foreach ($fo in $folders) {
        if ($fo.Parent -lt 0) { continue }
        $s = Get-Shape $fo.Name
        if (-not $folderShapes.ContainsKey($s)) { $folderShapes[$s] = @(0, (New-Object System.Collections.Generic.List[string])) }
        $folderShapes[$s][0]++; if ($folderShapes[$s][1].Count -lt 3) { $folderShapes[$s][1].Add($fo.Name) }
    }
    $toRows = { param($h) @($h.GetEnumerator() | Sort-Object { $_.Value[0] } -Descending | Select-Object -First 50 | ForEach-Object { [pscustomobject]@{ Pattern = $_.Key; Count = $_.Value[0]; Examples = (@($_.Value[1]) -join ' | ') } }) }

    $topLevel = @(for ($i = 0; $i -lt $folders.Count; $i++) { if ($folders[$i].Parent -eq 0) { $folders[$i] } }) | Sort-Object RecBytes -Descending
    $rootFilesCount = $folders[0].DirectFiles

    $mrp = $null
    if ($mrpCsv) { $mrp = Get-PPMrp $mrpCsv $files $folders $blobBase }

    $summary = [ordered]@{
        Client = $meta.client; Project = $meta.project; Ticket = $meta.ticket
        ScanRoot = $meta.root; SyncedFromLibrary = $meta.library; ScanDate = $meta.scanStarted; ScanMinutes = $meta.scanMinutes
        Computer = $meta.computer
        TotalSizeBytes = $totBytes; TotalSize = (Format-Bytes $totBytes)
        TotalFiles = $files.Count; TotalFolders = $folders.Count; EmptyFolders = $empty; MaxDepth = $maxDepth
        AvgFilesPerFolder = [math]::Round($files.Count / [math]::Max(1, $folders.Count), 1)
        FileTypes = $ext.Count
        OldestModified = $(if ($oldM) { $oldM.ToString('yyyy-MM-dd') } else { '' }); NewestModified = $(if ($newM) { $newM.ToString('yyyy-MM-dd') } else { '' })
        OldestCreated = $(if ($oldC) { $oldC.ToString('yyyy-MM-dd') } else { '' }); NewestCreated = $(if ($newC) { $newC.ToString('yyyy-MM-dd') } else { '' })
        FilesPerDay_AllTime = $rates.PerDay_AllTime; FilesPerMonth_AllTime = $rates.PerMonth_AllTime; FilesPerYear_AllTime = $rates.PerYear_AllTime
        FilesPerDay_Last90 = $rates.PerDay_Last90; FilesPerWeek_Last90 = $rates.PerWeek_Last90; FilesPerMonth_Last90 = $rates.PerMonth_Last90; FilesModified_Last365 = $m365
        FilesCreated_Last90 = $c90; FilesCreated_Last365 = $c365; FilesCopiedInWithOlderDate = $copiedIn; BadDates = $bad
        CloudOnlyFiles = $cloud; HiddenFiles = $hidden; SystemFiles = $system; ZeroByteFiles = $zero; JunkFiles = $junk
        ReparsePoints = $reparse; AccessDeniedFolders = $denied; ScanErrors = @($cap.errors).Count
        LongestPathChars = $maxPathLen; LongestNameChars = $maxNameLen; LongestBlobNameChars = $maxBlobLen; LongestPlannedUrlChars = $maxUrlLen
        PathsOver200 = $over[200]; PathsOver240 = $over[240]; PathsOver256 = $over[256]; PathsOver260 = $over[260]
        Folders_HasOnePdf = $draw.HasPdf; Folders_MultiplePdfs = $draw.MultiplePdfs; Folders_ArdOnly = $draw.ArdOnly; Folders_NoPdfNoArd = $draw.NoPdfNoArd
        SinglePdfNameMatchesFolder = $draw.SinglePdfNameMatchesFolder; SinglePdfNameDiffers = $draw.SinglePdfNameDiffers
        HashedFiles = $hashCount.Count
    }
    if ($mrp) { foreach ($k in $mrp.summary.Keys) { $summary['Mrp_' + $k] = $mrp.summary[$k] } }

    return @{
        summary = $summary; issueCounts = $issueCounts; rates = $rates; ext = $ext; years = $years; months = $months
        weekday = $weekday; hours = $hours; buckets = $buckets; depthHist = $depthHist
        filePatterns = (& $toRows $fileShapes); folderPatterns = (& $toRows $folderShapes)
        topLevel = $topLevel; rootFiles = $rootFilesCount; mrp = $mrp; blobBase = $blobBase
    }
}

# =====================================================================================
# MRPeasy link check
# =====================================================================================
function Get-PPMrp([string] $csv, $files, $folders, [string] $blobBase) {
    Write-Host "Checking MRPeasy links in $csv ..." -ForegroundColor Cyan
    $first = Get-Content -LiteralPath $csv -TotalCount 1
    $delim = ','
    $nc = $first.Split(',').Count; $ns = $first.Split(';').Count; $nt = $first.Split("`t").Count
    if ($ns -gt $nc -and $ns -ge $nt) { $delim = ';' } elseif ($nt -gt $nc -and $nt -gt $ns) { $delim = "`t" }
    $rows = @(Import-Csv -LiteralPath $csv -Delimiter $delim)
    $cols = if ($rows.Count) { @($rows[0].PSObject.Properties.Name) } else { @() }
    $linkRe = '^\s*(\\\\|[A-Za-z]:[\\/]|https?://|file:)'
    $linkCol = $null; $best = 0
    foreach ($c in $cols) {
        $n = 0; foreach ($r in $rows) { if ([string]$r.$c -match $linkRe) { $n++ } }
        if ($n -gt $best) { $best = $n; $linkCol = $c }
    }
    $relIdx = @{}; $nameIdx = @{}
    for ($i = 0; $i -lt $files.Count; $i++) {
        $relIdx[$files[$i].Rel.ToLowerInvariant()] = $i
        $k = $files[$i].Name.ToLowerInvariant()
        if (-not $nameIdx.ContainsKey($k)) { $nameIdx[$k] = New-Object System.Collections.Generic.List[int] }
        $nameIdx[$k].Add($i)
    }
    $review = New-Object System.Collections.Generic.List[object]
    $prefixes = @{}
    $matched = @{}
    $rowNum = 0
    foreach ($r in $rows) {
        $rowNum++
        if (-not $linkCol) { break }
        $v = [string]$r.$linkCol
        if ($v -notmatch $linkRe) { continue }
        $ctx = (@($cols | Where-Object { $_ -ne $linkCol } | ForEach-Object { "$_=$($r.$_)" }) -join '; ')
        if ($ctx.Length -gt 300) { $ctx = $ctx.Substring(0, 300) }
        foreach ($link in @($v -split '[\r\n]+' | Where-Object { $_ -match $linkRe } | ForEach-Object { $_.Trim() })) {
            $type = if ($link -match '^\\\\') { 'UNC' } elseif ($link -match '^[A-Za-z]:') { 'DriveLetter' } elseif ($link -match '^file:') { 'FileUrl' } elseif ($link -match 'sharepoint\.com|onedrive|1drv\.ms') { 'SharePoint/OneDrive' } else { 'WebUrl' }
            $norm = $link -replace '^file:/+', ''
            if ($type -ne 'UNC' -and $type -ne 'DriveLetter') { $norm = [uri]::UnescapeDataString(($norm -split '\?')[0]) -replace '^https?://[^/]+', '' }
            $segs = @($norm -split '[\\/]' | Where-Object { $_ -ne '' })
            $hit = -1; $method = ''; $k = 0
            for ($k = [math]::Min($segs.Count, 60); $k -ge 2; $k--) {
                $tail = ($segs[($segs.Count - $k)..($segs.Count - 1)] -join '/').ToLowerInvariant()
                if ($relIdx.ContainsKey($tail)) { $hit = [int]$relIdx[$tail]; $method = 'Path'; break }
            }
            $name = if ($segs.Count) { $segs[-1] } else { '' }
            $status = 'NotFound'
            if ($hit -ge 0) { $status = 'Matched' }
            else {
                $k = 1
                $cands = if ($name -and $nameIdx.ContainsKey($name.ToLowerInvariant())) { @($nameIdx[$name.ToLowerInvariant()]) } else { @() }
                if ($cands.Count -eq 1) { $hit = $cands[0]; $method = 'Name'; $status = 'Matched' }
                elseif ($cands.Count -gt 1) {
                    $parent = if ($segs.Count -ge 2) { $segs[-2] } else { '' }
                    $byParent = @($cands | Where-Object { $folders[$files[$_].Dir].Name -ieq $parent })
                    if ($byParent.Count -eq 1) { $hit = $byParent[0]; $method = 'Folder+Name'; $status = 'Matched'; $k = 2 }
                    else { $status = 'Ambiguous' }
                }
            }
            $caseDiff = $false; $rel = ''; $newUrl = ''
            if ($hit -ge 0) {
                $rel = $files[$hit].Rel
                $relSegs = $rel.Split('/')
                $kk = [math]::Min($k, $relSegs.Count)
                $a = ($segs[($segs.Count - $kk)..($segs.Count - 1)] -join '/')
                $b = ($relSegs[($relSegs.Count - $kk)..($relSegs.Count - 1)] -join '/')
                $caseDiff = ($a -cne $b)
                $newUrl = Get-PPBlobUrl $blobBase $rel
                $matched[$hit] = $true
                $pre = if ($segs.Count -gt $kk) { $segs[0..($segs.Count - $kk - 1)] -join '\' } else { '' }
            } else {
                $pre = if ($segs.Count -gt 2) { $segs[0..($segs.Count - 3)] -join '\' } else { '' }
            }
            $pk = "$type | $pre"
            $prefixes[$pk] = 1 + [int]$prefixes[$pk]
            $review.Add([pscustomobject]@{
                Row = $rowNum; Context = $ctx; LinkType = $type; OldLink = $link; Status = $status; Method = $method
                CaseDiffers = $caseDiff; MatchedFile = $rel; IsPdf = $(if ($hit -ge 0) { $files[$hit].Ext -eq '.pdf' } else { $null }); NewLink = $newUrl
            })
        }
    }
    # draft update: one row per unique old link, only when all its rows agree on the same file
    $byOld = @{}
    foreach ($x in $review) {
        if ($x.Status -ne 'Matched') { continue }
        if (-not $byOld.ContainsKey($x.OldLink)) { $byOld[$x.OldLink] = $x.NewLink } elseif ($byOld[$x.OldLink] -ne $x.NewLink) { $byOld[$x.OldLink] = '<conflict>' }
    }
    $update = @($byOld.GetEnumerator() | Where-Object { $_.Value -ne '<conflict>' } | Sort-Object Key | ForEach-Object { [pscustomobject]@{ old = $_.Key; new = $_.Value } })
    $unlinked = @(for ($i = 0; $i -lt $files.Count; $i++) { if ($files[$i].Ext -eq '.pdf' -and -not $matched.ContainsKey($i)) { $files[$i].Rel } })
    $summary = [ordered]@{
        Rows = $rows.Count; LinkColumn = $linkCol; Links = $review.Count
        Matched = @($review | Where-Object Status -eq 'Matched').Count
        MatchedByPath = @($review | Where-Object Method -eq 'Path').Count
        MatchedByName = @($review | Where-Object Method -eq 'Name').Count
        MatchedByFolderAndName = @($review | Where-Object Method -eq 'Folder+Name').Count
        Ambiguous = @($review | Where-Object Status -eq 'Ambiguous').Count
        NotFound = @($review | Where-Object Status -eq 'NotFound').Count
        CaseDiffers = @($review | Where-Object CaseDiffers -eq $true).Count
        LinksToNonPdf = @($review | Where-Object { $_.IsPdf -eq $false }).Count
        UniqueOldLinks = $byOld.Count; UpdateRows = $update.Count
        PdfsWithNoLink = $unlinked.Count
        BlobBaseUrl = $blobBase
    }
    $pre = @($prefixes.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { [pscustomobject]@{ TypeAndPrefix = $_.Key; Links = $_.Value } })
    return @{ summary = $summary; review = $review; update = $update; prefixes = $pre; unlinked = $unlinked }
}

# =====================================================================================
# Outputs
# =====================================================================================
function Out-PPCsv($rows, [string] $dir, [string] $name) {
    $p = Join-Path $dir $name
    $arr = New-Object System.Collections.ArrayList
    foreach ($r in $rows) { if ($null -ne $r) { [void]$arr.Add($r) } }
    if ($arr.Count) { $arr | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $p } else { Set-Content -Path $p -Value '' }
}

function Write-PPOutputs($cap, $an, [string] $outDir) {
    $files = $cap.files; $folders = $cap.folders
    [IO.File]::WriteAllText((Join-Path $outDir 'summary.json'), (ConvertTo-PPJson ([ordered]@{ summary = $an.summary; issues = $an.issueCounts; rates = $an.rates })))
    @($cap.device) | Set-Content -Path (Join-Path $outDir 'device-info.txt')
    if (@($cap.errors).Count) { @($cap.errors) | Set-Content -Path (Join-Path $outDir 'scan-errors.txt') }
    Out-PPCsv ($an.ext.GetEnumerator() | Sort-Object { $_.Value[0] } -Descending | ForEach-Object { [pscustomobject]@{ Extension = $_.Key; Files = $_.Value[0]; Bytes = $_.Value[1]; Size = (Format-Bytes $_.Value[1]) } }) $outDir 'extensions.csv'
    Out-PPCsv ($files | Sort-Object Size -Descending | Select-Object -First 100 @{n = 'Size'; e = { Format-Bytes $_.Size } }, @{n = 'Bytes'; e = { $_.Size } }, @{n = 'Path'; e = { $_.Rel } }) $outDir 'largest-files.csv'
    Out-PPCsv ($folders | Sort-Object RecBytes -Descending | Select-Object -First 100 @{n = 'Size'; e = { Format-Bytes $_.RecBytes } }, @{n = 'Bytes'; e = { $_.RecBytes } }, @{n = 'Files'; e = { $_.RecFiles } }, @{n = 'Folder'; e = { if ($_.Rel) { $_.Rel } else { '(root)' } } }) $outDir 'largest-folders.csv'
    Out-PPCsv ($folders | Sort-Object DirectFiles -Descending | Select-Object -First 100 @{n = 'FilesDirectlyInFolder'; e = { $_.DirectFiles } }, @{n = 'Folder'; e = { if ($_.Rel) { $_.Rel } else { '(root)' } } }) $outDir 'busiest-folders.csv'
    Out-PPCsv ($an.months.GetEnumerator() | Sort-Object Key | ForEach-Object { [pscustomobject]@{ Month = $_.Key; FilesModified = $_.Value } }) $outDir 'monthly-activity.csv'
    Out-PPCsv ($an.topLevel | ForEach-Object { [pscustomobject]@{ Folder = $_.Name; Files = $_.RecFiles; Size = (Format-Bytes $_.RecBytes); Bytes = $_.RecBytes; Newest = $(if ($_.Newest -gt [datetime]::MinValue) { $_.Newest.ToString('yyyy-MM-dd') } else { '' }) } }) $outDir 'top-level-folders.csv'
    Out-PPCsv ($an.filePatterns) $outDir 'file-name-patterns.csv'
    Out-PPCsv ($an.folderPatterns) $outDir 'folder-name-patterns.csv'
    Out-PPCsv ($files | Sort-Object { $_.Rel.Length } -Descending | Select-Object -First 200 @{n = 'FullPathChars'; e = { [int]$cap.meta.rootLength + 1 + $_.Rel.Length } }, @{n = 'NameChars'; e = { $_.Name.Length } }, @{n = 'Path'; e = { $_.Rel } }) $outDir 'longest-paths.csv'
    $issueRows = New-Object System.Collections.Generic.List[object]
    foreach ($fo in $folders) { if ($fo.Issues) { foreach ($c in $fo.Issues.Split(',')) { if ($IssueDefs[$c][0] -ne 'Info' -or $c -eq 'EMPTY_FOLDER') { $issueRows.Add([pscustomobject]@{ Severity = $IssueDefs[$c][0]; Code = $c; Type = 'Folder'; Path = $(if ($fo.Rel) { $fo.Rel } else { '(root)' }) }) } } } }
    foreach ($f in $files) { if ($f.Issues) { foreach ($c in $f.Issues.Split(',')) { if ($c -ne 'SPACE' -and $c -ne 'CLOUD_ONLY') { $issueRows.Add([pscustomobject]@{ Severity = $IssueDefs[$c][0]; Code = $c; Type = 'File'; Path = $f.Rel }) } } } }
    Out-PPCsv $issueRows $outDir 'issues.csv'
    if (@($cap.acl).Count) { Out-PPCsv $cap.acl $outDir 'permissions-top2.csv' }
    if ($an.mrp) {
        Out-PPCsv $an.mrp.review $outDir 'mrp-link-review.csv'
        Out-PPCsv $an.mrp.update $outDir 'mrp-link-update-DRAFT.csv'
        Out-PPCsv ($an.mrp.unlinked | ForEach-Object { [pscustomobject]@{ Path = $_ } }) $outDir 'mrp-unlinked-pdfs.csv'
        Out-PPCsv $an.mrp.prefixes $outDir 'mrp-link-prefixes.csv'
    }
    Write-PPHtml $cap $an (Join-Path $outDir 'report.html')
}

function Write-PPHtml($cap, $an, [string] $file) {
    $files = $cap.files; $folders = $cap.folders
    $maxEmbed = 200000
    $truncated = $files.Count -gt $maxEmbed
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('{"meta":' + (ConvertTo-PPJson $cap.meta))
    [void]$sb.Append(',"summary":' + (ConvertTo-PPJson $an.summary))
    [void]$sb.Append(',"rates":' + (ConvertTo-PPJson $an.rates))
    $defs = [ordered]@{}; foreach ($k in $IssueDefs.Keys) { $defs[$k] = @($IssueDefs[$k]) }
    [void]$sb.Append(',"issueDefs":' + (ConvertTo-PPJson $defs))
    [void]$sb.Append(',"issueCounts":' + (ConvertTo-PPJson $an.issueCounts))
    [void]$sb.Append(',"ext":' + (ConvertTo-PPJson @($an.ext.GetEnumerator() | Sort-Object { $_.Value[0] } -Descending | ForEach-Object { , @($_.Key, $_.Value[0], $_.Value[1]) })))
    [void]$sb.Append(',"years":' + (ConvertTo-PPJson @($an.years.GetEnumerator() | Sort-Object Key | ForEach-Object { , @([string]$_.Key, $_.Value) })))
    [void]$sb.Append(',"months":' + (ConvertTo-PPJson @($an.months.GetEnumerator() | Sort-Object Key | ForEach-Object { , @($_.Key, $_.Value) })))
    [void]$sb.Append(',"weekday":' + (ConvertTo-PPJson @($an.weekday)) + ',"hours":' + (ConvertTo-PPJson @($an.hours)))
    [void]$sb.Append(',"buckets":' + (ConvertTo-PPJson @($an.buckets.GetEnumerator() | ForEach-Object { , @($_.Key, $_.Value[0], $_.Value[1]) })))
    [void]$sb.Append(',"depth":' + (ConvertTo-PPJson @($an.depthHist.GetEnumerator() | Sort-Object Key | ForEach-Object { , @($_.Key, $_.Value) })))
    [void]$sb.Append(',"filePatterns":' + (ConvertTo-PPJson @($an.filePatterns | ForEach-Object { , @($_.Pattern, $_.Count, $_.Examples) })))
    [void]$sb.Append(',"folderPatterns":' + (ConvertTo-PPJson @($an.folderPatterns | ForEach-Object { , @($_.Pattern, $_.Count, $_.Examples) })))
    [void]$sb.Append(',"device":' + (ConvertTo-PPJson @($cap.device)))
    [void]$sb.Append(',"errors":' + (ConvertTo-PPJson @(@($cap.errors) | Select-Object -First 500)))
    [void]$sb.Append(',"truncated":' + $(if ($truncated) { 'true' } else { 'false' }))
    # folders: [rel, name, parent, depth, directFiles, recFiles, recBytes, newest, issues, subdirs]
    [void]$sb.Append(',"folders":[')
    for ($i = 0; $i -lt $folders.Count; $i++) {
        $fo = $folders[$i]
        if ($i) { [void]$sb.Append(',') }
        $nw = if ($fo.Newest -gt [datetime]::MinValue) { $fo.Newest.ToString('yyyy-MM-dd') } else { '' }
        [void]$sb.Append('[' + (Get-JStr $fo.Rel) + ',' + (Get-JStr $fo.Name) + ',' + $fo.Parent + ',' + $fo.Depth + ',' + $fo.DirectFiles + ',' + $fo.RecFiles + ',' + $fo.RecBytes + ',"' + $nw + '",' + (Get-JStr $fo.Issues) + ',' + $fo.SubDirs + ']')
    }
    # files: [dir, name, size, modified, issues, cloud]
    [void]$sb.Append('],"files":[')
    $firstF = $true
    foreach ($f in $files) {
        if ($truncated -and -not $f.Issues) { continue }
        if (-not $firstF) { [void]$sb.Append(',') }; $firstF = $false
        [void]$sb.Append('[' + $f.Dir + ',' + (Get-JStr $f.Name) + ',' + $f.Size + ',"' + $f.Modified.ToString('yyyy-MM-dd') + '",' + (Get-JStr $f.Issues) + ',' + $(if ($f.Attr -band $CloudMask) { '1' } else { '0' }) + ']')
    }
    [void]$sb.Append(']')
    if ($an.mrp) {
        $m = $an.mrp
        [void]$sb.Append(',"mrp":{"summary":' + (ConvertTo-PPJson $m.summary))
        [void]$sb.Append(',"prefixes":' + (ConvertTo-PPJson @($m.prefixes | ForEach-Object { , @($_.TypeAndPrefix, $_.Links) })))
        [void]$sb.Append(',"review":' + (ConvertTo-PPJson @($m.review | ForEach-Object { , @($_.Row, $_.Context, $_.LinkType, $_.OldLink, $_.Status, $_.Method, $_.CaseDiffers, $_.MatchedFile, $_.NewLink) })))
        [void]$sb.Append(',"update":' + (ConvertTo-PPJson @($m.update | ForEach-Object { , @($_.old, $_.new) })))
        [void]$sb.Append(',"unlinked":' + (ConvertTo-PPJson @($m.unlinked | Select-Object -First 5000)) + '}')
    } else { [void]$sb.Append(',"mrp":null') }
    [void]$sb.Append('}')
    # Where this report lives (shown under the header so the reader knows where to find it)
    $savedDir = Split-Path -Parent $file
    $savedZip = if ($NoZip) { '(no zip created)' } else { "$savedDir.zip" }
    $savedPc = if ($IsWin) { $env:COMPUTERNAME } else { [Environment]::MachineName }
    $html = $script:HtmlTemplate.Replace('__TITLE__', [Net.WebUtility]::HtmlEncode("$($cap.meta.client) - $ToolName")).Replace('__VERSION__', $ToolVersion).Replace('__LOGO__', $LogoBase64)
    $html = $html.Replace('__SAVEDFOLDER__', [Net.WebUtility]::HtmlEncode($savedDir)).Replace('__SAVEDZIP__', [Net.WebUtility]::HtmlEncode($savedZip)).Replace('__SAVEDPC__', [Net.WebUtility]::HtmlEncode($savedPc))
    $mail = Get-PPMailInfo $cap.meta $(if ($NoZip) { '' } else { "$savedDir.zip" })
    $folderUrl = ''
    # file:/// link to the folder that holds the report (and its zip); built by hand so drive
    # letters, spaces and \\server\share paths all come out right
    $fp = Split-Path -Parent $savedDir
    $pre = 'file:///'
    if ($fp.StartsWith('\\')) { $pre = 'file://'; $fp = $fp.Substring(2) }
    $segs = @($fp.Replace('\', '/').Trim('/') -split '/' | Where-Object { $_ } | ForEach-Object { [Uri]::EscapeDataString($_) })
    if ($segs.Count) { $folderUrl = $pre + ($segs -join '/').Replace('%3A', ':') + '/' }
    $html = $html.Replace('__FOLDERURL__', [Net.WebUtility]::HtmlEncode($folderUrl)).Replace('__MAILTO__', [Net.WebUtility]::HtmlEncode($mail.Mailto)).Replace('__GMAIL__', [Net.WebUtility]::HtmlEncode($mail.Gmail))
    # Data last: the JSON may contain text that looks like a placeholder
    $html = $html.Replace('__DATA__', $sb.ToString())
    [IO.File]::WriteAllText($file, $html, (New-Object System.Text.UTF8Encoding($false)))
}

function Write-PPConsole($an) {
    $s = $an.summary
    $line = '=' * 64
    function Write-PPHead([string] $t) { Write-Host ''; Write-Host $t -ForegroundColor Cyan; Write-Host ('-' * $t.Length) -ForegroundColor DarkGray }
    function Write-PPRow([string] $k, $v) { Write-Host ('  {0,-34} {1}' -f $k, $v) }
    Write-Host ''; Write-Host $line -ForegroundColor DarkGray
    Write-Host ("  $ToolName v$ToolVersion  |  $($s.Client)" + $(if ($s.Ticket) { "  |  Ticket #$($s.Ticket)" } else { '' })) -ForegroundColor White
    Write-Host "  $($s.Project)" -ForegroundColor Gray
    Write-Host $line -ForegroundColor DarkGray
    Write-PPHead 'Scan'
    Write-PPRow 'Path' $s.ScanRoot; if ($s.SyncedFromLibrary) { Write-PPRow 'Synced from' $s.SyncedFromLibrary }
    Write-PPRow 'Scanned' "$($s.ScanDate) on $($s.Computer) ($($s.ScanMinutes) min)"
    Write-PPHead 'Totals'
    Write-PPRow 'Total size' $s.TotalSize; Write-PPRow 'Files' ('{0:N0}' -f $s.TotalFiles); Write-PPRow 'Folders' ('{0:N0}' -f $s.TotalFolders)
    Write-PPRow 'Empty folders' ('{0:N0}' -f $s.EmptyFolders); Write-PPRow 'Deepest folder level' $s.MaxDepth; Write-PPRow 'Average files per folder' $s.AvgFilesPerFolder
    Write-PPRow 'Cloud-only (not downloaded)' ('{0:N0}' -f $s.CloudOnlyFiles)
    Write-PPHead 'Files by type (top 10)'
    $an.ext.GetEnumerator() | Sort-Object { $_.Value[0] } -Descending | Select-Object -First 10 | ForEach-Object { Write-PPRow $_.Key ('{0,10:N0} files  {1,12}' -f $_.Value[0], (Format-Bytes $_.Value[1])) }
    Write-PPHead 'Dates and growth'
    Write-PPRow 'Oldest / newest modified' "$($s.OldestModified)  /  $($s.NewestModified)"
    Write-PPRow 'Oldest / newest created' "$($s.OldestCreated)  /  $($s.NewestCreated)"
    Write-PPRow 'Average files (all time)' "$($s.FilesPerDay_AllTime) / day,  $($s.FilesPerMonth_AllTime) / month,  $($s.FilesPerYear_AllTime) / year"
    Write-PPRow 'Average files (last 90 days)' "$($s.FilesPerDay_Last90) / day,  $($s.FilesPerWeek_Last90) / week,  $($s.FilesPerMonth_Last90) / month"
    Write-PPRow 'Files modified last 365 days' ('{0:N0}' -f $s.FilesModified_Last365)
    Write-PPRow 'Copied in with older dates' ('{0:N0}' -f $s.FilesCopiedInWithOlderDate)
    Write-PPHead 'Paths and names'
    Write-PPRow 'Longest full path' "$($s.LongestPathChars) chars"; Write-PPRow 'Longest file name' "$($s.LongestNameChars) chars"
    Write-PPRow 'Paths over 240 / 260 chars' "$($s.PathsOver240)  /  $($s.PathsOver260)"
    Write-PPRow 'Longest planned web link' "$($s.LongestPlannedUrlChars) chars"
    Write-PPHead 'Migration readiness (issues found)'
    foreach ($k in $an.issueCounts.Keys) {
        $n = $an.issueCounts[$k]; if (-not $n) { continue }
        $sev = $IssueDefs[$k][0]
        $col = switch ($sev) { 'High' { 'Red' } 'Medium' { 'Yellow' } 'Low' { 'Gray' } default { 'DarkGray' } }
        Write-Host ('  {0,-8} {1,-22} {2,10:N0}' -f $sev, $k, $n) -ForegroundColor $col
    }
    if ($an.mrp) {
        $m = $an.mrp.summary
        Write-PPHead 'MRPeasy link check'
        Write-PPRow 'Links in export' ('{0:N0}  (column: {1})' -f $m.Links, $m.LinkColumn)
        Write-PPRow 'Matched to a file' ('{0:N0}  (path {1}, name {2}, folder+name {3})' -f $m.Matched, $m.MatchedByPath, $m.MatchedByName, $m.MatchedByFolderAndName)
        Write-PPRow 'Ambiguous / not found' ('{0:N0}  /  {1:N0}' -f $m.Ambiguous, $m.NotFound)
        Write-PPRow 'Case differs' ('{0:N0}' -f $m.CaseDiffers)
        Write-PPRow 'Rows in DRAFT update CSV' ('{0:N0}' -f $m.UpdateRows)
        Write-PPRow 'PDFs with no MRPeasy link' ('{0:N0}' -f $m.PdfsWithNoLink)
    }
    Write-Host ''
}

# =====================================================================================
# Start screen (Windows Forms)
# =====================================================================================
function Show-PPStartForm($settings) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $black = [System.Drawing.ColorTranslator]::FromHtml('#1a1a1a')
    $text = [System.Drawing.ColorTranslator]::FromHtml('#28251d')
    $muted = [System.Drawing.ColorTranslator]::FromHtml('#7a7974')
    $line = [System.Drawing.ColorTranslator]::FromHtml('#d4d1ca')
    $foot = [System.Drawing.ColorTranslator]::FromHtml('#f7f6f2')
    $last = $settings.last

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "$ToolName v$ToolVersion - Superior Networks"
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'; $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::White; $form.ForeColor = $text
    $form.Font = New-Object System.Drawing.Font('Arial', 9.5)
    $form.ClientSize = New-Object System.Drawing.Size(600, 560)

    try {
        $ms = New-Object IO.MemoryStream (, [Convert]::FromBase64String($LogoBase64))
        $pic = New-Object System.Windows.Forms.PictureBox
        $pic.Image = [System.Drawing.Image]::FromStream($ms); $pic.SizeMode = 'Zoom'
        $pic.Location = New-Object System.Drawing.Point(16, 10); $pic.Size = New-Object System.Drawing.Size(91, 48)
        $form.Controls.Add($pic)
    } catch {}
    $t1 = New-Object System.Windows.Forms.Label; $t1.Text = $ToolName; $t1.Font = New-Object System.Drawing.Font('Arial', 14, [System.Drawing.FontStyle]::Bold); $t1.Location = New-Object System.Drawing.Point(120, 12); $t1.AutoSize = $true; $form.Controls.Add($t1)
    $t2 = New-Object System.Windows.Forms.Label; $t2.Text = 'File share discovery and migration readiness'; $t2.ForeColor = $muted; $t2.Location = New-Object System.Drawing.Point(122, 40); $t2.AutoSize = $true; $form.Controls.Add($t2)
    $rule = New-Object System.Windows.Forms.Panel; $rule.BackColor = $black; $rule.Location = New-Object System.Drawing.Point(0, 66); $rule.Size = New-Object System.Drawing.Size(600, 3); $form.Controls.Add($rule)

    $script:ppY = 84
    $addRow = {
        param([string] $label, [string] $value, [string] $browse)
        $l = New-Object System.Windows.Forms.Label; $l.Text = $label; $l.Location = New-Object System.Drawing.Point(16, ($script:ppY + 4)); $l.Size = New-Object System.Drawing.Size(150, 20); $form.Controls.Add($l)
        $tb = New-Object System.Windows.Forms.TextBox; $tb.Text = $value; $tb.Location = New-Object System.Drawing.Point(170, $script:ppY)
        $tb.Size = New-Object System.Drawing.Size($(if ($browse) { 320 } else { 410 }), 24); $form.Controls.Add($tb)
        if ($browse) {
            $b = New-Object System.Windows.Forms.Button; $b.Text = 'Browse'; $b.Location = New-Object System.Drawing.Point(498, ($script:ppY - 1)); $b.Size = New-Object System.Drawing.Size(82, 26)
            $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderColor = $black; $b.Tag = @{ box = $tb; kind = $browse }
            $b.Add_Click({
                $info = $this.Tag
                if ($info.kind -eq 'folder') {
                    $d = New-Object System.Windows.Forms.FolderBrowserDialog; $d.SelectedPath = $info.box.Text
                    if ($d.ShowDialog() -eq 'OK') { $info.box.Text = $d.SelectedPath }
                } else {
                    $d = New-Object System.Windows.Forms.OpenFileDialog; $d.Filter = 'CSV files (*.csv)|*.csv|All files (*.*)|*.*'
                    if ($d.ShowDialog() -eq 'OK') { $info.box.Text = $d.FileName }
                }
            })
            $form.Controls.Add($b)
        }
        $script:ppY += 34
        return $tb
    }
    $tbClient = & $addRow 'Client name *' ([string]$last.client) ''
    $tbProject = & $addRow 'Project description *' ([string]$last.project) ''
    $tbTicket = & $addRow 'Ticket #' ([string]$last.ticket) ''
    $tbTicket.Width = 120
    $tbPath = & $addRow 'Folder to scan *' ([string]$last.path) 'folder'
    $scanHint = New-Object System.Windows.Forms.Label; $scanHint.ForeColor = $muted; $scanHint.Location = New-Object System.Drawing.Point(170, ($script:ppY - 6)); $scanHint.Size = New-Object System.Drawing.Size(410, 18)
    $scanHint.Text = 'Everything inside this folder is scanned. Files are only read, never changed.'; $form.Controls.Add($scanHint)
    $script:ppY += 18
    $tbReport = & $addRow 'Save report to *' $(if ($last.reportPath) { [string]$last.reportPath } else { $DefaultReportPath }) 'folder'
    $hint = New-Object System.Windows.Forms.Label; $hint.ForeColor = $muted; $hint.Location = New-Object System.Drawing.Point(170, ($script:ppY - 6)); $hint.Size = New-Object System.Drawing.Size(410, 18); $form.Controls.Add($hint)
    $updHint = { $n = (Get-SafeName $tbClient.Text) + $(if ($tbTicket.Text) { '-' + $tbTicket.Text } else { '' }) + '-' + (Get-Date -Format 'yyyyMMdd-HHmm'); $hint.Text = "Saves to $n (folder and .zip)" }
    $tbClient.Add_TextChanged($updHint); $tbTicket.Add_TextChanged($updHint); & $updHint
    $script:ppY += 18

    $chkOpt = New-Object System.Windows.Forms.CheckBox; $chkOpt.Text = 'Show optional checks (MRPeasy links, Blob URL, hashes, permissions)'; $chkOpt.Location = New-Object System.Drawing.Point(16, $script:ppY); $chkOpt.AutoSize = $true; $form.Controls.Add($chkOpt)
    $script:ppY += 28
    $grp = New-Object System.Windows.Forms.Panel; $grp.Location = New-Object System.Drawing.Point(0, $script:ppY); $grp.Size = New-Object System.Drawing.Size(600, 120); $grp.Visible = $false; $form.Controls.Add($grp)
    $optTop = $script:ppY
    $mk = {
        param($ctl, $x, $y, $w, $h) $ctl.Location = New-Object System.Drawing.Point($x, $y); $ctl.Size = New-Object System.Drawing.Size($w, $h); $grp.Controls.Add($ctl); $ctl
    }
    $l1 = New-Object System.Windows.Forms.Label; $l1.Text = 'MRPeasy links CSV'; [void](& $mk $l1 16 4 150 20)
    $tbMrp = New-Object System.Windows.Forms.TextBox; $tbMrp.Text = [string]$last.mrpLinks; [void](& $mk $tbMrp 170 0 320 24)
    $bMrp = New-Object System.Windows.Forms.Button; $bMrp.Text = 'Browse'; $bMrp.FlatStyle = 'Flat'; $bMrp.FlatAppearance.BorderColor = $black; [void](& $mk $bMrp 498 -1 82 26)
    $bMrp.Add_Click({ $d = New-Object System.Windows.Forms.OpenFileDialog; $d.Filter = 'CSV files (*.csv)|*.csv|All files (*.*)|*.*'; if ($d.ShowDialog() -eq 'OK') { $tbMrp.Text = $d.FileName } })
    $l2 = New-Object System.Windows.Forms.Label; $l2.Text = 'Blob base URL'; [void](& $mk $l2 16 38 150 20)
    $tbBlob = New-Object System.Windows.Forms.TextBox; $tbBlob.Text = [string]$last.blobBaseUrl; [void](& $mk $tbBlob 170 34 410 24)
    $chkHash = New-Object System.Windows.Forms.CheckBox; $chkHash.Text = 'Hash local files (MD5, finds true duplicates, slower)'; [void](& $mk $chkHash 170 66 410 22)
    $chkAcl = New-Object System.Windows.Forms.CheckBox; $chkAcl.Text = 'Permissions for the top two folder levels'; [void](& $mk $chkAcl 170 90 410 22)

    $low = New-Object System.Windows.Forms.Panel; $low.Location = New-Object System.Drawing.Point(0, $optTop); $low.Size = New-Object System.Drawing.Size(600, 260); $form.Controls.Add($low)
    $err = New-Object System.Windows.Forms.Label; $err.ForeColor = [System.Drawing.Color]::FromArgb(163, 45, 45); $err.Location = New-Object System.Drawing.Point(16, 0); $err.Size = New-Object System.Drawing.Size(564, 36); $low.Controls.Add($err)
    $bScan = New-Object System.Windows.Forms.Button; $bScan.Text = 'Scan'; $bScan.BackColor = $black; $bScan.ForeColor = [System.Drawing.Color]::White; $bScan.FlatStyle = 'Flat'; $bScan.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $bScan.Location = New-Object System.Drawing.Point(16, 40); $bScan.Size = New-Object System.Drawing.Size(120, 34); $low.Controls.Add($bScan)
    $bOpen = New-Object System.Windows.Forms.Button; $bOpen.Text = 'Open previous report'; $bOpen.FlatStyle = 'Flat'; $bOpen.FlatAppearance.BorderColor = $black
    $bOpen.Location = New-Object System.Drawing.Point(146, 40); $bOpen.Size = New-Object System.Drawing.Size(180, 34); $low.Controls.Add($bOpen)
    $lr = New-Object System.Windows.Forms.Label; $lr.Text = 'Recent reports (double-click to open)'; $lr.ForeColor = $muted; $lr.Location = New-Object System.Drawing.Point(16, 86); $lr.AutoSize = $true; $low.Controls.Add($lr)
    $lst = New-Object System.Windows.Forms.ListBox; $lst.Location = New-Object System.Drawing.Point(16, 106); $lst.Size = New-Object System.Drawing.Size(564, 96); $lst.BorderStyle = 'FixedSingle'; $low.Controls.Add($lst)
    foreach ($r in @($settings.recent)) { [void]$lst.Items.Add($r.label) }
    $ft = New-Object System.Windows.Forms.Label; $ft.Text = "  $ToolName v$ToolVersion  -  Superior Networks LLC  -  (937) 985-2480"; $ft.BackColor = $foot; $ft.ForeColor = $muted
    $ft.Font = New-Object System.Drawing.Font('Arial', 8); $ft.TextAlign = 'MiddleLeft'; $ft.Location = New-Object System.Drawing.Point(0, 214); $ft.Size = New-Object System.Drawing.Size(600, 30); $low.Controls.Add($ft)

    $layout = {
        if ($chkOpt.Checked) { $grp.Visible = $true; $low.Top = $optTop + 124 } else { $grp.Visible = $false; $low.Top = $optTop }
        $form.ClientSize = New-Object System.Drawing.Size(600, ($low.Top + 244))
    }
    $chkOpt.Add_CheckedChanged($layout)
    if ($last.mrpLinks -or $last.blobBaseUrl) { $chkOpt.Checked = $true }
    & $layout

    $collect = {
        @{ Client = $tbClient.Text.Trim(); Project = $tbProject.Text.Trim(); Ticket = $tbTicket.Text.Trim(); Path = $tbPath.Text.Trim(); ReportPath = $tbReport.Text.Trim()
           MrpLinks = $(if ($chkOpt.Checked) { $tbMrp.Text.Trim() } else { '' }); BlobBaseUrl = $(if ($chkOpt.Checked) { $tbBlob.Text.Trim() } else { '' })
           HashLocal = ($chkOpt.Checked -and $chkHash.Checked); IncludeAcl = ($chkOpt.Checked -and $chkAcl.Checked) }
    }
    $bScan.Add_Click({
        $v = & $collect
        $problems = Test-PPInputs $v
        if ($problems.Count) { $err.Text = ($problems -join '  ') ; return }
        $v.Action = 'scan'; $form.Tag = $v; $form.Close()
    })
    $bOpen.Add_Click({
        $d = New-Object System.Windows.Forms.OpenFileDialog
        $d.Filter = 'Report or capture (report.html, capture.json)|report.html;capture.json|All files (*.*)|*.*'
        if ($d.ShowDialog() -ne 'OK') { return }
        if ($d.FileName -like '*.json') {
            $v = & $collect
            if ($v.MrpLinks -and -not (Test-Path -LiteralPath $v.MrpLinks)) { $err.Text = "MRPeasy links CSV not found: $($v.MrpLinks)"; return }
            $v.Action = 'rebuild'; $v.Capture = $d.FileName; $form.Tag = $v; $form.Close()
        } else { Open-PPFile $d.FileName }
    })
    $lst.Add_DoubleClick({
        $i = $lst.SelectedIndex
        if ($i -ge 0) {
            $p = @($settings.recent)[$i].path
            if (Test-Path -LiteralPath $p) { Open-PPFile $p } else { $err.Text = "Report not found: $p" }
        }
    })
    [void]$form.ShowDialog()
    return $form.Tag
}

# =====================================================================================
# HTML report template (brand shell: snap-platform-standards section 4)
# =====================================================================================
$script:HtmlTemplate = @'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>__TITLE__</title>
<style>
:root{--bg:#f0f0f0;--card:#fff;--line:#d4d1ca;--ink:#28251d;--muted:#7a7974;--label:#f7f6f2;--black:#1a1a1a;--high:#a32d2d;--med:#8a5a00;--low:#5f5e5a}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 Arial,Helvetica,sans-serif}
.wrap{max-width:960px;margin:16px auto;padding:0 16px}.card{background:var(--card);border:1px solid var(--line);border-radius:8px;overflow:hidden}
header{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;padding:14px 20px;border-bottom:3px solid var(--black)}
header .brand{display:flex;align-items:center;gap:14px}header img{height:56px;width:auto}header h1{margin:0;font-size:20px}header .tag{color:var(--muted);font-size:12px}
header .who{text-align:right;font-size:13px}header .who b{font-size:15px}
nav{display:flex;gap:4px;flex-wrap:wrap;padding:8px 20px;border-bottom:1px solid var(--line)}
nav button{font:13px Arial;border:0;background:none;padding:6px 12px;border-radius:4px;cursor:pointer;color:var(--ink)}nav button.on{background:var(--black);color:#fff}
main{padding:16px 20px}section{display:none}section.on{display:block}
h2{font-size:17px;margin:20px 0 8px}h2:first-child{margin-top:0}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:8px}
.stat{border:1px solid var(--line);border-radius:8px;padding:10px}.stat .k{font-size:12px;color:var(--muted)}.stat .v{font-size:20px;font-weight:bold}.stat .s{font-size:11px;color:var(--muted)}
.tw{overflow-x:auto}table{width:100%;border-collapse:collapse;font-size:13px}td,th{border:1px solid var(--line);padding:5px 8px;text-align:left;vertical-align:top}
th,td.l{background:var(--label);font-weight:normal}td.n,th.n{text-align:right;white-space:nowrap}
.note{background:var(--label);border:1px solid var(--line);border-radius:8px;padding:10px 12px;font-size:13px;margin:8px 0}
.badge{display:inline-block;font-size:11px;border:1px solid var(--line);background:var(--label);border-radius:4px;padding:0 5px;margin:1px 2px 1px 0}
.sev-High{color:var(--high)}.sev-Medium{color:var(--med)}.sev-Low{color:var(--low)}.sev-Info{color:var(--muted)}
.btn{display:inline-block;background:var(--black);color:#fff;border:0;border-radius:4px;padding:8px 14px;font:13px Arial;cursor:pointer;margin:4px 6px 4px 0}
.btn.alt{background:#fff;color:var(--black);border:1px solid var(--black)}
input[type=text],select{font:13px Arial;padding:6px 8px;border:1px solid var(--line);border-radius:4px;max-width:100%}
.tree{font:12px/1.9 Consolas,Menlo,monospace}.tree .row{white-space:nowrap;cursor:default}.tree .tg{display:inline-block;width:16px;cursor:pointer;color:var(--muted)}
.tree .m{color:var(--muted)}.tree .f{padding-left:16px}
svg text{font:11px Arial;fill:var(--muted)}.bars rect{fill:var(--ink)}
.saved{padding:10px 20px;background:var(--label);border-bottom:1px solid var(--line);font-size:13px;word-break:break-all}
.saved code{font:13px Consolas,Menlo,monospace}.saved .btn{padding:3px 10px;font-size:12px;margin:0 0 0 8px;text-decoration:none}
.saved .mail{margin-top:8px}.mbtn{display:inline-flex;align-items:center;gap:6px;border:1px solid var(--line);background:#fff;border-radius:4px;padding:4px 10px;margin:2px 6px 2px 0;color:var(--ink);text-decoration:none;font-size:13px}
.mbtn:hover{border-color:var(--ink)}
footer{background:var(--label);color:var(--muted);font-size:11px;padding:10px 20px;border-top:1px solid var(--line);display:flex;justify-content:space-between;flex-wrap:wrap;gap:6px}
.muted{color:var(--muted)}.small{font-size:12px}
</style></head><body>
<div class="wrap"><div class="card">
<header><div class="brand"><img alt="Superior Networks" src="data:image/png;base64,__LOGO__"><div><h1>Project Planner</h1><div class="tag">File share discovery and migration readiness</div></div></div>
<div class="who" id="who"></div></header>
<div class="saved"><b>Report saved to:</b> <code id="savedPath">__SAVEDFOLDER__</code><button class="btn alt" onclick="var t=document.getElementById('savedPath').textContent;if(navigator.clipboard){navigator.clipboard.writeText(t);this.textContent='Copied'}">Copy path</button><a class="btn alt" href="__FOLDERURL__" title="Shows the Reports folder. Browsers show it as a file list; for File Explorer, use Copy path and paste it into the Explorer address bar.">Open folder</a><br><span class="muted">Zip to send back: __SAVEDZIP__ &middot; on computer __SAVEDPC__</span>
<div class="mail">Email the zip to Superior Networks:
<a class="mbtn" href="__MAILTO__" title="Opens a new email in your email app (Outlook)"><svg width="18" height="18" viewBox="0 0 20 20" aria-hidden="true"><rect x="1" y="3" width="18" height="14" rx="2" fill="#0a64c8"/><path d="M3 6l7 5 7-5" stroke="#fff" stroke-width="2" fill="none"/></svg>Outlook</a><a class="mbtn" href="__GMAIL__" target="_blank" rel="noopener" title="Opens a new Gmail message in your browser"><svg width="18" height="18" viewBox="0 0 20 20" aria-hidden="true"><rect x="1" y="3" width="18" height="14" rx="2" fill="#fff" stroke="#c5221f"/><path d="M3 5l7 6 7-6" stroke="#ea4335" stroke-width="2.5" fill="none"/></svg>Gmail</a><span class="muted small">Attach the .zip before sending: browsers can't attach files for you.</span></div></div>
<nav id="nav"></nav>
<main>
<section id="t-summary"></section>
<section id="t-folders"></section>
<section id="t-files"></section>
<section id="t-issues"></section>
<section id="t-mrp"></section>
<section id="t-help"></section>
</main>
<footer><span>Project Planner v__VERSION__ &middot; Superior Networks LLC &middot; (937) 985-2480</span><span id="gen"></span></footer>
</div></div>
<script id="pp-data" type="application/json">__DATA__</script>
<script>
(function(){
const D=JSON.parse(document.getElementById('pp-data').textContent);
const S=D.summary, M=D.meta;
const esc=s=>String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const n=x=>Number(x||0).toLocaleString();
const B=b=>{b=Number(b||0);const u=['B','KB','MB','GB','TB'];let i=0;while(b>=1024&&i<4){b/=1024;i++}return (i?b.toFixed(i>2?2:1):b)+' '+u[i]};
const sevOrder={High:0,Medium:1,Low:2,Info:3};
const T=(head,rows,num)=>'<div class="tw"><table><tr>'+head.map((h,i)=>'<th'+(num&&num.includes(i)?' class="n"':'')+'>'+esc(h)+'</th>').join('')+'</tr>'+rows.map(r=>'<tr>'+r.map((c,i)=>'<td'+(num&&num.includes(i)?' class="n"':'')+'>'+c+'</td>').join('')+'</tr>').join('')+'</table></div>';
const stat=(k,v,s)=>'<div class="stat"><div class="k">'+esc(k)+'</div><div class="v">'+v+'</div>'+(s?'<div class="s">'+s+'</div>':'')+'</div>';
function bars(pairs,h){h=h||120;if(!pairs.length)return '<p class="muted small">No data.</p>';const w=Math.max(8,Math.min(48,Math.floor(900/pairs.length)-4));const W=pairs.length*(w+4)+10;const mx=Math.max(...pairs.map(p=>p[1]))||1;
 let s='<div class="tw"><svg width="'+Math.max(W,300)+'" height="'+(h+34)+'" role="img" aria-label="bar chart"><g class="bars">';
 pairs.forEach((p,i)=>{const bh=Math.round(p[1]/mx*h);s+='<rect x="'+(5+i*(w+4))+'" y="'+(h-bh+4)+'" width="'+w+'" height="'+bh+'"><title>'+esc(p[0])+': '+n(p[1])+'</title></rect>'});
 s+='</g>';const step=Math.ceil(pairs.length/16);pairs.forEach((p,i)=>{if(i%step===0)s+='<text x="'+(5+i*(w+4)+w/2)+'" y="'+(h+20)+'" text-anchor="middle">'+esc(p[0])+'</text>'});return s+'</svg></div>';}
const issueBadges=s=>s?s.split(',').map(c=>'<span class="badge sev-'+(D.issueDefs[c]||['Info'])[0]+'">'+c+'</span>').join(''):'';
function fpath(fi){const r=D.folders[fi][0];return r};
// header
document.getElementById('who').innerHTML='<b>'+esc(M.client)+'</b><br>'+esc(M.project)+(M.ticket?'<br>Ticket #'+esc(M.ticket):'');
document.getElementById('gen').textContent='Scanned '+(M.scanStarted||'').replace('T',' ')+' on '+(M.computer||'')+' \u00b7 names and metadata only, no file contents';
const tabs=[['summary','Summary'],['folders','Folders'],['files','Files'],['issues','Issues'],['mrp','MRPeasy links'],['help','Help Guide']];
const nav=document.getElementById('nav');
tabs.forEach(([k,l],i)=>{const b=document.createElement('button');b.textContent=l;b.onclick=()=>show(k);b.id='b-'+k;nav.appendChild(b)});
const done={};
function show(k){tabs.forEach(([x])=>{document.getElementById('t-'+x).classList.toggle('on',x===k);document.getElementById('b-'+x).classList.toggle('on',x===k)});if(!done[k]){done[k]=1;R[k]()}try{localStorage.setItem('pp-tab',k)}catch(e){}}
const R={};
R.summary=function(){
 const ic=D.issueCounts;const sev={High:0,Medium:0,Low:0};Object.keys(ic).forEach(k=>{const s=(D.issueDefs[k]||[])[0];if(s in sev)sev[s]+=ic[k]});
 let h='<h2>Scan</h2>'+T(['Item','Value'],[['Client',esc(M.client)],['Project',esc(M.project)],['Ticket',esc(M.ticket||'')],['Folder scanned',esc(M.root)],['Synced from',esc(M.library||'(not a synced library)')],['Scanned',esc((M.scanStarted||'').replace('T',' '))+' on '+esc(M.computer)+', '+esc(M.scanMinutes)+' min']].map(r=>['<span class="muted">'+r[0]+'</span>',r[1]]));
 if(D.truncated)h+='<div class="note">This share has more than 200,000 files, so only files with issues are embedded in this report. The full list is in capture.json.</div>';
 h+='<h2>Totals</h2><div class="grid">'+stat('Total size',esc(S.TotalSize))+stat('Files',n(S.TotalFiles))+stat('Folders',n(S.TotalFolders),n(S.EmptyFolders)+' empty, '+S.MaxDepth+' levels deep')+stat('Oldest / newest',esc(S.OldestModified)+'<br>'+esc(S.NewestModified),'modified dates')+stat('Files per day, last 90 days',esc(S.FilesPerDay_Last90),esc(S.FilesPerWeek_Last90)+' / week, '+esc(S.FilesPerMonth_Last90)+' / month')+stat('Files per year, all time',n(S.FilesPerYear_AllTime),esc(S.FilesPerMonth_AllTime)+' / month, '+esc(S.FilesPerDay_AllTime)+' / day')+stat('Cloud-only files',n(S.CloudOnlyFiles),'not downloaded on the scan PC')+stat('Problems to fix',n(sev.High)+' high','plus '+n(sev.Medium)+' medium, '+n(sev.Low)+' low')+'</div>';
 const ms=D.months.slice(-36);h+='<h2>Files modified per month (last 36 months)</h2>'+bars(ms.map(m=>[m[0].slice(2),m[1]]));
 h+='<h2>Files per year</h2>'+bars(D.years.map(y=>[y[0],y[1]]),90);
 const wd=['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];h+='<h2>When files change (last 365 days)</h2><div class="grid" style="grid-template-columns:repeat(auto-fit,minmax(280px,1fr))"><div>'+bars(D.weekday.map((v,i)=>[wd[i],v]),80)+'</div><div>'+bars(D.hours.map((v,i)=>[String(i),v]),80)+'</div></div>';
 h+='<h2>File types</h2>'+T(['Type','Files','Size','% of files'],D.ext.slice(0,30).map(e=>[esc(e[0]),n(e[1]),B(e[2]),(e[1]/Math.max(1,S.TotalFiles)*100).toFixed(1)+'%']),[1,2,3]);
 if(D.ext.length>30)h+='<p class="muted small">'+(D.ext.length-30)+' more types in extensions.csv</p>';
 h+='<h2>File sizes</h2>'+T(['Size','Files','Total'],D.buckets.map(b=>[esc(b[0]),n(b[1]),B(b[2])]),[1,2]);
 const top=D.folders.map((f,i)=>[f,i]).filter(x=>x[0][2]===0).sort((a,b)=>b[0][6]-a[0][6]);
 h+='<h2>Top-level folders</h2>'+T(['Folder','Files','Size','Newest'],top.map(x=>[esc(x[0][1]),n(x[0][5]),B(x[0][6]),esc(x[0][7])]),[1,2]);
 const lf=D.folders.map(f=>f).sort((a,b)=>b[6]-a[6]).slice(1,16);h+='<h2>Largest folders</h2>'+T(['Folder','Files','Size'],lf.map(f=>[esc(f[0]||'(root)'),n(f[5]),B(f[6])]),[1,2]);
 const bf=D.folders.map(f=>f).sort((a,b)=>b[4]-a[4]).slice(0,10);h+='<h2>Folders with the most files directly inside</h2>'+T(['Folder','Files'],bf.map(f=>[esc(f[0]||'(root)'),n(f[4])]),[1]);
 const big=D.files.map(f=>f).sort((a,b)=>b[2]-a[2]).slice(0,25);h+='<h2>Largest files</h2>'+T(['File','Size','Modified'],big.map(f=>[esc((fpath(f[0])?fpath(f[0])+'/':'')+f[1]),B(f[2]),esc(f[3])]),[1]);
 h+='<h2>Paths and names</h2>'+T(['Measure','Value'],[['Longest full path',S.LongestPathChars+' chars'],['Longest file name',S.LongestNameChars+' chars'],['Paths over 200 / 240 / 256 / 260 chars',n(S.PathsOver200)+' / '+n(S.PathsOver240)+' / '+n(S.PathsOver256)+' / '+n(S.PathsOver260)],['Longest Blob name',S.LongestBlobNameChars+' chars (limit 1,024)'],['Longest planned web link',S.LongestPlannedUrlChars+' chars (keep under 2,048)'],['Files copied in with older dates',n(S.FilesCopiedInWithOlderDate)],['Hidden / system / zero-byte / junk files',n(S.HiddenFiles)+' / '+n(S.SystemFiles)+' / '+n(S.ZeroByteFiles)+' / '+n(S.JunkFiles)],['Reparse points / unreadable folders',n(S.ReparsePoints)+' / '+n(S.AccessDeniedFolders)]].map(r=>['<span class="muted">'+r[0]+'</span>',esc(r[1])]));
 h+='<h2>Folder depth (files per level)</h2>'+bars(D.depth.map(d=>['L'+d[0],d[1]]),80);
 h+='<h2>Drawing folders (PDF / ArtiosCAD)</h2>'+T(['Folders that','Count'],[['Have one PDF',n(S.Folders_HasOnePdf)],['Have several PDFs (revisions)',n(S.Folders_MultiplePdfs)],['Have only .ard (ArtiosCAD)',n(S.Folders_ArdOnly)],['Have files but no PDF or .ard',n(S.Folders_NoPdfNoArd)],['Single PDF named like the folder',n(S.SinglePdfNameMatchesFolder)],['Single PDF named differently',n(S.SinglePdfNameDiffers)]],[1]);
 h+='<h2>Name patterns</h2><p class="muted small">Digits become 9, letter runs become A. Example: "12372 Rev B" becomes "99999 A A".</p><div class="grid" style="grid-template-columns:repeat(auto-fit,minmax(300px,1fr))"><div>'+T(['File name pattern','Files','Examples'],D.filePatterns.slice(0,15).map(p=>[esc(p[0]),n(p[1]),'<span class="small">'+esc(p[2])+'</span>']),[1])+'</div><div>'+T(['Folder name pattern','Folders','Examples'],D.folderPatterns.slice(0,15).map(p=>[esc(p[0]),n(p[1]),'<span class="small">'+esc(p[2])+'</span>']),[1])+'</div></div>';
 h+='<h2>This PC</h2><pre class="note" style="white-space:pre-wrap;font-size:12px">'+esc(D.device.join('\n'))+'</pre>';
 if(D.errors.length)h+='<h2>Scan errors</h2><pre class="note" style="white-space:pre-wrap;font-size:12px">'+esc(D.errors.join('\n'))+'</pre>';
 document.getElementById('t-summary').innerHTML=h;
};
// folder tree
let kids=null,fileKids=null;
function buildKids(){kids={};fileKids={};D.folders.forEach((f,i)=>{if(f[2]>=0)(kids[f[2]]=kids[f[2]]||[]).push(i)});Object.values(kids).forEach(a=>a.sort((x,y)=>D.folders[x][1].localeCompare(D.folders[y][1])));D.files.forEach((f,i)=>{(fileKids[f[0]]=fileKids[f[0]]||[]).push(i)})}
function folderRow(i){const f=D.folders[i];const has=(kids[i]||[]).length||(fileKids[i]||[]).length;return '<div class="row" style="padding-left:'+(f[3]*16)+'px"><span class="tg" data-i="'+i+'">'+(has?'+':'')+'</span>'+esc(f[1])+' <span class="m">'+B(f[6])+', '+n(f[5])+' files'+(f[7]?', newest '+f[7]:'')+'</span> '+issueBadges(f[8])+'</div><div id="k'+i+'"></div>'}
R.folders=function(){buildKids();const el=document.getElementById('t-folders');el.innerHTML='<h2>Folder explorer</h2><p class="muted small">Click + to open a folder. Sizes and counts include everything inside.</p><div class="tree" id="tree">'+folderRow(0)+'</div>';
 el.addEventListener('click',e=>{const t=e.target.closest('.tg');if(!t||!t.textContent)return;const i=+t.dataset.i;const box=document.getElementById('k'+i);if(t.textContent==='-'){box.innerHTML='';t.textContent='+';return}
  t.textContent='-';const d=D.folders[i][3]+1;let h=(kids[i]||[]).map(folderRow).join('');const fk=(fileKids[i]||[]);h+=fk.slice(0,2000).map(j=>{const f=D.files[j];return '<div class="row f" style="padding-left:'+(d*16)+'px">'+esc(f[1])+' <span class="m">'+B(f[2])+', '+f[3]+(f[5]?', cloud-only':'')+'</span> '+issueBadges(f[4])+'</div>'}).join('');if(fk.length>2000)h+='<div class="row m" style="padding-left:'+(d*16)+'px">... '+n(fk.length-2000)+' more files (see capture.json)</div>';box.innerHTML=h});
 document.querySelector('#tree .tg').click();};
// files search
R.files=function(){const el=document.getElementById('t-files');const exts=D.ext.map(e=>e[0]);
 el.innerHTML='<h2>Find files</h2><p><input type="text" id="q" placeholder="Search path or name, e.g. 12372" style="width:320px"> <select id="qe"><option value="">All types</option>'+exts.map(x=>'<option>'+esc(x)+'</option>').join('')+'</select> <span id="qn" class="muted small"></span></p><div id="qr"></div>';
 const run=()=>{const q=document.getElementById('q').value.toLowerCase();const e=document.getElementById('qe').value;let out=[],cnt=0;
  for(let i=0;i<D.files.length;i++){const f=D.files[i];const p=(fpath(f[0])?fpath(f[0])+'/':'')+f[1];if(e&&!(e==='(none)'?f[1].indexOf('.')<0:p.toLowerCase().endsWith(e)))continue;if(q&&p.toLowerCase().indexOf(q)<0)continue;cnt++;if(out.length<500)out.push([esc(p),B(f[2]),esc(f[3]),issueBadges(f[4])])}
  document.getElementById('qn').textContent=n(cnt)+' match'+(cnt===1?'':'es')+(cnt>500?' (showing 500)':'');document.getElementById('qr').innerHTML=T(['Path','Size','Modified','Issues'],out,[1])};
 let tm;document.getElementById('q').oninput=()=>{clearTimeout(tm);tm=setTimeout(run,200)};document.getElementById('qe').onchange=run;run();};
// issues
R.issues=function(){const el=document.getElementById('t-issues');const ks=Object.keys(D.issueCounts).filter(k=>D.issueCounts[k]>0).sort((a,b)=>sevOrder[D.issueDefs[a][0]]-sevOrder[D.issueDefs[b][0]]||D.issueCounts[b]-D.issueCounts[a]);
 let h='<h2>Migration readiness</h2>'+T(['Severity','Issue','Count','What it means','What to do'],ks.map(k=>{const d=D.issueDefs[k];return ['<span class="sev-'+d[0]+'">'+d[0]+'</span>','<a href="#" data-k="'+k+'">'+k+'</a>',n(D.issueCounts[k]),esc(d[1]),esc(d[2])]}),[2]);
 if(!ks.length)h+='<p>No issues found.</p>';h+='<h2 id="ih">Pick an issue above to list the affected items</h2><div id="il"></div>';el.innerHTML=h;
 el.addEventListener('click',e=>{const a=e.target.closest('a[data-k]');if(!a)return;e.preventDefault();const k=a.dataset.k;const rows=[];
  D.folders.forEach(f=>{if(f[8]&&f[8].split(',').includes(k)&&rows.length<3000)rows.push(['Folder',esc(f[0]||'(root)')])});
  D.files.forEach(f=>{if(f[4]&&f[4].split(',').includes(k)&&rows.length<3000)rows.push(['File',esc((fpath(f[0])?fpath(f[0])+'/':'')+f[1])])});
  document.getElementById('ih').textContent=k+': '+n(D.issueCounts[k])+' item(s)'+(D.issueCounts[k]>3000?' (showing 3,000; full list in issues.csv)':'');document.getElementById('il').innerHTML=T(['Type','Path'],rows);document.getElementById('ih').scrollIntoView()});};
// mrp
function dl(name,rows){const csv=rows.map(r=>r.map(c=>{c=String(c==null?'':c);return /[",\n]/.test(c)?'"'+c.replace(/"/g,'""')+'"':c}).join(',')).join('\r\n');const a=document.createElement('a');a.href=URL.createObjectURL(new Blob(['\ufeff'+csv],{type:'text/csv'}));a.download=name;document.body.appendChild(a);a.click();a.remove()}
R.mrp=function(){const el=document.getElementById('t-mrp');const m=D.mrp;
 if(!m){el.innerHTML='<h2>MRPeasy link check</h2><div class="note">No MRPeasy export was included in this scan.<br><br>To add it: in MRPeasy go to Settings &gt; Database Maintenance &gt; Export and update file links, click Export to CSV, then open Project Planner, choose Open previous report, pick this report&#39;s capture.json, and fill in MRPeasy links CSV and Blob base URL under optional checks. The report is rebuilt without rescanning.</div>';return}
 const s=m.summary;let h='<h2>MRPeasy link check</h2><div class="grid">'+stat('Links in export',n(s.Links),'column: '+esc(s.LinkColumn))+stat('Matched to a file',n(s.Matched),'path '+n(s.MatchedByPath)+', name '+n(s.MatchedByName)+', folder+name '+n(s.MatchedByFolderAndName))+stat('Ambiguous',n(s.Ambiguous),'same name in several folders')+stat('File not found',n(s.NotFound))+stat('Case differs',n(s.CaseDiffers),'Blob links are case-sensitive')+stat('PDFs with no link',n(s.PdfsWithNoLink))+'</div>';
 h+='<div class="note"><b>DRAFT.</b> The update file has '+n(s.UpdateRows)+' rows (old link, new link) for matched links only'+(s.BlobBaseUrl?', using '+esc(s.BlobBaseUrl):'. No Blob base URL was given, so new links are relative paths')+'. Before uploading in MRPeasy (Settings &gt; Database Maintenance &gt; Export and update file links): download an MRPeasy backup, review this list, and pilot about 10 items.</div>';
 h+='<button class="btn" id="d1">Download DRAFT update CSV (old, new)</button><button class="btn alt" id="d2">Download full review CSV</button>';
 h+='<h2>Where the old links point</h2>'+T(['Link type and prefix','Links'],m.prefixes.map(p=>[esc(p[0]),n(p[1])]),[1]);
 h+='<h2>Review</h2><p><select id="ms"><option value="">All statuses</option><option>Matched</option><option>Ambiguous</option><option>NotFound</option><option value="case">Case differs</option></select> <span id="mn" class="muted small"></span></p><div id="mr"></div>';
 h+='<h2>PDFs with no MRPeasy link</h2><p class="muted small">'+n(s.PdfsWithNoLink)+' PDFs on the share are not referenced by any link'+(m.unlinked.length<s.PdfsWithNoLink?' (first 5,000 shown)':'')+'.</p>'+T(['Path'],m.unlinked.slice(0,300).map(p=>[esc(p)]))+(m.unlinked.length>300?'<p class="muted small">More in mrp-unlinked-pdfs.csv</p>':'');
 el.innerHTML=h;
 const run=()=>{const v=document.getElementById('ms').value;const rows=m.review.filter(r=>!v||(v==='case'?r[6]:r[4]===v));document.getElementById('mn').textContent=n(rows.length)+' rows'+(rows.length>1000?' (showing 1,000)':'');
  document.getElementById('mr').innerHTML=T(['Row','Old link','Status','Matched file','New link','Context'],rows.slice(0,1000).map(r=>[r[0],esc(r[3]),esc(r[4])+(r[5]?' <span class="muted small">('+esc(r[5])+')</span>':'')+(r[6]?' <span class="badge sev-High">case</span>':''),esc(r[7]),'<span class="small">'+esc(r[8])+'</span>','<span class="small muted">'+esc(r[1])+'</span>']),[0])};
 document.getElementById('ms').onchange=run;run();
 document.getElementById('d1').onclick=()=>dl('mrp-link-update-DRAFT.csv',[['old','new']].concat(m.update));
 document.getElementById('d2').onclick=()=>dl('mrp-link-review.csv',[['Row','Context','LinkType','OldLink','Status','Method','CaseDiffers','MatchedFile','NewLink']].concat(m.review));};
// help
R.help=function(){document.getElementById('t-help').innerHTML='<h2>Help Guide</h2><p class="small muted">Project Planner v__VERSION__ &middot; guide updated 2026-10-06</p>'+
 '<h2>What this report is</h2><p>A complete picture of one folder or file share, captured on '+esc((M.scanStarted||'').slice(0,10))+'. It is used to plan a migration: how big it is, how fast it grows, and what will break when files move to Azure or get web links.</p>'+
 '<h2>How it was made</h2><p>Project Planner read the names, sizes, dates and attributes of every folder and file inside the folder that was scanned. It did not open, change, move or download any file. OneDrive cloud-only files stayed cloud-only.</p>'+
 '<h2>Tabs</h2><ul><li><b>Summary:</b> totals, file types, dates and growth, sizes, top-level and largest folders, path lengths, name patterns, and details of the PC that ran the scan.</li><li><b>Folders:</b> the full folder tree. Click + to open a folder and see its files.</li><li><b>Files:</b> search every file by name or path, filter by type.</li><li><b>Issues:</b> everything that could break a migration or a web link, by severity. Click an issue to list the items.</li><li><b>MRPeasy links:</b> if an MRPeasy link export was included, how each existing link maps to a file and the draft old/new link file.</li></ul>'+
 '<h2>Severity</h2><ul><li><span class="sev-High">High</span>: will fail or break links. Fix before migrating.</li><li><span class="sev-Medium">Medium</span>: likely to cause problems. Review.</li><li><span class="sev-Low">Low</span>: worth a look (duplicates).</li><li><span class="sev-Info">Info</span>: for awareness.</li></ul>'+
 '<h2>Growth numbers</h2><p>"Files per day" uses modified dates. Last-90-days figures show the current pace; all-time figures average over the span from the oldest to the newest file. Files "copied in with older dates" were created on this share after their last change, so their modified date is older than their arrival.</p>'+
 '<h2>Files in the report folder</h2><ul><li><b>capture.json:</b> every folder and file with all details, for offline work. Open previous report &gt; capture.json rebuilds this report without rescanning.</li><li><b>summary.json, CSVs:</b> the same numbers for Excel.</li><li><b>issues.csv:</b> every flagged item.</li><li><b>mrp-link-update-DRAFT.csv:</b> only when an MRPeasy export was included. Review and pilot before uploading.</li></ul>'+
 '<h2>Privacy</h2><p>The report holds file and folder names, sizes and dates. It holds no file contents. Treat it as confidential client information.</p>'+
 '<h2>Questions</h2><p>Superior Networks LLC &middot; Dwain Henderson Jr. &middot; (937) 985-2480 &middot; dhenderson@superiornetworks.biz</p>';};
let start='summary';try{const s=localStorage.getItem('pp-tab');if(s&&R[s])start=s}catch(e){}
show(start);
})();
</script></body></html>
'@

# =====================================================================================
# Main
# =====================================================================================
$settings = Get-PPSettings
$useGui = (-not $NoGui) -and $IsWin -and (-not $Path) -and (-not $FromCapture)
# Create the default report folder on Windows so it is there in the start screen and Browse dialog
if ($IsWin -and -not (Test-Path -LiteralPath $DefaultReportPath)) {
    try { New-Item -ItemType Directory -Path $DefaultReportPath -Force -ErrorAction Stop | Out-Null } catch {}
}
if (-not $ReportPath -and $IsWin) { $ReportPath = $DefaultReportPath }
$v = @{ Client = $Client; Project = $Project; Ticket = $Ticket; Path = $Path; ReportPath = $ReportPath; MrpLinks = $MrpLinks; BlobBaseUrl = $BlobBaseUrl; HashLocal = [bool]$HashLocal; IncludeAcl = [bool]$IncludeAcl; Action = 'scan' }
if ($FromCapture) { $v.Action = 'rebuild'; $v.Capture = $FromCapture }
if ($useGui) {
    $g = Show-PPStartForm $settings
    if (-not $g) { Write-Host 'Cancelled.'; return }
    $v = $g
}

if ($v.Action -eq 'rebuild') {
    if (-not (Test-Path -LiteralPath $v.Capture -PathType Leaf)) { throw "Capture not found: $($v.Capture)" }
    $cap = Read-PPCapture $v.Capture
    $outDir = Split-Path -Parent (Resolve-Path -LiteralPath $v.Capture).ProviderPath
    $an = Get-PPAnalysis $cap $v.MrpLinks $v.BlobBaseUrl
    Write-PPOutputs $cap $an $outDir
} else {
    $problems = Test-PPInputs $v
    if ($problems.Count) { $problems | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }; throw 'Fix the inputs above and run again.' }
    $started = Get-Date
    $name = (Get-SafeName $v.Client) + $(if ($v.Ticket) { '-' + $v.Ticket } else { '' }) + '-' + $started.ToString('yyyyMMdd-HHmm')
    $outDir = Join-Path (Resolve-Path -LiteralPath $v.ReportPath).ProviderPath $name
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $rootFull = (Resolve-Path -LiteralPath $v.Path).ProviderPath
    $dev = Get-PPDeviceInfo $rootFull
    $scan = Invoke-PPScan $v.Path $v.HashLocal
    $acl = @(); if ($v.IncludeAcl) { $acl = @(Get-PPAcl $scan) }
    $meta = [ordered]@{
        client = $v.Client; project = $v.Project; ticket = $v.Ticket
        root = $scan.root; rootLength = $scan.root.Length; library = $dev.library
        scanStarted = $started.ToString('s'); scanMinutes = [math]::Round(((Get-Date) - $started).TotalMinutes, 1)
        computer = $(if ($IsWin) { $env:COMPUTERNAME } else { [Environment]::MachineName }); user = [Environment]::UserName
        psVersion = [string]$PSVersionTable.PSVersion; toolVersion = $ToolVersion; hashed = [bool]$v.HashLocal
    }
    $cap = @{ meta = $meta; device = $dev.lines.ToArray(); errors = $scan.errors.ToArray(); acl = $acl; folders = $scan.folders; files = $scan.files }
    Write-Host 'Writing capture.json ...' -ForegroundColor Cyan
    Write-PPCapture $cap (Join-Path $outDir 'capture.json')
    Write-Host 'Analyzing ...' -ForegroundColor Cyan
    $an = Get-PPAnalysis $cap $v.MrpLinks $v.BlobBaseUrl
    Write-PPOutputs $cap $an $outDir
}

Write-PPConsole $an
$report = Join-Path $outDir 'report.html'
$zip = "$outDir.zip"
if (-not $NoZip) {
    # .NET ZipFile instead of Compress-Archive: no progress bar (which fails without a real console,
    # e.g. SSH or RMM), faster, and no 2 GB per-file limit in Windows PowerShell 5.1.
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
        [IO.Compression.ZipFile]::CreateFromDirectory($outDir, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)
    }
    catch { $zip = ''; Write-Host "Could not create the zip ($($_.Exception.Message)). Zip the folder by hand: $outDir" -ForegroundColor Yellow }
} else { $zip = '' }
$line = '=' * 64
Write-Host ''
Write-Host $line -ForegroundColor Green
Write-Host '  REPORT SAVED' -ForegroundColor Green
Write-Host $line -ForegroundColor Green
Write-Host "  Folder:  $outDir" -ForegroundColor White
Write-Host "  Report:  $report" -ForegroundColor White
if ($zip) { Write-Host "  Zip:     $zip" -ForegroundColor White; Write-Host '  Send the .zip file back to Superior Networks.' -ForegroundColor Gray }
Write-Host $line -ForegroundColor Green

$label = "$($cap.meta.client)" + $(if ($cap.meta.ticket) { " - #$($cap.meta.ticket)" } else { '' }) + " - $(([string]$cap.meta.scanStarted).Replace('T', ' ').Substring(0, 16))"
if ($v.Action -eq 'scan') { $settings.last = @{ client = $v.Client; project = $v.Project; ticket = $v.Ticket; path = $v.Path; reportPath = $v.ReportPath; mrpLinks = $v.MrpLinks; blobBaseUrl = $v.BlobBaseUrl } }
Add-PPRecent $settings $label $report
Save-PPSettings $settings

if ($useGui) {
    Show-PPDoneForm $report $outDir $zip (Get-PPMailInfo $cap.meta $zip)
    # Keep the window open so the summary and report location stay on screen
    Write-Host ''
    try { Read-Host 'Press Enter to close this window' | Out-Null } catch {}
} elseif ($OpenReport) { Open-PPFile $report }
