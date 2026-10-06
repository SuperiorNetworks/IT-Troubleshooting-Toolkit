@echo off
rem Name: run_project_planner.cmd
rem Version: 3.18.0
rem Purpose: Double-click launcher for project_planner.ps1 (opens the start screen)
rem Author: Dwain Henderson Jr. ^| Superior Networks LLC
rem Contact: (937) 985-2480 ^| dhenderson@superiornetworks.biz
rem Copyright: 2026, Superior Networks LLC
rem Path: C:\ITTools\Scripts\run_project_planner.cmd
rem Change Log:
rem   2026-10-06 v1.0.0 - Initial release (Dwain Henderson Jr)
rem   2026-10-06 v3.18.0 - Added to IT Troubleshooting Toolkit (Dwain Henderson Jr)
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0project_planner.ps1"
if errorlevel 1 pause
