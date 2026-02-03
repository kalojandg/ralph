@echo off
REM Check Ralph Wiggum TDD progress

echo.
echo ╔════════════════════════════════════════════════════╗
echo ║          Ralph Wiggum TDD Progress                ║
echo ╚════════════════════════════════════════════════════╝
echo.

powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "& { $tasks = Get-Content '..\docs\composition\tasks.json' -Raw | ConvertFrom-Json; $completed = ($tasks | Where-Object { $_.passes -eq $true }).Count; $total = $tasks.Count; $percent = [math]::Round(($completed / $total) * 100, 2); Write-Host ''; Write-Host 'Progress: '$completed' / '$total' tasks complete ('$percent'%%)' -ForegroundColor Green; Write-Host ''; Write-Host 'Completed tasks:' -ForegroundColor Cyan; $tasks | Where-Object { $_.passes -eq $true } | ForEach-Object { Write-Host '  ✓ Task #'$_.id': '$_.description -ForegroundColor Green }; Write-Host ''; Write-Host 'Remaining tasks:' -ForegroundColor Yellow; $tasks | Where-Object { $_.passes -eq $false } | Select-Object -First 5 | ForEach-Object { Write-Host '  ○ Task #'$_.id': '$_.description -ForegroundColor Yellow }; if (($tasks | Where-Object { $_.passes -eq $false }).Count -gt 5) { Write-Host '  ... and '$( ($tasks | Where-Object { $_.passes -eq $false }).Count - 5)' more' -ForegroundColor Gray }; Write-Host ''; }"

echo.
pause
