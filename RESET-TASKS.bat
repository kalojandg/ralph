@echo off
REM Reset all tasks to passes: false (for testing)

echo.
echo ╔════════════════════════════════════════════════════╗
echo ║            ⚠️ WARNING: RESET TASKS ⚠️             ║
echo ╚════════════════════════════════════════════════════╝
echo.
echo This will reset ALL tasks in tasks.json to passes: false
echo This will also clear activity.md log
echo.
echo Use this ONLY for testing or if you want to restart completely!
echo.
set /p confirm="Are you sure? Type YES to confirm: "

if /i not "%confirm%"=="YES" (
    echo.
    echo Reset cancelled.
    echo.
    pause
    exit /b
)

echo.
echo Resetting tasks...

powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "& { $tasks = Get-Content '..\docs\composition\tasks.json' -Raw | ConvertFrom-Json; $tasks | ForEach-Object { $_.passes = $false }; $tasks | ConvertTo-Json -Depth 10 | Set-Content '..\docs\composition\tasks.json'; Write-Host 'All tasks reset to passes: false' -ForegroundColor Green }"

echo.
echo Resetting activity.md...

powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "& { @'
# Frontend Implementation - Activity Log (TDD)

## Current Status

**Last Updated:** [Ralph will update]  
**Tasks Completed:** 0 / 30  
**Current Task:** Setup and infrastructure  
**Current Phase:** Setup

**Methodology:** Test-Driven Development (TDD)  
**Backend:** localStorage mock (no real API)  
**Visual Testing:** Playwright MCP screenshot comparison

---

## Session Log

<!-- Ralph Wiggum agent will append dated entries here -->
'@ | Set-Content '..\docs\composition\activity.md'; Write-Host 'Activity log reset' -ForegroundColor Green }"

echo.
echo ╔════════════════════════════════════════════════════╗
echo ║                 Reset Complete!                    ║
echo ╚════════════════════════════════════════════════════╝
echo.
echo You can now run Ralph fresh from the start.
echo.
pause
