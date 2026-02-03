param(
    [Parameter(Mandatory=$true)]
    [string]$result
)

# Check for completion promise
if ($result -match '<promise>COMPLETE</promise>') {
    Write-Output "COMPLETE"
    exit 0
}

# Check if tasks.json exists and all tasks have passes: true
$tasksFile = "docs/composition/tasks.json"
if (Test-Path $tasksFile) {
    try {
        $tasks = Get-Content $tasksFile -Raw | ConvertFrom-Json
        
        # Count total tasks
        $totalTasks = $tasks.Count
        
        # Count completed tasks (passes: true)
        $completedTasks = ($tasks | Where-Object { $_.passes -eq $true }).Count
        
        Write-Host "Progress: $completedTasks / $totalTasks tasks complete" -ForegroundColor Cyan
        
        # If all tasks complete
        if ($completedTasks -eq $totalTasks) {
            Write-Host "✓ All tasks marked as passes: true!" -ForegroundColor Green
            Write-Output "COMPLETE"
            exit 0
        }
        
        # Find next incomplete task
        $nextTask = $tasks | Where-Object { $_.passes -eq $false } | Select-Object -First 1
        if ($nextTask) {
            Write-Host "Next task: #$($nextTask.id) - $($nextTask.description)" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "⚠️ Error reading tasks.json: $_" -ForegroundColor Yellow
    }
}

# Check for task-complete XML tag
if ($result -match '<task-complete>') {
    Write-Host "✓ Task completed in this iteration" -ForegroundColor Green
}

# Check for status tags
if ($result -match '<status>CONTINUE</status>') {
    Write-Host "Status: CONTINUE - more tasks remaining" -ForegroundColor Cyan
}

# Not complete - continue iterations
Write-Output "CONTINUE"
exit 1
