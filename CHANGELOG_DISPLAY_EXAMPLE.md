# Changelog Display Example - v2.5.0

This document shows what users will see when they update to v2.5.0 using Option 1: Download and Install Latest Version.

---

## What the User Will See

When updating from v2.4.0 to v2.5.0, the screen will display:

```
=== Checking for Updates ===
Current version: 2.4.0
Downloading from GitHub...
Extracting files...
Installing to C:\ITTools\Scripts...
Overwriting existing files if present...

=================================================================
                    Update Complete                              
=================================================================

  ✓ Updated from v2.4.0 → v2.5.0

  What's New in v2.5.0:

  - **Master Audit Logging System**: Comprehensive logging for troubleshooting and support
    - Logs all user actions, menu selections, and errors to `C:\ITTools\Scripts\Logs\master_audit_log.txt`
    - Captures diagnostic information: username, computer name, admin status, PowerShell version, OS version, timestamps
    - Structured log format with severity levels (INFO, WARN, ERROR)
    - Complete error messages with stack traces for debugging
    - Silent failure on logging errors (doesn't disrupt user experience)
  - **UI Improvement**: Removed persistent ImageManager status from main menu for cleaner interface
  - **Enhanced Changelog Display**: Now shows detailed changelog from README.md after updates (instead of brief embedded notes)
  - Status information still available in StorageCraft Troubleshooter submenu when needed

  Installation Path: C:\ITTools\Scripts

Press any key to return to menu...
```

---

## Color Coding

The changelog is displayed with color-coded formatting for better readability:

| Line Type | Color | Example |
|-----------|-------|---------|
| **Main bullets with bold** (e.g., `- **Feature**:`) | **Green** | `- **Master Audit Logging System**: Comprehensive logging...` |
| **Sub-bullets** (indented with `  -`) | **Gray** | `  - Logs all user actions, menu selections...` |
| **Regular bullets** (e.g., `- Item`) | **White** | `- Status information still available...` |

---

## How It Works

### 1. Function: `Get-ChangelogFromReadme`

This function extracts the changelog for a specific version from README.md:

```powershell
function Get-ChangelogFromReadme {
    param(
        [string]$version,
        [string]$readmePath = ""
    )
    
    # Use provided README path or default to installed version
    $readme = if ($readmePath) { $readmePath } else { Join-Path $installPath "README.md" }
    
    if (Test-Path $readme) {
        try {
            $content = Get-Content $readme -Raw
            
            # Extract changelog section for specific version
            # Pattern: ### Version X.X.X (date) followed by bullet points until next version or section
            $pattern = "### Version $version \([^)]+\)\s*([\s\S]*?)(?=### Version|## |\z)"
            
            if ($content -match $pattern) {
                $changelogText = $matches[1].Trim()
                
                # Split into lines and filter for bullet points and sub-bullets
                $lines = $changelogText -split "`n" | Where-Object { $_.Trim() -ne "" }
                
                return $lines
            }
        }
        catch {
            return @()
        }
    }
    return @()
}
```

### 2. Extraction Pattern

The function uses a regex pattern to extract changelog text:

```
### Version 2.5.0 (2025-12-08)
- **Master Audit Logging System**: ...
  - Sub-bullet 1
  - Sub-bullet 2
- **UI Improvement**: ...

### Version 2.4.0 (2025-12-08)    ← Stops here (next version)
```

**Pattern:** `### Version 2.5.0 \([^)]+\)\s*([\s\S]*?)(?=### Version|## |\z)`

- Matches: `### Version 2.5.0 (2025-12-08)`
- Captures: Everything after the version header
- Stops at: Next `### Version` or `## ` section or end of file

### 3. Display Logic

The function displays each line with appropriate color based on its format:

```powershell
foreach ($line in $changelog) {
    # Format different line types with appropriate colors
    if ($line -match '^-\s*\*\*') {
        # Main bullet with bold (e.g., - **Feature**: description)
        Write-Host "  $line" -ForegroundColor Green
    }
    elseif ($line -match '^\s+-\s+') {
        # Sub-bullet (indented)
        Write-Host "  $line" -ForegroundColor Gray
    }
    elseif ($line -match '^-\s+') {
        # Regular bullet
        Write-Host "  $line" -ForegroundColor White
    }
    else {
        # Other text
        Write-Host "  $line" -ForegroundColor White
    }
}
```

---

## README.md Changelog Format

To ensure proper extraction and display, maintain this format in README.md:

```markdown
## Change Log

### Version 2.5.0 (2025-12-08)
- **Main Feature Name**: Brief description
  - Sub-feature or detail 1
  - Sub-feature or detail 2
  - Sub-feature or detail 3
- **Another Feature**: Description
- Regular bullet point without bold

### Version 2.4.0 (2025-12-08)
- **Feature**: Description
...
```

**Important Rules:**
1. Version header must be: `### Version X.X.X (YYYY-MM-DD)`
2. Main features should use: `- **Feature Name**: Description`
3. Sub-bullets should be indented with 2 spaces: `  - Sub-item`
4. Regular bullets use: `- Item`
5. Blank lines between versions are optional

---

## Benefits Over Embedded Release Notes

### Before (Embedded in Script Header)

**Pros:**
- ✅ Always available offline
- ✅ Part of the script itself

**Cons:**
- ❌ Limited space (keep it brief)
- ❌ Duplicate maintenance (script header + README)
- ❌ Less detailed information
- ❌ Harder to format nicely

**Example:**
```
.RELEASE_NOTES
v2.5.0:
- Added comprehensive master audit logging system for troubleshooting
- Logs all user actions, menu selections, and errors to C:\ITTools\Scripts\Logs\master_audit_log.txt
- Captures diagnostic info: username, computer, admin status, PS version, OS version, timestamps
- Removed persistent ImageManager status from main menu (cleaner interface)
```

### After (From README.md)

**Pros:**
- ✅ Single source of truth (README.md)
- ✅ Detailed, well-formatted information
- ✅ Supports multi-level bullet points
- ✅ Color-coded display
- ✅ No duplicate maintenance
- ✅ Professional presentation

**Cons:**
- ❌ Requires README.md to be present (always is during install)

**Example:**
```
- **Master Audit Logging System**: Comprehensive logging for troubleshooting and support
  - Logs all user actions, menu selections, and errors to `C:\ITTools\Scripts\Logs\master_audit_log.txt`
  - Captures diagnostic information: username, computer name, admin status, PowerShell version, OS version, timestamps
  - Structured log format with severity levels (INFO, WARN, ERROR)
  - Complete error messages with stack traces for debugging
  - Silent failure on logging errors (doesn't disrupt user experience)
- **UI Improvement**: Removed persistent ImageManager status from main menu for cleaner interface
- **Enhanced Changelog Display**: Now shows detailed changelog from README.md after updates (instead of brief embedded notes)
- Status information still available in StorageCraft Troubleshooter submenu when needed
```

---

## Fallback Behavior

If the changelog cannot be extracted from README.md (file missing, version not found, etc.), the system displays a generic message:

```
  What's New in v2.5.0:

  - Bug fixes and improvements
```

This ensures the installation process never fails due to changelog extraction issues.

---

## Future Maintenance

When releasing a new version (e.g., v2.6.0):

1. **Update launch_menu.ps1 header:**
   - Change `Version: 2.5.0` to `Version: 2.6.0`
   - Add changelog entry to `Change Log:` section

2. **Update README.md:**
   - Change `**Version:** 2.5.0` to `**Version:** 2.6.0`
   - Add new `### Version 2.6.0 (YYYY-MM-DD)` section to `## Change Log`
   - Follow the format with main bullets and sub-bullets

3. **Update Show-Menu version display:**
   - Change hardcoded version in `Show-Menu` function

4. **That's it!** The changelog will automatically display from README.md

---

## Testing the Display

To test the changelog display locally:

```powershell
# Test the extraction function
$readme = "C:\ITTools\Scripts\README.md"
$changelog = Get-ChangelogFromReadme -version "2.5.0" -readmePath $readme

# Display the changelog
foreach ($line in $changelog) {
    if ($line -match '^-\s*\*\*') {
        Write-Host "  $line" -ForegroundColor Green
    }
    elseif ($line -match '^\s+-\s+') {
        Write-Host "  $line" -ForegroundColor Gray
    }
    elseif ($line -match '^-\s+') {
        Write-Host "  $line" -ForegroundColor White
    }
    else {
        Write-Host "  $line" -ForegroundColor White
    }
}
```

---

**Developed by:** Superior Networks LLC  
**Copyright:** 2025  
**Repository:** https://github.com/SuperiorNetworks/IT-Troubleshooting-Toolkit
