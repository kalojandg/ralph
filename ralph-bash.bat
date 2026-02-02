@echo off
setlocal enabledelayedexpansion
REM This wrapper calls the original ralph.sh using Git Bash

echo ========================================
echo Ralph Wiggum Algorithm (Git Bash)
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

echo Търсене на Git Bash...
echo.

REM Try to find Git Bash
set "GIT_BASH=C:\Program Files\Git\bin\bash.exe"

if not exist "%GIT_BASH%" (
    set "GIT_BASH=C:\Program Files (x86)\Git\bin\bash.exe"
)

if not exist "%GIT_BASH%" (
    echo ГРЕШКА: Git Bash не е намерен!
    echo Моля инсталирай Git for Windows от: https://git-scm.com/download/win
    echo.
    pause
    exit /b 1
)

echo Git Bash намерен: %GIT_BASH%
echo Стартиране на %iterations% итерации...
echo.

REM Convert Windows path to Unix-style path for bash
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:\=/%"
set "SCRIPT_DIR=%SCRIPT_DIR:C:=/c%"

"%GIT_BASH%" -c "cd '%SCRIPT_DIR%' && chmod +x ralph.sh && ./ralph.sh %iterations%"

echo.
echo ========================================
echo Изпълнението завърши
echo ========================================
pause
