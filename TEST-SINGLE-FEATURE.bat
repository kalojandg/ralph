@echo off
REM Test Ralph on ONE specific feature with multiple attempts

echo.
echo ====================================================
echo     Ralph Wiggum - Single Feature Test
echo     Test ONE task with multiple attempts
echo ====================================================
echo.

set /p taskId="Enter Task ID to test (default: 1): "
if "%taskId%"=="" set taskId=1

set /p attempts="Enter max attempts (default: 10): "
if "%attempts%"=="" set attempts=10

echo.
echo Testing Task #%taskId% with max %attempts% attempts...
echo Model: Claude Sonnet 4
echo TDD: RED - GREEN - VISUAL - REFACTOR - DONE
echo.
pause
echo.

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0TEST-SINGLE-FEATURE.ps1" -taskId %taskId% -maxAttempts %attempts%

echo.
echo ====================================================
echo                  Test Complete
echo ====================================================
echo.
pause
