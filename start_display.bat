@echo off
rem start_display.bat - kill stale app, start server, wait for port, launch Chrome kiosk
rem Idempotent: re-running kills the old server first.
cd /d "%~dp0"

rem --- Read PORT from .env (default 5001) ---
set PORT=5001
for /f "usebackq tokens=1,* delims==" %%a in (".env") do if /i "%%a"=="PORT" set PORT=%%b
echo [start_display] Using port %PORT%

rem --- Kill stale instances ---
echo [start_display] Killing stale listener on port %PORT%...
powershell -Command "Get-NetTCPConnection -LocalPort %PORT% -State Listen -EA SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }"

echo [start_display] Killing stale python running this app's main.py...
powershell -Command "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Where-Object { $_.CommandLine -like '*display-app*main.py*' -or $_.CommandLine -like '*spawn_main*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"

rem --- Start the server detached ---
echo [start_display] Starting server...
start "" "C:\Users\Deioh\AppData\Local\Programs\Python\Python313\python.exe" main.py

rem --- Wait for the port (poll up to 15s) ---
set TRIES=0
set PORT_OPEN=False
:waitloop
powershell -Command "Test-NetConnection -ComputerName 127.0.0.1 -Port %PORT% -InformationLevel Quiet" > "%TEMP%\portcheck.txt"
set /p PORT_OPEN=<"%TEMP%\portcheck.txt"
if /i "%PORT_OPEN%"=="True" goto portopen
set /a TRIES+=1
if %TRIES% GEQ 15 goto timeout
timeout /t 1 /nobreak >nul
goto waitloop

:timeout
echo [start_display] WARNING: port %PORT% did not open within 15s. Launching kiosk anyway.
goto launch

:portopen
echo [start_display] Server is up on port %PORT%.

:launch
rem --- Launch Chrome kiosk ---
where chrome >nul 2>nul
if %errorlevel%==0 (
    start "" chrome --kiosk http://127.0.0.1:%PORT%
) else (
    start chrome --kiosk http://127.0.0.1:%PORT%
)
echo [start_display] Done.