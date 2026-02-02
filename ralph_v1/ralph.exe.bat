@echo off
setlocal enabledelayedexpansion
REM Ralph Wiggum Algorithm Launcher
REM This wrapper makes the PowerShell script "executable"

echo ========================================
echo Ralph Wiggum Algorithm for Claude Code
echo ========================================
echo.

REM If no parameter provided, ask for it
if "%1"=="" (
    set /p iterations="Въведи брой итерации (например 10): "
    if "!iterations!"=="" (
        echo Грешка: Трябва да въведеш брой итерации!
        echo.
        pause
        exit /b 1
    )
) else (
    set iterations=%1
)

echo.
echo Стартиране на %iterations% итерации...
echo.

REM Execute the PowerShell script with bypass execution policy
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0ralph.ps1" %iterations%

echo.
echo ========================================
echo Изпълнението завърши
echo ========================================
pause
