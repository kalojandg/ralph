@echo off
REM Quick test - Task #1 with 5 attempts

echo.
echo ====================================================
echo         Quick Test: Task #1 (Setup)
echo         5 attempts until complete
echo ====================================================
echo.
echo Task: Install @dnd-kit packages
echo Attempts: up to 5
echo Model: Claude Sonnet 4
echo.
pause
echo.

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0TEST-SINGLE-FEATURE.ps1" -taskId 1 -maxAttempts 5

echo.
echo ====================================================
echo              Quick Test Complete
echo ====================================================
echo.
pause
