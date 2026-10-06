<#
Name: build_fake_tree.ps1
Version: 3.18.0
Purpose: Build a fake file share with known problems, plus a fake MRPeasy links export, to test project_planner.ps1.
Author: Dwain Henderson Jr. | Superior Networks LLC
Contact: (937) 985-2480 | dhenderson@superiornetworks.biz
Copyright: 2026, Superior Networks LLC
Location: IT-Troubleshooting-Toolkit repo, tests/project_planner/build_fake_tree.ps1 (not installed on client machines)

What This Script Does:
  - Creates <Root>/Design with CAD # folders (.pdf/.ard), revisions, .ard-only folders, an empty folder
  - Adds names with # % spaces, trailing dot, leading space, Unicode, case collisions, junk and zero-byte files
  - Adds a deep path over 260 characters, an old (1975) and a future (2030) date, a duplicate name/size copy
  - Adds a symbolic link to a folder (must be recorded, not followed)
  - Writes <Root>/mrp-file-links.csv (semicolon) with path, drive-letter, SharePoint, case-mismatch, ambiguous and missing links

Input:
  - -Root: folder to build in (wiped first)

Output:
  - <Root>/Design and <Root>/mrp-file-links.csv

Dependencies:
  - PowerShell 7 (Linux or Windows). Some names (trailing dot, case collisions) only work on Linux/macOS file systems.

Change Log:
  2026-10-06 v1.0.0 - Initial release (Dwain Henderson Jr)
  2026-10-06 v3.18.0 - Moved into the toolkit repo under tests/project_planner (Dwain Henderson Jr)
#>
param([Parameter(Mandatory)] [string] $Root)

if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath $Root -Recurse -Force }
$d = Join-Path $Root 'Design'
function New-F([string] $rel, [int] $bytes = 100, [string] $date) {
    $p = Join-Path $d $rel
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null
    [IO.File]::WriteAllBytes($p, [byte[]]::new($bytes))
    if ($date) { [IO.File]::SetLastWriteTime($p, [datetime]$date) }
}
New-F 'Boxes/12372/12372.pdf' 1500 '2024-05-02'
New-F 'Boxes/12372/12372.ard' 6000 '2024-05-02'
New-F 'Boxes/12373/12373.pdf' 1400 '2025-01-10'
New-F 'Boxes/12373/12373 Rev B.pdf' 1450 '2025-01-14'
New-F 'Boxes/12373/12373.ard' 6100
New-F 'Boxes/12374/12374.ard' 5000
New-F 'Boxes/Thumbs.db' 10
New-F 'Boxes/~$draft.docx' 10
New-F 'Trays/20001 Spec #21714/Spec 21714.PDF' 1200
New-F 'Trays/20002/Tray 50%.pdf' 900
New-F 'Trays/20002/trailing.' 10
New-F 'Trays/20002/ lead.pdf' 10
New-F ("Trays/20002/Caf" + [char]0x00E9 + ".pdf") 10   # accented e, built in code to keep this file ASCII
New-F 'Trays/20003/A.pdf' 10
New-F 'Trays/20003/a.pdf' 10
New-F 'Trays/20003/empty.txt' 0
New-F 'Trays/20003/old.pdf' 10 '1975-06-01'
New-F 'Trays/20003/future.pdf' 10 '2030-01-01'
New-F 'Archive/12372/12372.pdf' 1500 '2023-03-03'
$deep = 'Archive/' + ((1..12 | ForEach-Object { 'a-very-long-folder-name-number-' + $_ }) -join '/') + '/deep-drawing.pdf'
try { New-F $deep 50 } catch { Write-Host "Note: could not create the 260+ character test path here ($($_.Exception.Message))" -ForegroundColor Yellow }
New-Item -ItemType Directory -Force -Path (Join-Path $d 'Empty') | Out-Null
New-Item -ItemType SymbolicLink -Path (Join-Path $d 'LinkToBoxes') -Target (Join-Path $d 'Boxes') | Out-Null

$csv = @'
Type;Number;Name;File link
Item;12372;Box A;\\amtech\design\Boxes\12372\12372.pdf
Item;12373;Box B;\\amtech\design\Boxes\12373\12373 rev b.pdf
Item;20002;Tray;Z:\Trays\20002\Tray 50%.pdf
Item;99999;Gone;\\amtech\design\Boxes\99999\99999.pdf
Item;12372b;Box A copy;\\old\x\12372.pdf
MO;5;Spec;https://contoso.sharepoint.com/sites/Design/Shared%20Documents/Trays/20001%20Spec%20%2321714/Spec%2021714.PDF
Item;12372;Box A again;\\amtech\design\Boxes\12372\12372.pdf
Item;77;No link;
'@
Set-Content -LiteralPath (Join-Path $Root 'mrp-file-links.csv') -Value $csv
Write-Host "Built $d"
