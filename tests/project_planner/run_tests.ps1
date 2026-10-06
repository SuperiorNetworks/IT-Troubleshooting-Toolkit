<#
Name: run_tests.ps1
Version: 3.18.1
Purpose: End-to-end test of project_planner.ps1 against a fake share (scan, capture, report, MRPeasy check, rebuild).
Author: Dwain Henderson Jr. | Superior Networks LLC
Contact: (937) 985-2480 | dhenderson@superiornetworks.biz
Copyright: 2026, Superior Networks LLC
Location: IT-Troubleshooting-Toolkit repo, tests/project_planner/run_tests.ps1 (not installed on client machines)

What This Script Does:
  - Builds the fake share (build_fake_tree.ps1) in a work folder
  - Runs project_planner.ps1 -NoGui with the fake MRPeasy export and a Blob base URL
  - Checks counts against an independent file count, issue codes, MRPeasy matching, URL encoding,
    capture.json / summary.json / embedded report data are valid JSON, and the logo is embedded
  - Rebuilds the report with -FromCapture (no MRPeasy file) and checks it still works
  - Checks the script for PowerShell 7-only syntax so it still runs in Windows PowerShell 5.1

Input:
  - -Work: work folder (default: a folder in the system temp directory)

Output:
  - PASS/FAIL lines and an exit code (0 = all passed)

Dependencies:
  - PowerShell 7 (Linux/Mac/Windows) or Windows PowerShell 5.1

Change Log:
  2026-10-06 v1.0.0 - Initial release (Dwain Henderson Jr)
  2026-10-06 v3.18.0 - Moved into the toolkit repo under tests/project_planner; skip checks Windows
                      can't set up (case-only names, trailing dots, paths over 260) (Dwain Henderson Jr)
  2026-10-06 v3.18.1 - Check that the displayed version matches the script header (Dwain Henderson Jr)
#>
param([string] $Work = (Join-Path ([IO.Path]::GetTempPath()) 'pp-test'))

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$tool = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'project_planner.ps1'
$fails = 0
# On Windows the fake share can't hold names that differ only by case, trailing dots, or a
# path over 260 characters, so those checks are skipped there (long paths are covered by real scans).
$onWindows = ($env:OS -eq 'Windows_NT')
$winSkip = @('paths over 260', 'issue TRAILING_DOT_SPACE found', 'issue CASE_COLLISION found', 'issue LONG_PATH found')
function Check([string] $what, [bool] $ok, $detail) {
    if ($onWindows -and $winSkip -contains $what -and -not $ok) { Write-Host "SKIP  $what   (not possible on Windows)" -ForegroundColor Yellow; return }
    if ($ok) { Write-Host "PASS  $what" -ForegroundColor Green } else { Write-Host "FAIL  $what   ($detail)" -ForegroundColor Red; $script:fails++ }
}

& (Join-Path $here 'build_fake_tree.ps1') -Root $Work
$share = Join-Path $Work 'Design'
$reports = Join-Path $Work 'reports'
New-Item -ItemType Directory -Force -Path $reports | Out-Null

& $tool -NoGui -Client 'Test Client' -Project 'Fake share test' -Ticket 12345 -Path $share -ReportPath $reports `
    -MrpLinks (Join-Path $Work 'mrp-file-links.csv') -BlobBaseUrl 'https://example.blob.core.windows.net/drawings' -HashLocal | Out-Host

$out = Get-ChildItem -LiteralPath $reports -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Check 'report folder created' ($null -ne $out) 'no folder'
$o = $out.FullName
foreach ($f in 'report.html', 'capture.json', 'summary.json', 'issues.csv', 'extensions.csv', 'mrp-link-review.csv', 'mrp-link-update-DRAFT.csv', 'mrp-unlinked-pdfs.csv', 'device-info.txt') {
    Check "output $f" (Test-Path -LiteralPath (Join-Path $o $f)) 'missing'
}
Check 'zip created' (Test-Path -LiteralPath "$o.zip") 'missing'
Check 'folder name' ($out.Name -match '^Test-Client-12345-\d{8}-\d{4}$') $out.Name

$cap = Get-Content -LiteralPath (Join-Path $o 'capture.json') -Raw | ConvertFrom-Json
$sum = (Get-Content -LiteralPath (Join-Path $o 'summary.json') -Raw | ConvertFrom-Json)
$s = $sum.summary
$expectFiles = @(Get-ChildItem -LiteralPath $share -Recurse -File -Force | Where-Object { $_.FullName -notlike '*LinkToBoxes*' }).Count
Check 'capture.json valid, file count' ($cap.files.Count -eq $expectFiles) "$($cap.files.Count) vs $expectFiles"
Check 'summary TotalFiles' ($s.TotalFiles -eq $expectFiles) "$($s.TotalFiles) vs $expectFiles"
Check 'symlink recorded, not followed' (@($cap.folders | Where-Object { $_.n -eq 'LinkToBoxes' -and $_.rp -eq 1 }).Count -eq 1) 'not found'
Check 'empty folder counted' ($s.EmptyFolders -ge 1) $s.EmptyFolders
Check 'bad dates' ($s.BadDates -eq 2) $s.BadDates
Check 'oldest modified ignores 1975' ($s.OldestModified -ge '1980') $s.OldestModified
Check 'paths over 260' ($s.PathsOver260 -ge 1) $s.PathsOver260
Check 'drawing folders: ard only' ($s.Folders_ArdOnly -eq 1) $s.Folders_ArdOnly
Check 'drawing folders: multiple pdfs' ($s.Folders_MultiplePdfs -ge 1) $s.Folders_MultiplePdfs
$ic = $sum.issues
foreach ($code in 'URL_RESERVED', 'SPACE', 'NON_ASCII', 'TRAILING_DOT_SPACE', 'LEADING_SPACE', 'CASE_COLLISION', 'DUP_NAME', 'LIKELY_DUPLICATE', 'ZERO_BYTE', 'JUNK', 'LONG_PATH', 'BAD_DATE', 'REPARSE_POINT', 'EMPTY_FOLDER', 'DUP_CONTENT') {
    Check "issue $code found" ($ic.$code -ge 1) $ic.$code
}
Check 'no false TOO_MANY_SEGMENTS' ($ic.TOO_MANY_SEGMENTS -eq 0) $ic.TOO_MANY_SEGMENTS

# MRPeasy
Check 'mrp links' ($s.Mrp_Links -eq 7) $s.Mrp_Links
Check 'mrp matched' ($s.Mrp_Matched -eq 5) $s.Mrp_Matched
Check 'mrp ambiguous' ($s.Mrp_Ambiguous -eq 1) $s.Mrp_Ambiguous
Check 'mrp not found' ($s.Mrp_NotFound -eq 1) $s.Mrp_NotFound
Check 'mrp case differs' ($s.Mrp_CaseDiffers -eq 1) $s.Mrp_CaseDiffers
Check 'mrp link column detected' ($s.Mrp_LinkColumn -eq 'File link') $s.Mrp_LinkColumn
$upd = @(Import-Csv -LiteralPath (Join-Path $o 'mrp-link-update-DRAFT.csv'))
Check 'update csv: one row per unique old link' ($upd.Count -eq 4) $upd.Count
$tray = $upd | Where-Object { $_.old -like '*Tray 50%*' }
Check 'encoding: space and percent' ($tray.new -eq 'https://example.blob.core.windows.net/drawings/Trays/20002/Tray%2050%25.pdf') $tray.new
$spec = $upd | Where-Object { $_.old -like '*sharepoint*' }
Check 'encoding: hash sign, SharePoint link matched' ($spec.new -eq 'https://example.blob.core.windows.net/drawings/Trays/20001%20Spec%20%2321714/Spec%2021714.PDF') $spec.new

# report.html
$html = Get-Content -LiteralPath (Join-Path $o 'report.html') -Raw
Check 'logo embedded' ($html -match 'data:image/png;base64,iVBOR') 'no PNG data'
Check 'version in footer' ($html -match 'Project Planner v\d+\.\d+\.\d+') 'no version'
$hdrVer = ''; foreach ($l in (Get-Content -LiteralPath $tool -TotalCount 10)) { if ($l -match '^Version:\s*(\d+\.\d+\.\d+)') { $hdrVer = $matches[1]; break } }
Check 'footer version matches script header' ($html -match ('Project Planner v' + [regex]::Escape($hdrVer))) "header $hdrVer"
$m = [regex]::Match($html, '<script id="pp-data" type="application/json">(.*?)</script>', 'Singleline')
$data = $null; try { $data = $m.Groups[1].Value | ConvertFrom-Json } catch {}
Check 'embedded report data is valid JSON' ($null -ne $data -and $data.files.Count -eq $expectFiles) "parse failed or wrong count"
Check 'no unreplaced placeholders' (-not ($html -match '__(DATA|LOGO|VERSION|TITLE)__')) 'placeholder left'

# rebuild from capture (offline re-analysis)
& $tool -NoGui -NoZip -FromCapture (Join-Path $o 'capture.json') | Out-Host
$sum2 = Get-Content -LiteralPath (Join-Path $o 'summary.json') -Raw | ConvertFrom-Json
Check 'rebuild from capture: same totals' ($sum2.summary.TotalFiles -eq $expectFiles -and $sum2.summary.TotalSizeBytes -eq $s.TotalSizeBytes) "$($sum2.summary.TotalFiles)"
Check 'rebuild from capture: report written' ((Get-Item -LiteralPath (Join-Path $o 'report.html')).Length -gt 10000) 'small'

# Windows PowerShell 5.1 compatibility (no PS7-only syntax)
$tokens = $null; $errs = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($tool, [ref]$tokens, [ref]$errs)
$bad = @($tokens | Where-Object { $_.Kind -in 'QuestionQuestion', 'QuestionQuestionEquals', 'QuestionDot', 'QuestionLBracket', 'AndAnd', 'OrOr' })
$ternary = @($ast.FindAll({ param($n) $n.GetType().Name -eq 'TernaryExpressionAst' }, $true))
Check 'no PS7-only operators (??, ?., &&, ||, ternary)' ($bad.Count -eq 0 -and $ternary.Count -eq 0) "$($bad.Count) tokens, $($ternary.Count) ternary"
$ps7cmds = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ -in 'ForEach-Object -Parallel', 'Get-Error', 'Join-String', 'Test-Json' })
Check 'no PS7-only cmdlets' ($ps7cmds.Count -eq 0) ($ps7cmds -join ',')

Write-Host ''
if ($fails) { Write-Host "$fails check(s) failed" -ForegroundColor Red; exit 1 } else { Write-Host 'All checks passed' -ForegroundColor Green; exit 0 }
