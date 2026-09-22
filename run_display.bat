@echo off
title Queue Display Kiosk - Launcher
color 0A

echo.
echo ============================================
echo    🏥 Queue Display Kiosk - Launcher
echo ============================================
echo.

REM Change to the script directory (project root)
cd /d "%~dp0"

REM Check if config.ini exists
if not exist "config.ini" (
    echo [!] config.ini not found. Copy from config.ini.example:
    echo.
    echo    copy config.ini.example config.ini
    echo    notepad config.ini
    echo.
    echo Then update your URLs and settings before running.
    echo.
    pause
    exit /b 1
)

REM Check if Chrome is available
where chrome >nul 2>&1
if errorlevel 1 (
    echo [!] Chrome not found in PATH. Checking common locations...
    if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
        echo     [OK] Chrome found at C:\Program Files\Google\Chrome\
    ) else if exist "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" (
        echo     [OK] Chrome found at C:\Program Files (x86)\Google\Chrome\
    ) else (
        echo [!] Chrome not found. Please install Google Chrome and try again.
        pause
        exit /b 1
    )
)

echo [✓] Dependencies OK
echo.

REM Launch the kiosk controller
echo [*] Starting Queue Display Kiosk...
echo [*] Press F8 to exit, F5 to restart, F6 to cycle modes
echo.

REM Try to run the compiled launcher first, fall back to .au3
if exist "launcher.exe" (
    launcher.exe
) else (
    echo [*] launcher.exe not found — please compile launcher.au3 with AutoIt3Wrapper.
    echo [*] Alternatively, double-click launcher.au3 directly in Explorer.
    echo.
    pause
    exit /b 1
)

pause
