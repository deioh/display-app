@echo off
title Queue Display App - Server
color 0A

echo.
echo ============================================
echo    🏥 Queue Display App - Starting...
echo ============================================
echo.

REM Change to the script directory (project root)
cd /d "%~dp0"

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found. Please install Python 3.10+ and add to PATH.
    echo.
    pause
    exit /b 1
)

REM Install dependencies if needed
echo [*] Checking dependencies...
python -m pip install -q -r requirements.txt
if errorlevel 1 (
    echo [!] Warning: Failed to install some dependencies. Trying to continue...
)

REM Install Playwright Chromium if needed
echo [*] Ensuring Playwright Chromium is installed...
python -m playwright install chromium 2>nul || echo [!] Playwright browser install skipped/failed
echo.

REM Environment variables are loaded from .env file by the app itself
REM (via python-dotenv). You can still override here if needed:
REM set PAGE_URL=http://your-new-url-here
REM set PORT=5001
REM set REFRESH_SECS=5

echo [*] Configuration loaded from .env
echo [*] Starting server...
echo.
echo     Visit: http://localhost:5001
echo     Board: http://localhost:5001/board
echo     Press Ctrl+C to stop
echo.

REM Start the server
python main.py

pause
