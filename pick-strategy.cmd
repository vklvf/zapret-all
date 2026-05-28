@echo off
chcp 65001 > nul
:: 65001 - UTF-8

cd /d "%~dp0"

if /i "%~1"=="admin" goto run_picker

net session >nul 2>&1
if not errorlevel 1 goto run_picker

echo Requesting admin rights...
powershell -NoProfile -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\" admin\"' -Verb RunAs"
exit /b 1

:run_picker
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0utils\pick-strategy.ps1"
pause
