@echo off
REM Simple test to check if Claude Code works

echo.
echo ====================================================
echo     Testing Claude Code
echo ====================================================
echo.

echo 1. Checking Claude version...
echo.
claude --version

echo.
echo 2. Testing programmatic invocation with --print flag...
echo.
echo Command: claude --print -p "Say hello in Bulgarian" --dangerously-skip-permissions
echo.

claude --print -p "Say hello in Bulgarian" --dangerously-skip-permissions

echo.
echo ====================================================
echo If you see a response above, Claude works perfectly! ✓
echo This is the correct way to use Claude with subscription.
echo ====================================================
echo.
pause
