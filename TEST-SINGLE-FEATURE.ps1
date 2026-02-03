param(
    [Parameter(Mandatory=$false)]
    [int]$taskId = 1,
    
    [Parameter(Mandatory=$false)]
    [int]$maxAttempts = 10,
    
    [Parameter(Mandatory=$false)]
    [string]$configFile = "ralph-config.json"
)

# Get script directory and build absolute paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$tasksFile = Join-Path $projectRoot "docs\composition\tasks.json"
$configFilePath = Join-Path $scriptDir $configFile
$promptFile = Join-Path $scriptDir "PROMPT.md"

# Change to script directory for relative operations
Set-Location $scriptDir

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "    Ralph Wiggum - Single Feature Test" -ForegroundColor Cyan
Write-Host "    Focus on ONE task with multiple attempts" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $tasksFile)) {
    Write-Host "X tasks.json not found: $tasksFile" -ForegroundColor Red
    exit 1
}

$tasks = Get-Content $tasksFile -Raw | ConvertFrom-Json
$targetTask = $tasks | Where-Object { $_.id -eq $taskId }

if (-not $targetTask) {
    Write-Host "X Task #$taskId not found in tasks.json" -ForegroundColor Red
    exit 1
}

Write-Host "Target Task: #$taskId" -ForegroundColor Yellow
Write-Host ("Description: " + $targetTask.description) -ForegroundColor Yellow
Write-Host ("Category: " + $targetTask.category) -ForegroundColor Gray
Write-Host ("Current Status: passes = " + $targetTask.passes) -ForegroundColor Gray
Write-Host ""
Write-Host "Max Attempts: $maxAttempts" -ForegroundColor Cyan
Write-Host "Model: claude-opus-4-20250514" -ForegroundColor Green
Write-Host ""

$originalPrompt = Get-Content $promptFile -Raw

$focusInstruction = @"

## SPECIAL INSTRUCTION FOR THIS RUN

FOCUS MODE: Work ONLY on Task #$taskId

Task Details:
- ID: $taskId
- Description: $($targetTask.description)
- Category: $($targetTask.category)

Instructions:
1. Read tasks.json and find Task #$taskId
2. Work ONLY on this task (ignore all others)
3. Follow full TDD workflow: RED -> GREEN -> VISUAL -> REFACTOR -> DONE
4. Mark passes: true ONLY when ALL criteria met
5. If task is already complete (passes: true), report success and exit

DO NOT work on any other tasks!

"@

$focusedPrompt = $focusInstruction + "`n`n" + $originalPrompt

$tempPromptFile = Join-Path $scriptDir "PROMPT-FOCUS-TASK-$taskId.md"
$focusedPrompt | Set-Content $tempPromptFile -Encoding UTF8

$tempConfigFile = Join-Path $scriptDir "ralph-config-focus-task-$taskId.json"
$config = Get-Content $configFilePath -Raw | ConvertFrom-Json
$config.prompt_file = "PROMPT-FOCUS-TASK-$taskId.md"
$config | ConvertTo-Json -Depth 10 | Set-Content $tempConfigFile -Encoding UTF8

Write-Host "Created focused prompt: $tempPromptFile" -ForegroundColor Green
Write-Host "Created focused config: $tempConfigFile" -ForegroundColor Green
Write-Host ""
Write-Host "Starting focused test run..." -ForegroundColor Yellow
Write-Host ""

$startTime = Get-Date
$attempt = 0
$taskCompleted = $false

while ($attempt -lt $maxAttempts -and -not $taskCompleted) {
    $attempt++
    
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Magenta
    Write-Host "  Attempt $attempt of $maxAttempts - Task #$taskId" -ForegroundColor Magenta
    Write-Host "====================================================" -ForegroundColor Magenta
    Write-Host ""
    
    $iterScript = Join-Path $scriptDir "ralph-iteration.ps1"
    & powershell -ExecutionPolicy Bypass -NoProfile -File $iterScript -iterationNumber $attempt -configFile "ralph-config-focus-task-$taskId.json"
    
    $tasks = Get-Content $tasksFile -Raw | ConvertFrom-Json
    $targetTask = $tasks | Where-Object { $_.id -eq $taskId }
    
    if ($targetTask.passes -eq $true) {
        $taskCompleted = $true
        Write-Host ""
        Write-Host "*** Task #$taskId COMPLETED! ***" -ForegroundColor Green
        Write-Host ""
        break
    } else {
        Write-Host ""
        Write-Host "Task #$taskId not yet complete (passes: false)" -ForegroundColor Yellow
        Write-Host "Continuing to next attempt..." -ForegroundColor Yellow
        Write-Host ""
        Start-Sleep -Seconds 2
    }
}

$endTime = Get-Date
$duration = $endTime - $startTime

Remove-Item $tempPromptFile -ErrorAction SilentlyContinue
Remove-Item $tempConfigFile -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "              Test Results" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

$tasks = Get-Content $tasksFile -Raw | ConvertFrom-Json
$targetTask = $tasks | Where-Object { $_.id -eq $taskId }

Write-Host ("Task: #" + $taskId + " - " + $targetTask.description) -ForegroundColor Yellow
Write-Host ""
Write-Host "Attempts Used: $attempt / $maxAttempts" -ForegroundColor Cyan

$totalMin = [math]::Round($duration.TotalMinutes, 2)
$avgMin = [math]::Round($duration.TotalMinutes / $attempt, 2)
Write-Host "Total Duration: $totalMin minutes" -ForegroundColor Cyan
Write-Host "Average per attempt: $avgMin minutes" -ForegroundColor Cyan
Write-Host ""

if ($targetTask.passes -eq $true) {
    Write-Host "Status: COMPLETED" -ForegroundColor Green
    Write-Host ""
    Write-Host "Task successfully completed after $attempt attempt(s)!" -ForegroundColor Green
} else {
    Write-Host "Status: NOT COMPLETE" -ForegroundColor Red
    Write-Host ""
    Write-Host "Task did not complete after $attempt attempts." -ForegroundColor Red
    Write-Host "Possible reasons:" -ForegroundColor Yellow
    Write-Host "  - Tests not passing" -ForegroundColor Gray
    Write-Host "  - Visual comparison not matching" -ForegroundColor Gray
    Write-Host "  - Linter errors" -ForegroundColor Gray
    Write-Host "  - TypeScript errors" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Check logs for details:" -ForegroundColor Yellow
    Write-Host "  - Activity: $projectRoot\docs\composition\activity.md" -ForegroundColor Gray
    Write-Host "  - Logs: $scriptDir\logs\" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Performance Summary:" -ForegroundColor Cyan
Write-Host "  Time spent: $totalMin minutes" -ForegroundColor Gray
Write-Host "  Attempts: $attempt" -ForegroundColor Gray
Write-Host ("  Completed: " + $targetTask.passes) -ForegroundColor Gray
Write-Host ""

if ($taskCompleted) {
    Write-Host "Ready to proceed with full run!" -ForegroundColor Green
    Write-Host "Run: .\START-RALPH-TDD.bat" -ForegroundColor Green
} else {
    Write-Host "Review logs and try again with more attempts" -ForegroundColor Yellow
}

Write-Host ""
