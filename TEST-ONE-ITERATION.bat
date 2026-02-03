@echo off
REM Test ONE iteration to check performance

echo.
echo ╔════════════════════════════════════════════════════╗
echo ║        Ralph Wiggum - Single Test Iteration       ║
echo ║             Performance Check                      ║
echo ╚════════════════════════════════════════════════════╝
echo.
echo Model: Claude Opus 4 (claude-opus-4-20250514)
echo Config: ralph-config.json
echo.
echo This will run ONE iteration to test:
echo   - Model performance
echo   - Task execution time
echo   - cursor-ide-browser MCP functionality
echo   - TDD workflow (RED → GREEN → VISUAL → REFACTOR)
echo.
echo Press Ctrl+C to cancel
echo.
pause
echo.

echo Starting single test iteration...
echo.

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0ralph-iteration.ps1" -iterationNumber 1

echo.
echo ╔════════════════════════════════════════════════════╗
echo ║            Test Iteration Complete                 ║
echo ╚════════════════════════════════════════════════════╝
echo.
echo Check results:
echo   - Console output above
echo   - Activity log: ..\docs\composition\activity.md
echo   - Tasks status: ..\docs\composition\tasks.json
echo   - Logs: .\logs\iteration-1-*.log
echo.
echo To run full Ralph: START-RALPH-TDD.bat
echo.
pause
