@echo off
REM Ralph SWARM - parallel agents over git worktrees
REM Usage: START-RALPH-SWARM.bat [agents] [maxTasks]
REM   agents   - parallel slots (default 3; from playbook: start 2-3, ceiling 5-6)
REM   maxTasks - stop after N tasks (default 0 = run until done/blocked)

setlocal
set AGENTS=%1
set MAXTASKS=%2
if "%AGENTS%"=="" set AGENTS=3
if "%MAXTASKS%"=="" set MAXTASKS=0

echo.
echo ====================================================
echo    Ralph SWARM - Parallel Agentic Development
echo    Agents: %AGENTS%   MaxTasks: %MAXTASKS%
echo ====================================================
echo.
echo Each agent gets its OWN worktree + branch + console window.
echo The orchestrator (this window) claims tasks, merges branches
echo sequentially and updates tasks.json / activity.md.
echo.
echo Press Ctrl+C to stop launching new agents (running ones finish).
echo.
pause
echo.

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0ralph-swarm.ps1" -agents %AGENTS% -maxTasks %MAXTASKS%

echo.
echo ====================================================
echo               Swarm Execution Complete
echo ====================================================
echo.
echo Check results:
echo   - Tasks status:   %~dp0tasks.json
echo   - Activity log:   %~dp0activity.md
echo   - Agent results:  %~dp0results\
echo   - Kept branches:  git branch --list "ralph/task-*"  (in each repo)
echo.
pause
