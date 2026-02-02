param(
    [Parameter(Mandatory=$true)]
    [int]$iterations,
    
    [Parameter(Mandatory=$false)]
    [string]$configFile = "ralph-config.json"
)

if ($iterations -le 0) {
    Write-Host "Usage: .\ralph.ps1 <iterations> [config-file]"
    Write-Host "Example: .\ralph.ps1 10"
    Write-Host "Example: .\ralph.ps1 10 custom-config.json"
    exit 1
}

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Ralph Wiggum Algorithm for Claude Code         ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration: $configFile" -ForegroundColor White
Write-Host "Max iterations: $iterations" -ForegroundColor White
Write-Host ""

# Check if iteration script exists
$iterationScript = "ralph-iteration.ps1"
if (!(Test-Path $iterationScript)) {
    Write-Host "✗ Error: $iterationScript not found!" -ForegroundColor Red
    Write-Host "Make sure ralph-iteration.ps1 is in the same directory." -ForegroundColor Yellow
    exit 1
}

# Main loop
for ($i = 1; $i -le $iterations; $i++) {
    Write-Host ""
    Write-Host "▼▼▼ Starting iteration $i of $iterations ▼▼▼" -ForegroundColor Magenta
    Write-Host ""
    
    # Execute one iteration
    $result = & powershell -ExecutionPolicy Bypass -NoProfile -File $iterationScript -iterationNumber $i -configFile $configFile
    $exitCode = $LASTEXITCODE
    
    Write-Host ""
    Write-Host "▲▲▲ End of iteration $i ▲▲▲" -ForegroundColor Magenta
    Write-Host ""
    
    # Check if complete
    if ($exitCode -eq 0) {
        Write-Host ""
        Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║          ✓ All tasks complete!                    ║" -ForegroundColor Green
        Write-Host "║          Finished after $i iteration(s)            ║" -ForegroundColor Green
        Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        exit 0
    }
    
    # Optional: pause between iterations (except last one)
    if ($i -lt $iterations) {
        Start-Sleep -Milliseconds 500
    }
}

# Reached max iterations without completion
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║   ⚠️ Reached max iterations ($iterations)             ║" -ForegroundColor Yellow
Write-Host "║   Tasks may not be complete                       ║" -ForegroundColor Yellow
Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""
exit 1
