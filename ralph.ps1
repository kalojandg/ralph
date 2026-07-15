param(
    [Parameter(Mandatory=$true)]
    [int]$iterations,
    
    [Parameter(Mandatory=$false)]
    [string]$configFile = "ralph-config.json"
)

# Get script directory and change to it
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

if ($iterations -le 0) {
    Write-Host "Usage: .\ralph.ps1 <iterations> [config-file]"
    Write-Host "Example: .\ralph.ps1 10"
    Write-Host "Example: .\ralph.ps1 10 custom-config.json"
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   Ralph Wiggum Algorithm for Claude Code" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration: $configFile" -ForegroundColor White
Write-Host "Max iterations: $iterations" -ForegroundColor White
Write-Host ""

# Check if iteration script exists
$iterationScript = "ralph-iteration.ps1"
if (!(Test-Path $iterationScript)) {
    Write-Host "[X] Error: $iterationScript not found!" -ForegroundColor Red
    Write-Host "Make sure ralph-iteration.ps1 is in the same directory." -ForegroundColor Yellow
    exit 1
}

# Pre-flight: verify Claude CLI is reachable
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudeCmd) {
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Red
    Write-Host "   [X] FATAL: 'claude' CLI not found on PATH" -ForegroundColor Red
    Write-Host "====================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Ralph harness needs the Claude CLI installed and on PATH." -ForegroundColor Yellow
    Write-Host "Without it, every iteration will fail silently with" -ForegroundColor Yellow
    Write-Host "  '[!] No output from Claude'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Install options:" -ForegroundColor Cyan
    Write-Host "  1. npm install -g @anthropic-ai/claude-code" -ForegroundColor White
    Write-Host "  2. Download standalone installer from claude.com/download" -ForegroundColor White
    Write-Host ""
    Write-Host "After install, verify with: claude --version" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}
Write-Host "[+] Claude CLI: $($claudeCmd.Source)" -ForegroundColor Green
Write-Host ""

# Main loop
$i = 1
$consecutiveFailures = 0
while ($i -le $iterations) {
    Write-Host ""
    Write-Host ">>> Starting iteration $i of $iterations >>>" -ForegroundColor Magenta
    Write-Host ""

    # Snapshot log dir before iteration so we can detect "did Claude write anything?"
    $logDir = Join-Path $scriptDir "logs"
    $beforeLogCount = if (Test-Path $logDir) { (Get-ChildItem $logDir -File).Count } else { 0 }

    # Execute one iteration — run inline so output is visible
    & .\$iterationScript -iterationNumber $i -configFile $configFile
    $exitCode = $LASTEXITCODE

    # Check if iteration produced a log (= Claude actually ran)
    $afterLogCount = if (Test-Path $logDir) { (Get-ChildItem $logDir -File).Count } else { 0 }
    $producedLog = $afterLogCount -gt $beforeLogCount

    Write-Host ""
    Write-Host "<<< End of iteration $i <<<" -ForegroundColor Magenta
    Write-Host ""

    # Check exit codes
    if ($exitCode -eq 0) {
        # All tasks complete
        Write-Host ""
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host "   [+] All tasks complete!" -ForegroundColor Green
        Write-Host "   Finished after $i iteration(s)" -ForegroundColor Green
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host ""
        exit 0
    }
    elseif ($exitCode -eq 2) {
        # Quota exceeded — iteration already waited, retry WITHOUT consuming iteration count
        Write-Host "[i] Retrying iteration $i after quota wait..." -ForegroundColor Cyan
        $consecutiveFailures = 0
        continue
    }
    elseif ($exitCode -eq 3) {
        # Iteration timed out — claude was killed. Advance to next iteration so we attempt the next pending task.
        Write-Host "[!] Iteration $i was killed due to timeout. Advancing to next iteration..." -ForegroundColor Yellow
        $consecutiveFailures = 0
        $i++
        Start-Sleep -Seconds 5
        continue
    }
    elseif ($exitCode -eq 4) {
        # Fatal environment error (API credit balance / auth) — no reset time to wait for,
        # a human must fix it. Retrying would just mark tasks failed for no reason.
        Write-Host ""
        Write-Host "====================================================" -ForegroundColor Red
        Write-Host "   [X] FATAL: billing/auth error (see log). Loop stopped." -ForegroundColor Red
        Write-Host "   Top up API credits or switch --model, then re-run." -ForegroundColor Red
        Write-Host "====================================================" -ForegroundColor Red
        exit 1
    }

    # Detect silent failure (Claude never produced output)
    if (-not $producedLog) {
        $consecutiveFailures++
        Write-Host ""
        Write-Host "[!] Iteration $i produced NO log — Claude likely failed to run." -ForegroundColor Yellow
        Write-Host "    Consecutive failures: $consecutiveFailures" -ForegroundColor Yellow

        if ($consecutiveFailures -ge 3) {
            Write-Host ""
            Write-Host "====================================================" -ForegroundColor Red
            Write-Host "   [X] ABORT: 3 consecutive failures with no output" -ForegroundColor Red
            Write-Host "====================================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "Likely causes:" -ForegroundColor Yellow
            Write-Host "  - Claude CLI auth expired (run: claude /login)" -ForegroundColor White
            Write-Host "  - Network / API unreachable" -ForegroundColor White
            $promptPath = Join-Path $env:TEMP "ralph-prompt-$i.txt"
            Write-Host "  - Prompt malformed (check temp file: $promptPath)" -ForegroundColor White
            Write-Host "  - Model name in ralph-config.json not available" -ForegroundColor White
            Write-Host ""
            Write-Host "Fix the issue and re-run." -ForegroundColor Cyan
            exit 1
        }

        # Slow pause so user can read the error before retry
        Write-Host "[i] Pausing 10s before next attempt (so you can read this)..." -ForegroundColor Cyan
        Start-Sleep -Seconds 10
    } else {
        $consecutiveFailures = 0
    }

    # Normal completion of one task — advance to next iteration
    $i++

    # Brief pause between iterations
    if ($i -le $iterations) {
        Start-Sleep -Milliseconds 500
    }
}

# Reached max iterations without completion
Write-Host ""
Write-Host "====================================================" -ForegroundColor Yellow
Write-Host "   [!] Reached max iterations ($iterations)" -ForegroundColor Yellow
Write-Host "   Tasks may not be complete" -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Yellow
Write-Host ""
exit 1
