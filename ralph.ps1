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

# Main loop
$i = 1
while ($i -le $iterations) {
    Write-Host ""
    Write-Host ">>> Starting iteration $i of $iterations >>>" -ForegroundColor Magenta
    Write-Host ""

    # Execute one iteration — run inline so output is visible
    & .\$iterationScript -iterationNumber $i -configFile $configFile
    $exitCode = $LASTEXITCODE

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
        continue
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
