@echo off
REM ================================================================
REM IT Troubleshooting Toolkit Launcher
REM Superior Networks LLC
REM ================================================================
REM
REM This batch file ensures the toolkit runs from the correct
REM installation directory: C:\ITTools\Scripts
REM
REM Always use this launcher.bat to start the toolkit!
REM ================================================================

REM Change to the installation directory
cd /d "C:\ITTools\Scripts"

REM Launch the PowerShell menu
PowerShell.exe -ExecutionPolicy Bypass -File "C:\ITTools\Scripts\launch_menu.ps1"

REM Pause if there was an error
if errorlevel 1 (
    echo.
    echo ERROR: Failed to launch the toolkit.
    echo.
    echo Please ensure the toolkit is installed at: C:\ITTools\Scripts
    echo.
    pause
)
