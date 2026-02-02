param(
    [Parameter(Mandatory=$true)]
    [int]$iterationNumber,
    
    [Parameter(Mandatory=$false)]
    [string]$configFile = "ralph-config.json"
)

# Load configuration
if (Test-Path $configFile) {
    $config = Get-Content $configFile -Raw | ConvertFrom-Json
} else {
    Write-Host "⚠️ Config file not found: $configFile"
    Write-Host "Using default configuration..."
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

# 1. Read main prompt file
if (Test-Path $config.prompt_file) {
    $promptText = Get-Content $config.prompt_file -Raw
    Write-Host "✓ Loaded main prompt from: $($config.prompt_file)" -ForegroundColor Green
} else {
    Write-Host "✗ Prompt file not found: $($config.prompt_file)" -ForegroundColor Red
    exit 1
}

# 2. Append user-defined steps if enabled
if ($config.user_defined_steps.enabled -and $config.user_defined_steps.steps_file) {
    $stepsFile = $config.user_defined_steps.steps_file
    if (Test-Path $stepsFile) {
        $userSteps = Get-Content $stepsFile -Raw
        if ($config.user_defined_steps.append_to_prompt) {
            $promptText += "`n`n--- User Defined Steps ---`n`n"
            $promptText += $userSteps
            Write-Host "✓ Appended user steps from: $stepsFile" -ForegroundColor Green
        }
    } else {
        Write-Host "⚠️ User steps file not found: $stepsFile (skipping)" -ForegroundColor Yellow
    }
}

# 3. Append feedback from previous iteration if enabled
if ($config.feedback.enabled -and $config.feedback.feedback_file -and $iterationNumber -gt 1) {
    $feedbackFile = $config.feedback.feedback_file
    if (Test-Path $feedbackFile) {
        $feedback = Get-Content $feedbackFile -Raw
        $promptText += "`n`n--- Feedback from Previous Iteration ---`n`n"
        $promptText += $feedback
        Write-Host "✓ Appended feedback from: $feedbackFile" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Executing Claude..." -ForegroundColor Cyan

# Execute Claude
try {
    $claudeArgs = @("-p", $promptText) + $config.claude_args
    $result = & claude $claudeArgs 2>&1 | Out-String
} catch {
    $result = $_.Exception.Message
    Write-Host "✗ Error executing Claude: $result" -ForegroundColor Red
    exit 1
}

Write-Host $result
Write-Host ""

# Save iteration log if enabled
if ($config.logging.enabled) {
    $logDir = $config.logging.log_dir
    if (!(Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logFile = "$logDir/iteration-$iterationNumber-$timestamp.txt"
    $result | Out-File -FilePath $logFile -Encoding UTF8
    Write-Host "✓ Saved log to: $logFile" -ForegroundColor Green
}

# Check completion criteria
$isComplete = $false

# Check built-in patterns
foreach ($pattern in $config.completion_criteria.patterns) {
    if ($result -match [regex]::Escape($pattern)) {
        Write-Host "✓ Found completion pattern: $pattern" -ForegroundColor Green
        $isComplete = $true
        break
    }
}

# Check user-defined completion script if exists
if (!$isComplete -and $config.completion_criteria.user_defined_file) {
    $completionScript = $config.completion_criteria.user_defined_file
    if (Test-Path $completionScript) {
        Write-Host "Checking user-defined completion criteria..." -ForegroundColor Cyan
        
        # Execute the user completion check script
        # It should accept $result as input and output "COMPLETE" or "CONTINUE"
        $checkResult = & powershell -File $completionScript -result $result
        
        if ($checkResult -match "COMPLETE") {
            Write-Host "✓ User-defined completion criteria met!" -ForegroundColor Green
            $isComplete = $true
        }
    }
}

# Return result as exit code
if ($isComplete) {
    exit 0
} else {
    exit 1
}
