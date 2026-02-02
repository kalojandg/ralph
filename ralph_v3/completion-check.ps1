param(
    [Parameter(Mandatory=$true)]
    [string]$result
)

# Custom completion check logic
# Return "COMPLETE" if done, "CONTINUE" if not

# Example 1: Check for specific keywords
$completeKeywords = @(
    "all tests passing",
    "deployment successful",
    "no errors found",
    "task completed successfully"
)

foreach ($keyword in $completeKeywords) {
    if ($result -match [regex]::Escape($keyword)) {
        Write-Host "✓ Found completion keyword: $keyword" -ForegroundColor Green
        Write-Output "COMPLETE"
        exit 0
    }
}

# Example 2: Check for error indicators (if found, NOT complete)
$errorKeywords = @(
    "error:",
    "failed:",
    "exception:",
    "critical:"
)

foreach ($keyword in $errorKeywords) {
    if ($result -match [regex]::Escape($keyword)) {
        Write-Host "✗ Found error indicator: $keyword" -ForegroundColor Red
        Write-Output "CONTINUE"
        exit 0
    }
}

# Example 3: Check file existence (custom logic)
# if (Test-Path "deployment-complete.flag") {
#     Write-Output "COMPLETE"
#     exit 0
# }

# Example 4: Call external API or service
# $status = Invoke-RestMethod "http://localhost:3000/status"
# if ($status.complete -eq $true) {
#     Write-Output "COMPLETE"
#     exit 0
# }

# Default: Continue
Write-Host "⚠️ No completion criteria met" -ForegroundColor Yellow
Write-Output "CONTINUE"
exit 0
