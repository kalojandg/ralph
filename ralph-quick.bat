@echo off
REM Quick TDD launch with 10 iterations (for testing)
REM Double-click this file to start immediately

echo.
echo ╔════════════════════════════════════════════════════╗
echo ║   Ralph Wiggum TDD (Quick Test - 10 iterations)   ║
echo ╚════════════════════════════════════════════════════╝
echo.
echo Starting with 10 iterations...
echo TDD: RED → GREEN → VISUAL → REFACTOR → DONE
echo.

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0ralph.ps1" 10

echo.
echo ╔════════════════════════════════════════════════════╗
echo ║              Quick Test Complete                   ║
echo ╚════════════════════════════════════════════════════╝
echo.
echo Check: ..\docs\composition\activity.md for results
echo.
pause
