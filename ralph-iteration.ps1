param(
    [Parameter(Mandatory=$true)]
    [int]$iterationNumber,
    
    [Parameter(Mandatory=$false)]
    [string]$configFile = "ralph-config.json"
)

# Get script directory and change to it
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Build absolute path for config file if relative
if (-not [System.IO.Path]::IsPathRooted($configFile)) {
    $configFile = Join-Path $scriptDir $configFile
}

# Load configuration
if (Test-Path $configFile) {
    $config = Get-Content $configFile -Raw | ConvertFrom-Json
} else {
    Write-Host "[!] Config file not found: $configFile" -ForegroundColor Yellow
    $config = @{
        prompt_file = "PROMPT.md"
        claude_args = @("--output-format", "text")
        user_defined_steps = @{ enabled = $false }
        completion_criteria = @{ patterns = @("<promise>COMPLETE</promise>") }
        feedback = @{ enabled = $false }
        logging = @{ enabled = $false }
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Iteration $iterationNumber" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Build the prompt
$promptText = ""

if (Test-Path $config.prompt_file) {
    $promptText = Get-Content $config.prompt_file -Raw
    Write-Host "[+] Loaded prompt: $($config.prompt_file)" -ForegroundColor Green
} else {
    Write-Host "[X] Prompt file not found: $($config.prompt_file)" -ForegroundColor Red
    exit 1
}

if ($config.user_defined_steps.enabled -and $config.user_defined_steps.steps_file) {
    $stepsFile = $config.user_defined_steps.steps_file
    if (Test-Path $stepsFile) {
        $userSteps = Get-Content $stepsFile -Raw
        if ($config.user_defined_steps.append_to_prompt) {
            $promptText += "`n`n--- User Defined Steps ---`n`n"
            $promptText += $userSteps
            Write-Host "[+] Appended: $stepsFile" -ForegroundColor Green
        }
    }
}

if ($config.feedback.enabled -and $config.feedback.feedback_file -and $iterationNumber -gt 1) {
    $feedbackFile = $config.feedback.feedback_file
    if (Test-Path $feedbackFile) {
        $feedback = Get-Content $feedbackFile -Raw
        $promptText += "`n`n--- Feedback from Previous Iteration ---`n`n"
        $promptText += $feedback
        Write-Host "[+] Appended feedback" -ForegroundColor Green
    }
}

# Save prompt to temp file
$tempPromptFile = Join-Path $env:TEMP "ralph-prompt-$iterationNumber.txt"
$promptText | Out-File -FilePath $tempPromptFile -Encoding UTF8 -NoNewline

Write-Host ""
Write-Host ">>> Running Claude (streaming output) >>>" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor DarkGray
Write-Host ""

# Build command - escape the path properly
$escapedPath = $tempPromptFile -replace '\\', '\\'
$claudeCmd = "claude --print -p `"@$tempPromptFile`" --dangerously-skip-permissions"
foreach ($arg in $config.claude_args) {
    $claudeCmd += " $arg"
}

# Execute claude using cmd /c and capture output
$result = ""
try {
    # Use Invoke-Expression with Tee-Object to show and capture output
    $result = cmd /c $claudeCmd 2>&1 | ForEach-Object {
        Write-Host $_
        $_
    } | Out-String
} catch {
    Write-Host "[X] Error: $_" -ForegroundColor Red
    $result = "ERROR: $_"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor DarkGray
Write-Host "<<< End Claude Output <<<" -ForegroundColor Yellow
Write-Host ""

# Cleanup
Remove-Item $tempPromptFile -ErrorAction SilentlyContinue

# Save log
if ($config.logging.enabled) {
    $logDir = $config.logging.log_dir
    if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logFile = "$logDir/iteration-$iterationNumber-$timestamp.txt"
    $result | Out-File -FilePath $logFile -Encoding UTF8
    Write-Host "[+] Log saved: $logFile" -ForegroundColor Green
}

# Check completion
$isComplete = $false

foreach ($pattern in $config.completion_criteria.patterns) {
    if ($result -match [regex]::Escape($pattern)) {
        Write-Host "[+] ALL TASKS COMPLETE!" -ForegroundColor Green
        $isComplete = $true
        break
    }
}

if (-not $isComplete) {
    if ($result -match "<task-complete>") {
        Write-Host "[+] Task completed in this iteration" -ForegroundColor Cyan
    }
    if ($result -match "<status>CONTINUE</status>") {
        Write-Host "[+] Status: CONTINUE" -ForegroundColor Cyan
    }
    if ($result -match "<next-task>(\d+)</next-task>") {
        Write-Host "[+] Next task: #$($matches[1])" -ForegroundColor Yellow
    }
}

# User-defined completion check
if (!$isComplete -and $config.completion_criteria.user_defined_file) {
    $completionScript = $config.completion_criteria.user_defined_file
    if (Test-Path $completionScript) {
        $checkResult = & powershell -ExecutionPolicy Bypass -File $completionScript -result $result
        if ($checkResult -match "COMPLETE") {
            Write-Host "[+] All tasks done!" -ForegroundColor Green
            $isComplete = $true
        }
    }
}

Write-Host ""
if ($isComplete) {
    Write-Host "======== ALL COMPLETE! ========" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[i] Continuing to next iteration..." -ForegroundColor Cyan
    exit 1
}
