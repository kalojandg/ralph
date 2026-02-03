@echo off
REM View latest Ralph Wiggum iteration logs

echo.
echo ╔════════════════════════════════════════════════════╗
echo ║        Ralph Wiggum Latest Iteration Log          ║
echo ╚════════════════════════════════════════════════════╝
echo.

if not exist "logs" (
    echo No logs folder found. Ralph hasn't run yet.
    echo.
    pause
    exit /b
)

powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "& { $latest = Get-ChildItem 'logs' | Sort-Object LastWriteTime -Descending | Select-Object -First 1; if ($latest) { Write-Host 'Latest log: '$latest.Name -ForegroundColor Cyan; Write-Host ''; Get-Content $latest.FullName; } else { Write-Host 'No iteration logs found yet.' -ForegroundColor Yellow } }"

echo.
echo.
echo To view all logs: explorer logs
echo.
pause
