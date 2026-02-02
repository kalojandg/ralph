param(
    [Parameter(Mandatory=$true)]
    [int]$iterations
)

if ($iterations -le 0) {
    Write-Host "Usage: .\ralph.ps1 <iterations>"
    exit 1
}

for ($i = 1; $i -le $iterations; $i++) {
    Write-Host "Iteration $i"
    Write-Host "--------------------------------"
    
    try {
        $promptContent = Get-Content -Path "PROMPT.md" -Raw
        $result = & claude -p $promptContent --output-format text 2>&1 | Out-String
    } catch {
        $result = $_.Exception.Message
    }
    
    Write-Host $result
    
    if ($result -match "<promise>COMPLETE</promise>") {
        Write-Host "All tasks complete after $i iterations."
        exit 0
    }
    
    Write-Host ""
    Write-Host "--- End of iteration $i ---"
    Write-Host ""
}

Write-Host "Reached max iterations ($iterations)"
exit 1
