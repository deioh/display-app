@echo off
rem ===========================================================================
rem  start_display.bat - start the Queue Display server and open Chrome
rem
rem  Idempotent: re-running first kills any stale server / Chrome instance.
rem  Window stays open at the end so errors are readable (see :end).
rem ===========================================================================

setlocal EnableDelayedExpansion
cd /d "%~dp0"

rem --------------------------------------------------------------------------
rem  Read settings from .env  (eol=# skips comment lines)
rem --------------------------------------------------------------------------
set "PORT=5001"
set "AUTO_LAUNCH=1"
set "KIOSK_MODE=1"

if not exist ".env" (
    echo [start_display] WARNING: .env not found - using defaults. Copy .env.example to .env.
) else (
    for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do (
        if /i "%%a"=="PORT"        set "PORT=%%b"
        if /i "%%a"=="AUTO_LAUNCH" set "AUTO_LAUNCH=%%b"
        if /i "%%a"=="KIOSK_MODE"  set "KIOSK_MODE=%%b"
        rem Legacy key: AUTO_KIOSK=0 meant "do not auto-launch"
        if /i "%%a"=="AUTO_KIOSK"  set "AUTO_LAUNCH=%%b"
    )
)

echo [start_display] PORT=%PORT%  AUTO_LAUNCH=%AUTO_LAUNCH%  KIOSK_MODE=%KIOSK_MODE%

set "URL=http://127.0.0.1:%PORT%"

rem --------------------------------------------------------------------------
rem  Kill stale instances
rem --------------------------------------------------------------------------
echo [start_display] Killing stale listener on port %PORT% ...
powershell -NoProfile -Command "Get-NetTCPConnection -LocalPort %PORT% -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }"

echo [start_display] Killing stale python running this app's main.py ...
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Where-Object { $_.CommandLine -like '*display-app*main.py*' -or $_.CommandLine -like '*spawn_main*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"

rem --------------------------------------------------------------------------
rem  Locate python
rem --------------------------------------------------------------------------
set "PYTHON_EXE="
for %%p in (
    "C:\Users\Deioh\AppData\Local\Programs\Python\Python313\python.exe"
    "C:\Users\Deioh\AppData\Local\Programs\Python\Python312\python.exe"
) do if exist %%p if not defined PYTHON_EXE set "PYTHON_EXE=%%~p"

if not defined PYTHON_EXE (
    for /f "delims=" %%p in ('where python 2^>nul') do if not defined PYTHON_EXE set "PYTHON_EXE=%%p"
)

if not defined PYTHON_EXE (
    echo [start_display] ERROR: could not find python.exe
    goto :end
)
echo [start_display] Using python: %PYTHON_EXE%

rem --------------------------------------------------------------------------
rem  Start the server detached
rem --------------------------------------------------------------------------
echo [start_display] Starting server ...
start "Queue Display Server" "%PYTHON_EXE%" "%~dp0main.py"

rem --------------------------------------------------------------------------
rem  Wait for the port to open (poll up to 40s)
rem  NOTE: netstat is used instead of Test-NetConnection, because the latter
rem        writes a multi-line WARNING into the captured file when the port is
rem        closed, which corrupts the value read back by `set /p`.
rem --------------------------------------------------------------------------
set /a TRIES=0
:waitloop
netstat -an | findstr /R /C:"TCP.*:%PORT% .*LISTENING" >nul 2>&1
if not errorlevel 1 goto :portopen

set /a TRIES+=1
if %TRIES% GEQ 40 goto :timeout
powershell -NoProfile -Command "Start-Sleep -Milliseconds 500" >nul 2>&1
goto :waitloop

:timeout
echo [start_display] WARNING: port %PORT% did not open within 40s.
echo [start_display]          The server may have failed to start - check the
echo [start_display]          "Queue Display Server" window for a traceback.
goto :launch

:portopen
echo [start_display] Server is up on port %PORT%.

rem --------------------------------------------------------------------------
rem  Launch Chrome
rem --------------------------------------------------------------------------
:launch
if not "%AUTO_LAUNCH%"=="1" (
    echo [start_display] AUTO_LAUNCH is not 1 - server only, not launching Chrome.
    goto :end
)

echo [start_display] Closing any existing Chrome showing this app ...
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='chrome.exe'\" | Where-Object { $_.CommandLine -like '*127.0.0.1:%PORT%*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"

set "CHROME_EXE="
for %%p in (
    "C:\Program Files\Google\Chrome\Application\chrome.exe"
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
    "%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"
) do if exist %%p if not defined CHROME_EXE set "CHROME_EXE=%%~p"

set "URL=http://127.0.0.1:%PORT%"
set "FLAGS=--autoplay-policy=no-user-gesture-required"
if "%KIOSK_MODE%"=="1" set "FLAGS=--kiosk --autoplay-policy=no-user-gesture-required"

if defined CHROME_EXE (
    if "%KIOSK_MODE%"=="1" (echo [start_display] Launching Chrome in kiosk mode ...) else (echo [start_display] Launching Chrome in a normal window ...)
    start "" "%CHROME_EXE%" %FLAGS% %URL%
) else (
    echo [start_display] Chrome not found in the usual locations - using the default browser.
    start "" %URL%
)

:end
echo [start_display] Done.
echo.
echo   Display : %URL%
echo   Server  : running in the "Queue Display Server" window
echo   Kiosk   : %KIOSK_MODE%   (set KIOSK_MODE=0 in .env for a normal window)
echo   Auto    : %AUTO_LAUNCH%  (set AUTO_LAUNCH=0 in .env for server-only)
echo.
echo [start_display] You can close this window.
pause
endlocal
