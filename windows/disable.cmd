@echo off
rem Double-click to run disable.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0disable.ps1" %*
echo.
pause
