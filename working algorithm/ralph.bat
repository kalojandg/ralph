@echo off
setlocal enabledelayedexpansion

echo ========================================
echo Ralph Wiggum Algorithm for Claude Code
echo ========================================
echo.

REM If no parameter provided, ask for it
if "%1"=="" (
    set /p max_iterations="Въведи брой итерации (например 10): "
    if "!max_iterations!"=="" (
        echo Грешка: Трябва да въведеш брой итерации!
        echo.
        pause
        exit /b 1
    )
) else (
    set max_iterations=%1
)

echo.
echo Стартиране на %max_iterations% итерации...
echo.

for /L %%i in (1,1,%max_iterations%) do (
    echo Iteration %%i
    echo --------------------------------
    
    claude -p "@PROMPT.md" --output-format text > temp_result.txt 2>&1
    set /p result=<temp_result.txt
    type temp_result.txt
    
    findstr /C:"<promise>COMPLETE</promise>" temp_result.txt >nul
    if !errorlevel! equ 0 (
        echo.
        echo ========================================
        echo All tasks complete after %%i iterations.
        echo ========================================
        del temp_result.txt
        pause
        exit /b 0
    )
    
    echo.
    echo --- End of iteration %%i ---
    echo.
)

del temp_result.txt
echo.
echo ========================================
echo Reached max iterations (%max_iterations%)
echo ========================================
pause
exit /b 1
