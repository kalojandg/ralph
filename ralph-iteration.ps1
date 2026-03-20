param(
    [int]$iterationNumber = 1,
    [string]$configFile = "ralph-config.json"
)

# Setup paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$tasksFile = Join-Path $scriptDir "tasks.json"

# Load config
$config = $null
if (Test-Path $configFile) {
    $config = Get-Content $configFile -Raw | ConvertFrom-Json
    Write-Host "[+] Config: $configFile" -ForegroundColor Green
} else {
    Write-Host "[!] Config not found, using defaults" -ForegroundColor Yellow
}

# Get model from config or use default
$model = "claude-opus-4-5-20251101"
if ($config -and $config.claude_args) {
    $modelIndex = [array]::IndexOf($config.claude_args, "--model")
    if ($modelIndex -ge 0 -and $modelIndex -lt $config.claude_args.Count - 1) {
        $model = $config.claude_args[$modelIndex + 1]
    }
}

Write-Host "[i] Iteration $iterationNumber starting..." -ForegroundColor Cyan
Write-Host "[i] Model: $model" -ForegroundColor Cyan

# Build prompt from PROMPT.md and user-steps.md
$promptText = ""

# Get prompt file from config or use default
$promptFile = "PROMPT.md"
if ($config -and $config.prompt_file) {
    $promptFile = $config.prompt_file
}

# Check in current dir first, then project root
$promptPath = $promptFile
if (!(Test-Path $promptPath)) {
    $promptPath = Join-Path $projectRoot $promptFile
}
if (!(Test-Path $promptPath)) {
    $promptPath = Join-Path $projectRoot "PROMPT.md"
}

if (Test-Path $promptPath) {
    $promptText = Get-Content $promptPath -Raw
    Write-Host "[+] Loaded: $promptPath" -ForegroundColor Green
} else {
    Write-Host "[X] PROMPT.md not found!" -ForegroundColor Red
    exit 1
}

# Get prerequisite file from config (appended BEFORE user-steps — read after task selection, before coding)
$prereqFile = "prerequisite-steps.md"
if ($config -and $config.prerequisite_steps -and $config.prerequisite_steps.steps_file) {
    $prereqFile = $config.prerequisite_steps.steps_file
}

$prereqEnabled = $true
if ($config -and $config.prerequisite_steps -and $config.prerequisite_steps.PSObject.Properties['enabled']) {
    $prereqEnabled = $config.prerequisite_steps.enabled
}

if ($prereqEnabled -and (Test-Path $prereqFile)) {
    $promptText += "`n`n--- Prerequisite: Read Before Implementation ---`n`n"
    $promptText += Get-Content $prereqFile -Raw
    Write-Host "[+] Appended prerequisite: $prereqFile" -ForegroundColor Green
}

# Get steps file from config (appended AFTER prerequisite — post-implementation checks)
$stepsFile = "user-steps.md"
if ($config -and $config.user_defined_steps -and $config.user_defined_steps.steps_file) {
    $stepsFile = $config.user_defined_steps.steps_file
}

if (Test-Path $stepsFile) {
    $promptText += "`n`n--- Post-Implementation Steps ---`n`n"
    $promptText += Get-Content $stepsFile -Raw
    Write-Host "[+] Appended user-steps: $stepsFile" -ForegroundColor Green
}

# Save prompt to temp file
$tempPrompt = Join-Path $env:TEMP "ralph-prompt-$iterationNumber.txt"
$promptText | Out-File -FilePath $tempPrompt -Encoding UTF8

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "   CLAUDE IS WORKING..." -ForegroundColor Yellow
Write-Host "   (output appears below when complete)" -ForegroundColor Gray
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

# Run Claude - capture output but also display progress indicator
$outputFile = Join-Path $env:TEMP "ralph-output-$iterationNumber.txt"

# Calculate project root (Admin-App folder)
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
Write-Host "[i] Project root: $projectRoot" -ForegroundColor Cyan

# Start claude in background and monitor
# IMPORTANT: Job must change to project root directory so Claude can find files!
$job = Start-Job -ScriptBlock {
    param($prompt, $output, $modelName, $workDir)
    Set-Location $workDir
    & claude -p "@$prompt" --model $modelName --dangerously-skip-permissions 2>&1 | Out-File -FilePath $output -Encoding UTF8
} -ArgumentList $tempPrompt, $outputFile, $model, $projectRoot

# Show spinner while waiting
$spinChars = @('|', '/', '-', '\')
$spinIndex = 0
$lastSize = 0

Write-Host -NoNewline "Working "
while ($job.State -eq 'Running') {
    Write-Host -NoNewline "`rWorking $($spinChars[$spinIndex]) "
    $spinIndex = ($spinIndex + 1) % 4
    
    # Check if output file is growing
    if (Test-Path $outputFile) {
        $size = (Get-Item $outputFile).Length
        if ($size -gt $lastSize) {
            $lastSize = $size
            Write-Host -NoNewline "(${size} bytes) "
        }
    }
    
    Start-Sleep -Milliseconds 500
}

# Wait for job to complete
$null = Wait-Job $job
$null = Remove-Job $job

Write-Host ""
Write-Host ""

# Read and display output
if (Test-Path $outputFile) {
    $result = Get-Content $outputFile -Raw
    
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "   CLAUDE OUTPUT:" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host $result
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Yellow
    
    # Save to log
    $logDir = "logs"
    if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logFile = "$logDir/iteration-$iterationNumber-$timestamp.txt"
    $result | Out-File -FilePath $logFile -Encoding UTF8
    Write-Host "[+] Log saved: $logFile" -ForegroundColor Green
    
    # Cleanup
    Remove-Item $outputFile -ErrorAction SilentlyContinue
} else {
    Write-Host "[!] No output from Claude" -ForegroundColor Yellow
}

# Cleanup temp prompt
Remove-Item $tempPrompt -ErrorAction SilentlyContinue

# Check tasks.json for completion
Write-Host ""
if (Test-Path $tasksFile) {
    $tasksContent = Get-Content $tasksFile -Raw
    $tasks = $tasksContent | ConvertFrom-Json
    
    # Count explicitly
    $total = 0
    $done = 0
    foreach ($task in $tasks) {
        $total++
        if ($task.passes -eq $true) {
            $done++
        }
    }
    
    Write-Host "Progress: $done / $total tasks complete" -ForegroundColor Cyan
    
    if ($done -eq $total -and $total -gt 0) {
        Write-Host "[+] ALL TASKS COMPLETE!" -ForegroundColor Green
        exit 0
    }
    
    $next = $tasks | Where-Object { $_.passes -eq $false } | Select-Object -First 1
    if ($next) {
        Write-Host "Next task: #$($next.id) - $($next.description)" -ForegroundColor Yellow
    }
}

Write-Host ""
exit 1
