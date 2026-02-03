@echo off
REM TDD Ralph Wiggum - БДЖ Compositions Module
REM Стартира с 20 iterations (препоръчително за TDD)

echo.
echo ╔════════════════════════════════════════════════════╗
echo ║   Ralph Wiggum TDD - Compositions Module          ║
echo ║   Test-Driven Development + Visual Feedback       ║
echo ╚════════════════════════════════════════════════════╝
echo.
echo Starting with 20 iterations...
echo.
echo TDD Workflow: RED → GREEN → VISUAL → REFACTOR → DONE
echo Visual Testing: Playwright MCP screenshot comparison
echo Backend: localStorage mock (no real API)
echo.
echo Press Ctrl+C to stop at any time
echo.
pause
echo.

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0ralph.ps1" 20

echo.
echo ╔════════════════════════════════════════════════════╗
echo ║              Execution Complete                    ║
echo ╚════════════════════════════════════════════════════╝
echo.
echo Check results:
echo   - Activity log: ..\docs\composition\activity.md
echo   - Tasks status: ..\docs\composition\tasks.json
echo   - Iteration logs: .\logs\
echo.
pause
