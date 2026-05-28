@echo off
chcp 65001 > nul
:: 65001 - UTF-8

cd /d "%~dp0"
title zapret + telegram

if /i "%~1"=="download-telegram" goto download_telegram
if /i "%~1"=="telegram-only" goto telegram_only
if /i "%~1"=="stop" goto stop_requested
if /i "%~1"=="admin-stop" goto stop_after_admin

call :ensure_admin
if errorlevel 1 exit /b 1

call :stop_all_processes

call :start_telegram_proxy
if errorlevel 1 (
    pause
    exit /b 1
)

call :get_strategy
call :start_watchdog

echo Starting zapret strategy: %STRATEGY_NAME%
echo:
call "%STRATEGY_PATH%"

timeout /t 2 /nobreak > nul
tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if errorlevel 1 (
    echo winws.exe did not start.
    echo Run pick-strategy.cmd to find a working ALT/FAKE strategy.
    call :stop_all_processes
    pause
    exit /b 1
)

echo zapret is running with: %STRATEGY_NAME%
echo Telegram proxy will be closed together with zapret-all.cmd.
echo Press Q to stop zapret and Telegram proxy.

:wait_loop
choice /c QN /n /t 2 /d N > nul
if errorlevel 2 goto check_winws
goto stop_all

:check_winws
tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if not errorlevel 1 goto wait_loop

:stop_all
call :stop_all_processes
echo:
echo zapret stopped. Telegram proxy was closed.
exit /b 0

:download_telegram
call :ensure_telegram_proxy
exit /b %ERRORLEVEL%

:telegram_only
call :start_telegram_proxy
if errorlevel 1 pause
exit /b %ERRORLEVEL%

:stop_requested
net session >nul 2>&1
if not errorlevel 1 goto stop_after_admin

echo Requesting admin rights...
powershell -NoProfile -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\" admin-stop\"' -Verb RunAs"
exit /b 1

:stop_after_admin
call :stop_all_processes
echo zapret and Telegram proxy stopped.
exit /b 0

:ensure_admin
net session >nul 2>&1
if not errorlevel 1 exit /b 0

echo Requesting admin rights...
powershell -NoProfile -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\" admin\"' -Verb RunAs"
exit /b 1

:get_strategy
set "STRATEGY_NAME=general.bat"
set "STRATEGY_FILE=%~dp0utils\combo-strategy.txt"
if exist "%STRATEGY_FILE%" (
    set /p STRATEGY_NAME=<"%STRATEGY_FILE%"
)
if not exist "%~dp0%STRATEGY_NAME%" (
    set "STRATEGY_NAME=general.bat"
)
set "STRATEGY_PATH=%~dp0%STRATEGY_NAME%"
exit /b 0

:ensure_telegram_proxy
set "TG_DIR=%~dp0tg-ws-proxy"
set "TG_EXE=%TG_DIR%\TgWsProxy_windows.exe"
set "TG_URL=https://github.com/Flowseal/tg-ws-proxy/releases/latest/download/TgWsProxy_windows.exe"

if exist "%TG_EXE%" exit /b 0
if not exist "%TG_DIR%" mkdir "%TG_DIR%"

echo Downloading Flowseal TG WS Proxy...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%TG_URL%' -OutFile '%TG_EXE%'"
if errorlevel 1 (
    echo Failed to download TG WS Proxy from GitHub.
    exit /b 1
)

exit /b 0

:start_telegram_proxy
tasklist /FI "IMAGENAME eq TgWsProxy_windows.exe" | find /I "TgWsProxy_windows.exe" > nul
if not errorlevel 1 (
    echo TG WS Proxy is already running.
    echo It will be closed together with zapret.
    exit /b 0
)

call :ensure_telegram_proxy
if errorlevel 1 exit /b 1

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $p = Start-Process -FilePath '%TG_EXE%' -WindowStyle Minimized -PassThru; Start-Sleep -Seconds 2; if (-not (Get-Process -Id $p.Id -ErrorAction SilentlyContinue)) { throw 'TG WS Proxy exited immediately' }; Write-Host ('TG WS Proxy PID: ' + $p.Id)"
if errorlevel 1 (
    echo Failed to start TG WS Proxy.
    echo Try running tg-ws-proxy\TgWsProxy_windows.exe manually to see its error.
    exit /b 1
)
echo TG WS Proxy started. Telegram Desktop proxy: MTProto 127.0.0.1:1443.
exit /b 0

:stop_all_processes
taskkill /IM winws.exe /F > nul 2>&1
taskkill /IM TgWsProxy_windows.exe /F > nul 2>&1
exit /b 0

:start_watchdog
for /f %%P in ('powershell -NoProfile -Command "(Get-CimInstance Win32_Process -Filter \"ProcessId=$PID\").ParentProcessId"') do set "COMBO_PID=%%P"
if not defined COMBO_PID exit /b 0

powershell -NoProfile -WindowStyle Hidden -Command "Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','\"%~dp0utils\combo-watchdog.ps1\"','-ParentPid','%COMBO_PID%'" > nul 2>&1
exit /b 0
