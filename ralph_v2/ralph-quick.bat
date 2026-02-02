@echo off
REM Quick launch with default 10 iterations
REM Double-click this file to start immediately

echo ========================================
echo Ralph Wiggum Algorithm (Quick Launch)
echo Starting with 10 iterations...
echo ========================================
echo.

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0ralph.ps1" 10

echo.
echo ========================================
echo Execution completed
echo ========================================
pause
