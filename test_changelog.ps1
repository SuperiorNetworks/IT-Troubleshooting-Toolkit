$content = Get-Content 'README.md' -Raw
$version = '2.5.0'
$pattern = "### Version $version \([^)]+\)\s*([\s\S]*?)(?=### Version|## |\z)"

Write-Host "Testing pattern: $pattern"
Write-Host ""

if ($content -match $pattern) {
    Write-Host "MATCH FOUND!" -ForegroundColor Green
    Write-Host "Captured text length: $($matches[1].Length)"
    Write-Host ""
    Write-Host "Full captured text:"
    Write-Host "===================="
    Write-Host $matches[1]
} else {
    Write-Host "NO MATCH FOUND" -ForegroundColor Red
    Write-Host ""
    Write-Host "Checking if version header exists..."
    if ($content -match '### Version 2\.5\.0') {
        Write-Host "Version 2.5.0 header EXISTS in README" -ForegroundColor Yellow
        
        # Show the actual line
        $lines = $content -split "`n"
        $versionLine = $lines | Where-Object { $_ -match '### Version 2\.5\.0' } | Select-Object -First 1
        Write-Host "Found line: '$versionLine'"
    } else {
        Write-Host "Version 2.5.0 header NOT FOUND" -ForegroundColor Red
    }
}
