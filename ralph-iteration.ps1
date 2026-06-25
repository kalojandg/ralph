param(
    [int]$iterationNumber = 1,
    [string]$configFile = "ralph-config.json"
)

# Setup paths — ralph lives in C:\Users\kaloyan.georgiev\Projects\ralph\, project is C:\Users\kaloyan.georgiev\Projects\
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$bdzProject = "C:\Users\kaloyan.georgiev\Projects"
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
$model = "claude-opus-4-8"
if ($config -and $config.claude_args) {
    $modelIndex = [array]::IndexOf($config.claude_args, "--model")
    if ($modelIndex -ge 0 -and $modelIndex -lt $config.claude_args.Count - 1) {
        $model = $config.claude_args[$modelIndex + 1]
    }
}

Write-Host "[i] Iteration $iterationNumber starting..." -ForegroundColor Cyan
Write-Host "[i] Model: $model" -ForegroundColor Cyan

# Show current task before starting
if (Test-Path $tasksFile) {
    $allTasks = Get-Content $tasksFile -Raw | ConvertFrom-Json
    $currentTask = $allTasks | Where-Object { $_.passes -eq $false } | Select-Object -First 1
    if ($currentTask) {
        $repo = if ($currentTask.repo) { $currentTask.repo } else { "frontend" }
        Write-Host "[>] Task #$($currentTask.id): $($currentTask.description)" -ForegroundColor Green
        Write-Host "[>] Repo: $repo" -ForegroundColor Green
        if ($currentTask.migrationRef) {
            Write-Host "[>] Migration: $($currentTask.migrationRef)" -ForegroundColor Green
        }
    } else {
        Write-Host "[+] No pending tasks!" -ForegroundColor Green
    }
}

# Build prompt from PROMPT.md and user-steps.md
$promptText = ""

# Get prompt file from config or use default
$promptFile = "PROMPT.md"
if ($config -and $config.prompt_file) {
    $promptFile = $config.prompt_file
}

if (Test-Path $promptFile) {
    $promptText = Get-Content $promptFile -Raw
    Write-Host "[+] Loaded: $promptFile" -ForegroundColor Green
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

# Working directory is the BDZ Project root — Claude navigates to specific repos via prerequisite
Write-Host "[i] Working dir: $bdzProject" -ForegroundColor Cyan

# Start claude in background and monitor
$job = Start-Job -ScriptBlock {
    param($prompt, $output, $modelName, $workDir)
    Set-Location $workDir
    # --verbose --output-format stream-json => claude streams an NDJSON event per step,
    # so $output grows continuously while it works. WITHOUT this, `claude -p` (text) buffers
    # ALL output until the very end => the file stays 0 bytes the whole run => the
    # "No output growth for 60 min" watchdog FALSE-kills any iteration that takes >60 min.
    # Substring completion checks ("<promise>COMPLETE</promise>", "hit your limit") still match
    # because those literals appear inside the JSON text events.
    & claude -p "@$prompt" --model $modelName --dangerously-skip-permissions --verbose --output-format stream-json 2>&1 | Out-File -FilePath $output -Encoding UTF8
} -ArgumentList $tempPrompt, $outputFile, $model, $bdzProject

# Show spinner while waiting
$spinChars = @('|', '/', '-', '\')
$spinIndex = 0
$lastSize = 0
$startTime = Get-Date
$lastGrowth = Get-Date
$maxIterationMinutes = 180
$maxStaleMinutes = 60
$timedOut = $false
$timeoutReason = ""

Write-Host -NoNewline "Working "
while ($job.State -eq 'Running') {
    Write-Host -NoNewline "`rWorking $($spinChars[$spinIndex]) "
    $spinIndex = ($spinIndex + 1) % 4

    # Hard timeout — runaway iteration
    if (((Get-Date) - $startTime).TotalMinutes -gt $maxIterationMinutes) {
        $timedOut = $true
        $timeoutReason = "Max iteration time ($maxIterationMinutes min) exceeded"
        break
    }

    # Check if output file is growing
    if (Test-Path $outputFile) {
        $size = (Get-Item $outputFile).Length
        if ($size -gt $lastSize) {
            $lastSize = $size
            $lastGrowth = Get-Date
            Write-Host -NoNewline "(${size} bytes) "
        } elseif (((Get-Date) - $lastGrowth).TotalMinutes -gt $maxStaleMinutes) {
            $timedOut = $true
            $timeoutReason = "No output growth for $maxStaleMinutes min (claude likely hung)"
            break
        }

        # Completion detection (critical for unattended/overnight runs):
        # claude -p --output-format stream-json emits a final "result" event carrying
        # "terminal_reason" when the iteration is done. Break on it directly — a background
        # process the agent left running (dev server / watch / vitest) can hold the PS job's
        # stdout pipe open so $job.State NEVER leaves 'Running'. Without this, the loop would
        # spin until the 60-min stale timeout (or Wait-Job would block forever) and the wrapper
        # would never advance to the next task.
        if ($size -gt 0) {
            $tail = Get-Content $outputFile -Tail 3 -ErrorAction SilentlyContinue
            if ($tail -match '"terminal_reason"') { break }
        }
    }

    Start-Sleep -Milliseconds 500
}

if ($timedOut) {
    Write-Host ""
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "   [X] ITERATION TIMED OUT" -ForegroundColor Red
    Write-Host "   Reason: $timeoutReason" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red

    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue

    # Save partial output as log so wrapper does not count this as silent failure
    if (Test-Path $outputFile) {
        $logDir = "logs"
        if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $logFile = "$logDir/iteration-$iterationNumber-$timestamp-TIMEOUT.txt"
        $partial = Get-Content $outputFile -Raw -ErrorAction SilentlyContinue
        "TIMEOUT: $timeoutReason`n`n=== Partial output ===`n$partial" | Out-File -FilePath $logFile -Encoding UTF8
        Write-Host "[+] Partial log saved: $logFile" -ForegroundColor Yellow
        Remove-Item $outputFile -ErrorAction SilentlyContinue
    }
    Remove-Item $tempPrompt -ErrorAction SilentlyContinue
    exit 3
}

# Iteration finished (claude emitted its terminal "result" event). The PS job may still
# report 'Running' if the agent left a background process holding the stdout pipe open — do
# NOT Wait-Job (it would block forever). Force-stop it, then reap stray test runners the agent
# may have spawned so they don't accumulate across iterations (overnight runs). NOTE: only
# vitest/playwright are reaped — a `vite` dev server is left alone (could be the user's).
Stop-Job $job -ErrorAction SilentlyContinue
Remove-Job $job -Force -ErrorAction SilentlyContinue
try {
    Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'vitest|playwright' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
} catch {}

Write-Host ""
Write-Host ""

# Read and display output
if (Test-Path $outputFile) {
    $result = Get-Content $outputFile -Raw

    # --output-format stream-json dumps an NDJSON event per step (needed so the file grows and
    # the watchdog can see progress) — but that JSON is unreadable in the console/log. Extract
    # just the human-readable assistant text + final result for display/logging. $result (raw)
    # is kept for the substring quota/pattern checks below.
    $display = $result
    try {
        $clean = foreach ($line in (Get-Content $outputFile)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try { $o = $line | ConvertFrom-Json } catch { continue }
            if ($o.type -eq 'assistant' -and $o.message.content) {
                foreach ($c in $o.message.content) {
                    if ($c.type -eq 'text' -and $c.text) { $c.text }
                }
            } elseif ($o.type -eq 'result' -and $o.result) {
                $o.result
            }
        }
        if ($clean) { $display = ($clean -join "`n`n") }
    } catch {}

    # === QUOTA DETECTION ===
    # Pattern: "You've hit your limit · resets 7pm (Europe/Sofia)"
    if ($result -match "hit your limit") {
        $waitMinutes = 60  # default fallback: wait 1 hour

        if ($result -match "resets\s+(\d{1,2})(am|pm)\s*\(([^)]+)\)") {
            $resetHour = [int]$Matches[1]
            $ampm = $Matches[2]
            $tz = $Matches[3]

            # Convert to 24h
            if ($ampm -eq "pm" -and $resetHour -ne 12) { $resetHour += 12 }
            if ($ampm -eq "am" -and $resetHour -eq 12) { $resetHour = 0 }

            $now = Get-Date
            $resetTime = Get-Date -Hour $resetHour -Minute 0 -Second 0
            # If reset time is in the past, it means tomorrow
            if ($resetTime -le $now) { $resetTime = $resetTime.AddDays(1) }

            $waitMinutes = [math]::Ceiling(($resetTime - $now).TotalMinutes)
        }

        # Add 2 min buffer, minimum 5 min
        $waitMinutes = [math]::Max(5, $waitMinutes + 2)

        Write-Host ""
        Write-Host "============================================" -ForegroundColor Red
        Write-Host "   QUOTA EXCEEDED" -ForegroundColor Red
        Write-Host "   Resets at: ${resetHour}:00 ($tz)" -ForegroundColor Red
        Write-Host "   Waiting $waitMinutes minutes..." -ForegroundColor Red
        Write-Host "============================================" -ForegroundColor Red
        Write-Host ""

        # Save log
        $logDir = "logs"
        if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $logFile = "$logDir/iteration-$iterationNumber-$timestamp.txt"
        "QUOTA EXCEEDED - waiting until $resetTime" | Out-File -FilePath $logFile -Encoding UTF8

        # Wait loop — print status every 5 minutes
        $waited = 0
        while ($waited -lt $waitMinutes) {
            $remaining = $waitMinutes - $waited
            $resumeAt = (Get-Date).AddMinutes($remaining).ToString("HH:mm")
            Write-Host "[$(Get-Date -Format 'HH:mm')] Waiting $remaining more minutes (resume at ~$resumeAt)..." -ForegroundColor Yellow
            $sleepChunk = [math]::Min(5, $remaining)
            Start-Sleep -Seconds ($sleepChunk * 60)
            $waited += $sleepChunk
        }

        Write-Host ""
        Write-Host "[+] Quota should be reset. Resuming..." -ForegroundColor Green
        Write-Host ""

        # Cleanup and retry this iteration (exit 2 = retry signal)
        Remove-Item $outputFile -ErrorAction SilentlyContinue
        Remove-Item $tempPrompt -ErrorAction SilentlyContinue
        exit 2
    }

    # === NORMAL OUTPUT ===
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "   CLAUDE OUTPUT:" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host $display
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Yellow

    # Save to log
    $logDir = "logs"
    if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logFile = "$logDir/iteration-$iterationNumber-$timestamp.txt"
    $display | Out-File -FilePath $logFile -Encoding UTF8
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
