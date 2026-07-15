param(
    [int]$iterationNumber = 1,
    [string]$configFile = "ralph-config.json",
    # === Parallel (swarm) mode — all optional; passing -taskId activates it ===
    [int]$taskId = 0,          # exact task to work on (instead of "first passes:false")
    [string]$workDir = "",     # agent working dir = worktree (sub)dir; overrides project root
    [string]$branch = "",      # git branch the worktree is on (informational, for the prompt)
    [string]$resultFile = "",  # where the agent must write its result JSON (instead of tasks.json/activity.md)
    [int]$agentSlot = 0        # 1-based slot number -> port offsets, labels
)

$isParallel = $taskId -gt 0

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

# Show current task before starting.
# Canonical mode: first passes:false in array order. Parallel mode: the exact -taskId
# assigned by the orchestrator (claiming already happened there - no race here).
if (Test-Path $tasksFile) {
    $allTasks = Get-Content $tasksFile -Raw | ConvertFrom-Json
    if ($isParallel) {
        $currentTask = $allTasks | Where-Object { $_.id -eq $taskId } | Select-Object -First 1
        if (-not $currentTask) {
            Write-Host "[X] Parallel mode: task #$taskId not found in tasks.json!" -ForegroundColor Red
            exit 1
        }
        Write-Host "[i] PARALLEL MODE - agent slot $agentSlot, task #$taskId, branch $branch" -ForegroundColor Magenta
    } else {
        $currentTask = $allTasks | Where-Object { $_.passes -eq $false } | Select-Object -First 1
    }
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

# === Task-specific conditional steps (task-steps.json) ===
# For the CURRENT task, inject ONLY the matching hooks (key == task id => whole task;
# or key like "<id>." => a specific step). No match => nothing is added, so per-task
# requirements do not leak into every other task's prompt.
# NOTE: keep this block ASCII-only. PS 5.1 parses a no-BOM .ps1 as ANSI, so Cyrillic
# literals here break the tokenizer. The Cyrillic CONTENT comes from task-steps.json,
# read with -Encoding UTF8 below.
$taskStepsFile = "task-steps.json"
if ($config -and $config.task_steps -and $config.task_steps.steps_file) {
    $taskStepsFile = $config.task_steps.steps_file
}
if ($currentTask -and (Test-Path $taskStepsFile)) {
    try {
        $taskSteps = Get-Content $taskStepsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($taskSteps.hooks) {
            $tid = "$($currentTask.id)"
            $matched = @()
            foreach ($prop in $taskSteps.hooks.PSObject.Properties) {
                $key = $prop.Name
                if ($key -eq $tid -or $key -like "$tid.*") {
                    foreach ($h in @($prop.Value)) {
                        $meta = @()
                        if ($h.phase)   { $meta += $h.phase }
                        if ($h.at)      { $meta += "at=$($h.at)" }
                        if ($h.PSObject.Properties['blocking'] -and -not $h.blocking) { $meta += "non-blocking" } else { $meta += "BLOCKING" }
                        $metaStr = if ($meta.Count) { " [" + ($meta -join ", ") + "]" } else { "" }
                        $matched += "- **$key$metaStr**: $($h.action)"
                    }
                }
            }
            if ($matched.Count -gt 0) {
                $promptText += "`n`n--- Task-Specific Steps (MANDATORY for task #$tid) ---`n`n"
                $promptText += "This task has extra steps injected by the harness. Execute each at the point named in its 'at' field, IN ADDITION to the steps in tasks.json. A BLOCKING hook must pass before the task may be marked passes:true.`n`n"
                $promptText += ($matched -join "`n")
                Write-Host "[+] Injected $($matched.Count) task-specific step(s) for task #$tid" -ForegroundColor Green
            } else {
                Write-Host "[i] No task-specific steps for task #$tid" -ForegroundColor DarkGray
            }
        }
    } catch {
        Write-Host "[!] Could not parse ${taskStepsFile}: $_" -ForegroundColor Yellow
    }
}

# === PARALLEL MODE override (injected only in swarm runs) ===
# Placed AFTER task-specific steps (it overrides workflow Steps 1/4/5) but BEFORE feedback
# (feedback stays the final word on acceptance). ASCII-only (PS 5.1 ANSI parsing).
if ($isParallel) {
    $fePort = 3000 + $agentSlot
    $vitePort = 5173 + $agentSlot
    $promptText += @"


--- PARALLEL MODE (OVERRIDES Steps 1, 4 and 5 above) ---

You are agent slot $agentSlot in a MULTI-AGENT run. Other agents are working on OTHER tasks in OTHER worktrees at the same time. Your assignment is FIXED:

1. TASK: work ONLY on task #$taskId. Do NOT pick a task yourself. Do NOT touch any other task.
2. WORKDIR: work ONLY inside: $workDir
   This is an isolated git worktree already checked out on branch '$branch'. NEVER edit files outside it (the main repo checkout and other worktrees belong to other agents).
3. GIT: commit on the CURRENT branch only. FORBIDDEN: git checkout/switch/merge/rebase/push/worktree/branch -d. The orchestrator merges your branch later.
4. SCOPE: if the task has a "files" list, treat it as your ownership boundary - modify only files matching it (plus new test files for them). If you believe you must edit something outside the boundary, STOP and report it in the result file instead ("status": "failed", explain in "summary").
5. PORTS: if you need a dev server, use port $vitePort (vite) / $fePort (node) - NOT the defaults - to avoid collisions with other agents. Pass it explicitly (e.g. 'npm run dev -- --port $vitePort').
6. DO NOT edit tasks.json or activity.md (shared files - the orchestrator updates them). INSTEAD, when finished, WRITE EXACTLY this file (UTF-8, valid JSON, no markdown fences):
   $resultFile
   {
     "taskId": $taskId,
     "status": "done",            // or "failed"
     "commit": "<full or short hash of your final commit, empty if none>",
     "testsPassed": true,          // false if anything red
     "summary": "<1-3 sentences: what you did / why it failed>",
     "activity": "<the FULL activity.md entry for this task, markdown, same template as usual>"
   }
7. SETUP: worktrees start WITHOUT untracked build artifacts. If node_modules is missing (FE), run 'npm ci' once before tests. .env files were copied in by the orchestrator when present.
8. Then output the usual <task-complete> XML and STOP. Do not start anything else.
"@
    Write-Host "[+] Injected PARALLEL MODE override (task #$taskId, slot $agentSlot)" -ForegroundColor Magenta
}

# === Iteration-level feedback (feedback.md) — LAST so it has the final word ===
# Injected at the very END of the prompt (recency) so it can set/override the ACCEPTANCE
# CRITERIA: what "done" means for THIS iteration. NOT per-task (task-scoped steps go in
# task-steps.json). HTML comments stripped; skipped if nothing real remains.
# ASCII-only here (PS 5.1 parses no-BOM .ps1 as ANSI); Cyrillic content comes from the file (UTF8).
$feedbackFile = "feedback.md"
$feedbackEnabled = $true
if ($config -and $config.feedback) {
    if ($config.feedback.feedback_file) { $feedbackFile = $config.feedback.feedback_file }
    if ($config.feedback.PSObject.Properties['enabled']) { $feedbackEnabled = $config.feedback.enabled }
}
if ($feedbackEnabled -and (Test-Path $feedbackFile)) {
    $fbRaw = Get-Content $feedbackFile -Raw -Encoding UTF8
    $fbStripped = ($fbRaw -replace '(?s)<!--.*?-->', '').Trim()
    if ($fbStripped.Length -gt 0) {
        $promptText += "`n`n--- Feedback & Acceptance Criteria (FINAL WORD for THIS iteration) ---`n`n"
        $promptText += "Highest priority. Defines when THIS iteration is DONE. If it conflicts with anything above, THIS wins.`n`n"
        $promptText += $fbStripped
        Write-Host "[+] Injected iteration feedback ($($fbStripped.Length) chars) [LAST]" -ForegroundColor Green
    } else {
        Write-Host "[i] feedback.md has no active feedback - nothing injected" -ForegroundColor DarkGray
    }
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

# Working directory: canonical mode = project root (Claude navigates to repos via prerequisite);
# parallel mode = the agent's isolated worktree (sub)dir.
$agentWorkDir = if ($isParallel -and $workDir) { $workDir } else { $bdzProject }
Write-Host "[i] Working dir: $agentWorkDir" -ForegroundColor Cyan

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
} -ArgumentList $tempPrompt, $outputFile, $model, $agentWorkDir

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
    # In parallel mode, only reap runners spawned from OUR worktree - a blanket kill would
    # murder the vitest/playwright of the OTHER agents running concurrently.
    $reapScope = if ($isParallel -and $workDir) { [regex]::Escape($workDir) } else { $null }
    Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'vitest|playwright' -and (-not $reapScope -or $_.CommandLine -match $reapScope) } |
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

# === Parallel mode: success = the agent produced its result file (orchestrator merges &
# updates tasks.json). Skip the shared tasks.json completion count entirely. ===
if ($isParallel) {
    Write-Host ""
    if ($resultFile -and (Test-Path $resultFile)) {
        try {
            $res = Get-Content $resultFile -Raw -Encoding UTF8 | ConvertFrom-Json
            Write-Host "[+] Result file written: status=$($res.status), commit=$($res.commit)" -ForegroundColor Green
            exit 0
        } catch {
            Write-Host "[!] Result file exists but is not valid JSON: $_" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "[!] Agent finished WITHOUT writing the result file - treating as failed." -ForegroundColor Yellow
        exit 1
    }
}

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
