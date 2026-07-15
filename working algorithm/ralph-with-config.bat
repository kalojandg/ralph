@echo off
setlocal enabledelayedexpansion
REM Ralph with custom config file

echo ========================================
echo Ralph Wiggum Algorithm (Custom Config)
echo ========================================
echo.

REM Check for parameters
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

if "%2"=="" (
    set config=ralph-config.json
    echo Използвам default config: !config!
) else (
    set config=%2
    echo Използвам custom config: !config!
)

echo.
echo Стартиране на !iterations! итерации с config: !config!
echo.

REM Execute the PowerShell script with bypass execution policy
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0ralph.ps1" !iterations! !config!

echo.
echo ========================================
echo Изпълнението завърши
echo ========================================
pause
