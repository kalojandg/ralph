param(
    [Parameter(Mandatory=$false)]
    [string]$configFile = "ralph-config.json"
)

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   Ralph Wiggum Performance Test (1 iteration)" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

if (Test-Path $configFile) {
    $config = Get-Content $configFile -Raw | ConvertFrom-Json
    $modelArg = $config.claude_args | Where-Object { $_ -like "claude-*" }
    if ($modelArg) {
        Write-Host "Model: $modelArg" -ForegroundColor Green
    }
}

Write-Host "Config: $configFile" -ForegroundColor Gray
Write-Host ""
Write-Host "Starting test iteration..." -ForegroundColor Yellow
Write-Host ""

$startTime = Get-Date

& powershell -ExecutionPolicy Bypass -NoProfile -File "$PSScriptRoot\ralph-iteration.ps1" -iterationNumber 1 -configFile $configFile

$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "              Performance Metrics" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host ("Total Duration: " + $duration.TotalSeconds + " seconds") -ForegroundColor Green
Write-Host ("               (" + [math]::Round($duration.TotalMinutes, 2) + " minutes)") -ForegroundColor Green
Write-Host ""

$estimatedFullTime = $duration.TotalMinutes * 30
Write-Host "Estimated time for 30 tasks:" -ForegroundColor Yellow
Write-Host ("  - If all tasks take this long: " + [math]::Round($estimatedFullTime, 1) + " minutes") -ForegroundColor Yellow
Write-Host ("  - (~" + [math]::Round($estimatedFullTime / 60, 1) + " hours)") -ForegroundColor Yellow
Write-Host ""

Write-Host "Task Status:" -ForegroundColor Cyan
# Get script directory and build absolute path
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$tasksFile = Join-Path $projectRoot "docs\composition\tasks.json"
if (Test-Path $tasksFile) {
    try {
        $tasks = Get-Content $tasksFile -Raw | ConvertFrom-Json
        $completedCount = ($tasks | Where-Object { $_.passes -eq $true }).Count
        $totalCount = $tasks.Count
        
        Write-Host "  Completed: $completedCount / $totalCount tasks" -ForegroundColor Green
        
        if ($completedCount -gt 0) {
            $remainingTasks = $totalCount - $completedCount
            $remainingTime = $duration.TotalMinutes * $remainingTasks
            Write-Host "  Remaining: $remainingTasks tasks" -ForegroundColor Yellow
            Write-Host ("  Estimated remaining time: " + [math]::Round($remainingTime, 1) + " minutes") -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [!] Could not parse tasks.json" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [!] tasks.json not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Check detailed results:" -ForegroundColor Cyan
Write-Host "  - Activity log: ..\docs\composition\activity.md" -ForegroundColor Gray
Write-Host "  - Tasks: ..\docs\composition\tasks.json" -ForegroundColor Gray
Write-Host "  - Logs: .\logs\" -ForegroundColor Gray
Write-Host ""

$latestLog = Get-ChildItem ".\logs" -ErrorAction SilentlyContinue | 
    Where-Object { $_.Name -like "iteration-1-*" } | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1

if ($latestLog) {
    Write-Host ("Latest log: " + $latestLog.Name) -ForegroundColor Gray
    Write-Host ""
    Write-Host "Last 20 lines of log:" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Get-Content $latestLog.FullName -Tail 20
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "To run full Ralph (20 iterations): .\START-RALPH-TDD.bat" -ForegroundColor Green
Write-Host ""
