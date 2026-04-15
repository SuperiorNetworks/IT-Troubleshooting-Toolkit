import re

with open('/home/ubuntu/IT-Troubleshooting-Toolkit/ftp_sync_tool.ps1', 'r') as f:
    content = f.read()

new_func = """function Upload-FilesWithWinSCP {
    param (
        [array]$files,
        [hashtable]$ftpCreds
    )
    
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "              Uploading Files with WinSCP                        " -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $successCount = 0
    $failCount = 0
    $failedFiles = @()
    
    Write-Log "Starting upload of $($files.Count) files with 3-strike retry logic..."
    
    foreach ($file in $files) {
        $fileName = if ($file.Name) { $file.Name } else { Split-Path $file.FullPath -Leaf }
        $filePath = $file.FullPath
        
        Write-Host "Uploading: $fileName " -NoNewline -ForegroundColor White
        Write-Log "Attempting to upload: $fileName"
        
        $attempts = 0
        $maxAttempts = 3
        $success = $false
        
        while ($attempts -lt $maxAttempts -and -not $success) {
            $attempts++
            
            if ($attempts -gt 1) {
                Write-Host "[Retry $attempts/$maxAttempts] " -NoNewline -ForegroundColor Yellow
                Write-Log "Retry $attempts/$maxAttempts for $fileName"
                Start-Sleep -Seconds 5 # Brief pause before retry
            }
            
            # Create a single-file WinSCP script for this attempt
            $scriptPath = Join-Path $env:TEMP "winscp_upload_$($attempts).txt"
            $logPath = Join-Path $logDirectory "winscp_$($fileName)_$($attempts).log"
            
            $scriptContent = @"
option batch abort
option confirm off
open ftp://$($ftpCreds.User):$($ftpCreds.Pass)@$($ftpCreds.Server)/
put "$filePath"
exit
"@
            $scriptContent | Out-File -FilePath $scriptPath -Encoding ASCII
            
            try {
                # Run WinSCP for this single file
                $output = & $winscpExe /script=$scriptPath /log="$logPath" 2>&1
                
                # Check output for success
                $fileSuccess = $false
                foreach ($line in $output) {
                    if ($line -match 'Upload of file.*finished' -or $line -match 'Transfer was successfully finished') {
                        $fileSuccess = $true
                        break
                    }
                }
                
                if ($fileSuccess) {
                    $success = $true
                    Write-Host "[OK]" -ForegroundColor Green
                    Write-Log "Successfully uploaded: $fileName on attempt $attempts"
                } else {
                    if ($attempts -eq $maxAttempts) {
                        Write-Host "[FAILED]" -ForegroundColor Red
                        Write-Log "Failed to upload $fileName after $maxAttempts attempts." "ERROR"
                    }
                }
            }
            catch {
                Write-Log "WinSCP execution error on $fileName: $($_.Exception.Message)" "ERROR"
            }
            finally {
                Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
            }
        }
        
        if ($success) {
            $successCount++
        } else {
            $failCount++
            $failedFiles += $fileName
        }
    }
    
    Write-Host ""
    Write-Host "-----------------------------------------------------------------" -ForegroundColor Gray
    Write-Host "Upload Summary:" -ForegroundColor Cyan
    Write-Host "  Total Files: $($files.Count)" -ForegroundColor White
    Write-Host "  Successful: $successCount" -ForegroundColor Green
    
    if ($failCount -gt 0) {
        Write-Host "  Failed: $failCount" -ForegroundColor Red
        Write-Host ""
        Write-Host "Failed Files List:" -ForegroundColor Yellow
        foreach ($failed in $failedFiles) {
            Write-Host "  - $failed" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "Check individual logs in $logDirectory for details." -ForegroundColor Yellow
    }
    
    Write-Host "-----------------------------------------------------------------" -ForegroundColor Gray
    Write-Host ""
    
    Write-Log "Upload complete: $successCount successful, $failCount failed" "SUCCESS"
}"""

# Replace the old function
pattern = re.compile(r'function Upload-FilesWithWinSCP \{.*?(?=\n# --- Main Script ---)', re.DOTALL | re.MULTILINE)
new_content = pattern.sub(new_func + '\n', content)

with open('/home/ubuntu/IT-Troubleshooting-Toolkit/ftp_sync_tool.ps1', 'w') as f:
    f.write(new_content)

print("Replaced Upload-FilesWithWinSCP function")
