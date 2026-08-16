# =====================================================================================
# Ralph SWARM - multi-agent orchestrator (parallel Ralph Wiggum over git worktrees)
#
# Canonical Ralph = 1 agent, 1 task, clean context.  Swarm = N canonical Ralphs at once,
# each in an ISOLATED git worktree on its own branch, coordinated by THIS single-writer
# orchestrator (task board pattern):
#   - picks eligible tasks (lane free + dependsOn satisfied), claims them atomically
#   - creates a worktree + branch per task, spawns ralph-iteration.ps1 -taskId ... per agent
#   - agents NEVER touch tasks.json/activity.md; they write results\task-<id>.json
#   - orchestrator merges finished branches back into the integration branch SEQUENTIALLY,
#     updates tasks.json (single writer), prepends activity.md, cleans up the worktree
#   - rolling pipeline: as soon as a slot frees up, the next eligible task starts
#
# NOTE: ASCII-only in this file (PS 5.1 parses no-BOM .ps1 as ANSI; Cyrillic breaks it).
# =====================================================================================
param(
    [int]$agents = 0,             # 0 = take from config (swarm.agents), fallback 3
    [int]$maxTasks = 0,           # stop after N completed tasks (0 = run until done/blocked)
    [string]$configFile = "ralph-config.json",
    [string]$worktreeRoot = "",   # default: <parent-of-ralph>\.ralph-worktrees
    [switch]$keepWindows,         # keep each agent's console window open after it finishes
    [ValidateSet("Normal","Minimized","Hidden")]
    [string]$agentWindows = ""    # agent console style: Normal (popup), Minimized (taskbar only), Hidden (no console - logs only)
)

$ErrorActionPreference = 'Continue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# ---------------------------------------------------------------- preflight
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudeCmd) { Write-Host "[X] FATAL: 'claude' CLI not found on PATH" -ForegroundColor Red; exit 1 }
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) { Write-Host "[X] FATAL: 'git' not found on PATH" -ForegroundColor Red; exit 1 }

$config = $null
if (Test-Path $configFile) { $config = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json }

if ($agents -le 0) {
    $agents = 3
    if ($config -and $config.swarm -and $config.swarm.agents) { $agents = [int]$config.swarm.agents }
}
if (-not $worktreeRoot) {
    if ($config -and $config.swarm -and $config.swarm.worktree_root) { $worktreeRoot = $config.swarm.worktree_root }
    else { $worktreeRoot = Join-Path (Split-Path -Parent $scriptDir) ".ralph-worktrees" }
}
if (-not $PSBoundParameters.ContainsKey('keepWindows')) {
    if ($config -and $config.swarm -and $config.swarm.PSObject.Properties['keep_windows'] -and $config.swarm.keep_windows) {
        $keepWindows = $true
    }
}
if (-not $agentWindows) {
    $agentWindows = "Normal"
    if ($config -and $config.swarm -and $config.swarm.PSObject.Properties['window_style'] -and $config.swarm.window_style) {
        $agentWindows = $config.swarm.window_style
    }
}

# Retry budgets (unattended autonomy): a watchdog-killed (timeout/stale) task and a truly
# failed task are re-queued a BOUNDED number of times instead of blocking their lane for
# the whole session. Failed retries are INFORMED - see Save-RetryContext below.
$maxTimeoutRequeues = 2
$maxFailRetries = 2
if ($config -and $config.swarm) {
    if ($config.swarm.PSObject.Properties['max_timeout_requeues']) { $maxTimeoutRequeues = [int]$config.swarm.max_timeout_requeues }
    if ($config.swarm.PSObject.Properties['max_fail_retries'])     { $maxFailRetries     = [int]$config.swarm.max_fail_retries }
}

# Post-merge verification gate: after every successful merge, run the repo's `verify`
# commands (repos.json) in the MAIN checkout, i.e. on the freshly merged integration
# branch. Two branches that were each green in isolation can still break each other
# (semantic conflict - no textual conflict, broken logic); this gate is the only place
# that catches it. RED -> the merge is undone and the task goes through informed retry.
$verifyEnabled = $true
$verifyTimeoutMin = 20
if ($config -and $config.swarm) {
    if ($config.swarm.PSObject.Properties['verify_enabled'])     { $verifyEnabled    = [bool]$config.swarm.verify_enabled }
    if ($config.swarm.PSObject.Properties['verify_timeout_min']) { $verifyTimeoutMin = [int]$config.swarm.verify_timeout_min }
}

# Scope escalation: after this many consumed fail-retries, the next attempt gets
# -retryMode escalate - the files boundary is LIFTED for gate-diagnosed failures, so the
# agent may surgically fix out-of-scope tests/code instead of stalling until a human steps
# in (the #33/#34 pattern: agent sees the fix, discipline forbids it, budget burns).
$escalateAfter = 2
if ($config -and $config.swarm -and $config.swarm.PSObject.Properties['escalate_after']) {
    $escalateAfter = [int]$config.swarm.escalate_after
}

# Finishing step (runs ONLY on ALL TASKS COMPLETE - i.e. every merge passed the gate):
# finish_docs -> spawn one docs agent per touched repo to refresh the structure reference
# and the repo's own docs; finish_push -> git push every touched repo + the ralph repo.
# Full-success only: partially failed boards stay local for human review.
$finishDocs = $true
$finishPush = $true
$finishReview = $true
$finishIndex = $true
$reviewCycles = 2
$reviewDirBase = "C:\CodeReview"
if ($config -and $config.swarm) {
    if ($config.swarm.PSObject.Properties['finish_docs']) { $finishDocs = [bool]$config.swarm.finish_docs }
    if ($config.swarm.PSObject.Properties['finish_push']) { $finishPush = [bool]$config.swarm.finish_push }
    if ($config.swarm.PSObject.Properties['finish_review']) { $finishReview = [bool]$config.swarm.finish_review }
    if ($config.swarm.PSObject.Properties['finish_index']) { $finishIndex = [bool]$config.swarm.finish_index }
    if ($config.swarm.PSObject.Properties['finish_review_cycles']) { $reviewCycles = [int]$config.swarm.finish_review_cycles }
    if ($config.swarm.PSObject.Properties['review_dir']) { $reviewDirBase = $config.swarm.review_dir }
}
$agentModel = "claude-opus-5"
if ($config -and $config.claude_args) {
    $mi = [array]::IndexOf($config.claude_args, "--model")
    if ($mi -ge 0 -and $mi -lt $config.claude_args.Count - 1) { $agentModel = $config.claude_args[$mi + 1] }
}
$useApiKeyCfg = $false
if ($config -and $config.PSObject.Properties['use_api_key']) { $useApiKeyCfg = [bool]$config.use_api_key }

$tasksFile  = Join-Path $scriptDir "tasks.json"
$reposFile  = Join-Path $scriptDir "ralph reference\project reference\repos.json"
$claimsDir  = Join-Path $scriptDir "claims"
$resultsDir = Join-Path $scriptDir "results"
$retryDir   = Join-Path $scriptDir "retry"

if (-not (Test-Path $tasksFile)) { Write-Host "[X] tasks.json not found" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $reposFile)) { Write-Host "[X] repos.json not found ($reposFile)" -ForegroundColor Red; exit 1 }
$reposMap = Get-Content $reposFile -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($d in @($claimsDir, $resultsDir, $worktreeRoot, $retryDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}
# stale claims are from a previous session - this orchestrator is the only claimer, so reset
Remove-Item (Join-Path $claimsDir "*.claim") -Force -ErrorAction SilentlyContinue
# retry context outlives sessions ON PURPOSE (a new run retries informed, not blind), but a
# task completed OUTSIDE the swarm (manual conflict resolve + passes:true by hand) must not
# keep one around - sweep retry files whose task is already done
$doneNow = @((Get-Content $tasksFile -Raw -Encoding UTF8 | ConvertFrom-Json) |
             Where-Object { $_.passes -eq $true } | ForEach-Object { $_.id })
Get-ChildItem $retryDir -Filter "task-*.md" -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.BaseName -match '^task-(\d+)$' -and ($doneNow -contains [int]$Matches[1])) {
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   Ralph SWARM - parallel agents over worktrees"      -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "Agents (slots) : $agents"       -ForegroundColor White
Write-Host "Max tasks      : $(if ($maxTasks -gt 0) { $maxTasks } else { 'until done' })" -ForegroundColor White
Write-Host "Worktree root  : $worktreeRoot" -ForegroundColor White
Write-Host "Retry budgets  : timeout x$maxTimeoutRequeues, fail x$maxFailRetries (per task)" -ForegroundColor White
Write-Host "Verify gate    : $(if ($verifyEnabled) { "ON - repos.json 'verify' commands, timeout ${verifyTimeoutMin}m/cmd" } else { 'OFF' })" -ForegroundColor White
Write-Host ""

# ---------------------------------------------------------------- helpers
function Read-Tasks {
    return @(Get-Content $tasksFile -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-LaneKey($t) {
    if ($t.PSObject.Properties['lane'] -and $t.lane) { return "$($t.lane)" }
    return "task-$($t.id)"   # no lane declared -> its own lane (independent)
}

function Try-Claim($id) {
    $f = Join-Path $claimsDir "task-$id.claim"
    try {
        $fs = [System.IO.File]::Open($f, [System.IO.FileMode]::CreateNew)
        $fs.Close()
        return $true
    } catch { return $false }
}

function Release-Claim($id) {
    Remove-Item (Join-Path $claimsDir "task-$id.claim") -Force -ErrorAction SilentlyContinue
}

# Newest agent log for a task. Agents log to logs\iteration-<taskId>-<timestamp>[-TIMEOUT].txt
# (iterationNumber = task id in swarm mode), so the tail of the newest match is what the
# failed attempt was doing when it died.
function Get-AgentLogTail($taskId, $lines = 60) {
    $latest = Get-ChildItem (Join-Path $scriptDir "logs") -Filter "iteration-$taskId-*.txt" -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) { return "(no agent log found)" }
    return ((Get-Content $latest.FullName -Tail $lines -ErrorAction SilentlyContinue) -join "`n")
}

# Append a failure report to retry\task-<id>.md. Start-AgentForTask hands this file to the
# NEXT attempt via -retryFile, so the retry is INFORMED (sees why the last attempt failed)
# instead of blind. The file survives across sessions and is deleted only when the task
# finally merges - no stale context can leak into an already-completed task.
function Save-RetryContext($taskId, $attempt, $why) {
    $fence = '```'
    $tail = Get-AgentLogTail $taskId 60
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $block = "## Attempt at $stamp - FAILED (retry $attempt)`n`nReason: $why`n`n### Tail of the failed agent's log`n$fence`n$tail`n$fence`n"
    $f = Join-Path $retryDir "task-$taskId.md"
    if (Test-Path $f) {
        $block = (Get-Content $f -Raw -Encoding UTF8).TrimEnd() + "`n`n" + $block
    }
    $block | Out-File $f -Encoding UTF8
}

# Post-merge verification gate. Runs the task's repo `verify` commands (repos.json) in the
# repo's MAIN working dir (location), which at call time sits on the just-merged integration
# branch. Returns $null when green (or when no gate is configured for the repo), otherwise a
# failure report string that goes into the retry context. Runs in the orchestrator, so merges
# stay strictly sequential - the next merge only happens onto a VERIFIED-green branch.
# NOTE: verify commands must not leave untracked files behind (gitignore build artifacts),
# or every later merge gets skipped as "dirty".
function Invoke-VerifyGate($task) {
    if (-not $verifyEnabled) { return $null }
    $rKey = "frontend"
    if ($task.PSObject.Properties['repo'] -and $task.repo) { $rKey = $task.repo }
    $r = $reposMap.repos.$rKey
    if (-not $r) { return $null }
    # Per-task override: a task may carry its own `verify` array (targeted spec subset for
    # cheap merges); tasks without it use the repo-wide gate. Empty task array = no gate.
    $cmds = $null
    if ($task.PSObject.Properties['verify'] -and $null -ne $task.verify) { $cmds = @($task.verify) }
    elseif ($r.PSObject.Properties['verify'] -and $r.verify) { $cmds = @($r.verify) }
    if (-not $cmds -or $cmds.Count -eq 0) { return $null }
    foreach ($cmd in $cmds) {
        Write-Host "[v] Task #$($task.id): verify gate ($rKey): $cmd" -ForegroundColor Cyan
        $job = Start-Job -ScriptBlock {
            param($dir, $c)
            Set-Location $dir
            $o = & cmd /c $c 2>&1 | Out-String
            [pscustomobject]@{ out = $o; code = $LASTEXITCODE }
        } -ArgumentList $r.location, $cmd
        $done = Wait-Job $job -Timeout ($verifyTimeoutMin * 60)
        if (-not $done) {
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            return "VERIFY GATE TIMEOUT: '$cmd' did not finish in $verifyTimeoutMin min on the integration branch after merging this task. Treated as RED."
        }
        $res = Receive-Job $job
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        if ($res.code -ne 0) {
            $tailLines = (($res.out -split "`r?`n") | Select-Object -Last 60) -join "`n"
            return "VERIFY GATE RED: '$cmd' exited $($res.code) on the integration branch AFTER merging this task. Your changes passed in isolation but break the integrated state (or vice versa).`n--- last verify output ---`n$tailLines"
        }
    }
    Write-Host "[v] Task #$($task.id): verify gate GREEN" -ForegroundColor Green
    return $null
}

# REVIEW STAGE (part of finishing): review -> fix -> re-review, per touched repo.
# Acceptance: ZERO blockers AND ZERO important findings (recommendations are allowed).
# Runs claude agents synchronously in the MAIN checkout (swarm is done - exclusive).
# Fix commits must survive the repo's FULL verify gate, else they are rolled back.
# Returns $true when every repo passes; $false aborts docs/push for human attention.
function Invoke-ReviewStage($tasks, $repoKeys) {
    $template = Get-Content (Join-Path $scriptDir "ralph reference\review-prompt-template.md") -Raw -Encoding UTF8
    $taskList = ($tasks | ForEach-Object { "  #$($_.id) [$($_.repo)] $($_.description)" }) -join "`n"
    $taskIds = ($tasks | ForEach-Object { $_.id }) -join ","
    $allPass = $true
    foreach ($k in $repoKeys) {
        $r = $reposMap.repos.$k
        if (-not $r) { continue }
        $startSha = $script:startShas[$r.gitRoot]
        $headSha = (& git -C $r.gitRoot rev-parse HEAD 2>$null)
        if (-not $startSha -or $startSha -eq $headSha) {
            Write-Host "[r] Repo '$k': no changes this run - review skipped" -ForegroundColor DarkGray
            continue
        }
        $range = "$startSha..HEAD"
        $outDir = Join-Path $reviewDirBase $k
        if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
        $refPath = Join-Path (Join-Path $scriptDir "ralph reference\project reference") $r.reference
        # Rules resolution: a rules/ folder IN THE REPO wins (out-of-the-box on any repo,
        # e.g. an employer's); the ralph structure reference is the fallback rulebook.
        $rulesDir = Join-Path $r.location "rules"
        $hasRules = (Test-Path $rulesDir) -and (@(Get-ChildItem $rulesDir -File -ErrorAction SilentlyContinue).Count -gt 0)
        if ($hasRules) {
            $rulesInstr = "The repo has a 'rules' folder at '$rulesDir' - READ EVERY file in it; those are the BINDING review rules. Also consult the architecture reference at '$refPath' for repo-specific red lines."
        } else {
            $rulesInstr = "The rulebook is the architecture reference at '$refPath' - read it fully and evaluate against it (especially the red lines and review criteria sections)."
        }
        $repoPass = $false
        for ($cycle = 1; $cycle -le ($reviewCycles + 1); $cycle++) {
            $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
            $verdictPath = Join-Path $outDir "verdict.json"
            Remove-Item $verdictPath -Force -ErrorAction SilentlyContinue
            $prompt = $template.Replace("{{REPO_NAME}}", $k).Replace("{{REPO_DESC}}", "$($r.description)").
                Replace("{{REPO_PATH}}", $r.location).Replace("{{RANGE}}", $range).
                Replace("{{RULES_INSTRUCTION}}", $rulesInstr).Replace("{{TASK_LIST}}", $taskList).
                Replace("{{TASK_IDS}}", $taskIds).Replace("{{OUT_DIR}}", $outDir).Replace("{{STAMP}}", "$stamp-cycle$cycle")
            $tempP = Join-Path $env:TEMP "ralph-review-$k.txt"
            $prompt | Out-File $tempP -Encoding UTF8
            Write-Host "[r] Repo '$k': review cycle $cycle (timeout 20 min)..." -ForegroundColor Cyan
            $job = Start-Job -ScriptBlock {
                param($dir, $pf, $model, $useKey)
                Set-Location $dir
                if (-not $useKey) { Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue }
                & claude -p "@$pf" --model $model --dangerously-skip-permissions 2>&1 | Out-String
            } -ArgumentList $r.location, $tempP, $agentModel, $useApiKeyCfg
            $done = Wait-Job $job -Timeout 1200
            if ($done) { Receive-Job $job | Out-String | Out-File (Join-Path $scriptDir "logs\review-$k-cycle$cycle-$stamp.txt") -Encoding UTF8 }
            else { Stop-Job $job -ErrorAction SilentlyContinue }
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            Remove-Item $tempP -ErrorAction SilentlyContinue
            $verdict = $null
            if (Test-Path $verdictPath) {
                try { $verdict = Get-Content $verdictPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
            }
            if (-not $verdict) {
                Write-Host "[!] Repo '$k': no valid verdict.json from reviewer - treating as FAILED review" -ForegroundColor Yellow
                break
            }
            $bad = [int]$verdict.blockers + [int]$verdict.important
            Write-Host "[r] Repo '$k' cycle ${cycle}: blockers=$($verdict.blockers) important=$($verdict.important) recommendations=$($verdict.recommendations)" -ForegroundColor $(if ($bad -eq 0) { 'Green' } else { 'Yellow' })
            if ($bad -eq 0) { $repoPass = $true; break }
            if ($cycle -gt $reviewCycles) { break }
            # ---- FIX cycle: one agent addresses blockers+important, then must survive the gate
            $preFixSha = (& git -C $r.gitRoot rev-parse HEAD 2>$null)
            $fixPrompt = "You are the FIX agent after a code review. Read the newest CODE-REVIEW-*.md in '$outDir' (cycle $cycle). Fix ONLY the items listed under the Blockers (must fix) and Important (should fix) sections - surgically, nothing else. $rulesInstr You may run the repo's unit tests if any; do NOT run e2e/servers. Commit your fixes in '$($r.location)' with message 'fix: address code review findings (board $taskIds, cycle $cycle)'. If a finding is WRONG (the reviewer misread the code), do not change code for it - instead append a short justification section at the bottom of the review file explaining why, so the next review cycle can account for it."
            $tempF = Join-Path $env:TEMP "ralph-reviewfix-$k.txt"
            $fixPrompt | Out-File $tempF -Encoding UTF8
            Write-Host "[r] Repo '$k': fix cycle $cycle (timeout 25 min)..." -ForegroundColor Cyan
            $job = Start-Job -ScriptBlock {
                param($dir, $pf, $model, $useKey)
                Set-Location $dir
                if (-not $useKey) { Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue }
                & claude -p "@$pf" --model $model --dangerously-skip-permissions 2>&1 | Out-String
            } -ArgumentList $r.location, $tempF, $agentModel, $useApiKeyCfg
            $done = Wait-Job $job -Timeout 1500
            if ($done) { Receive-Job $job | Out-String | Out-File (Join-Path $scriptDir "logs\reviewfix-$k-cycle$cycle-$stamp.txt") -Encoding UTF8 }
            else { Stop-Job $job -ErrorAction SilentlyContinue }
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            Remove-Item $tempF -ErrorAction SilentlyContinue
            # fixes must keep the repo green: run the FULL repo gate; red -> roll back fixes
            $gateErr = Invoke-VerifyGate ([pscustomobject]@{ id = 0; repo = $k })
            if ($gateErr) {
                & git -C $r.gitRoot reset --hard $preFixSha 2>&1 | Out-Null
                Write-Host "[!] Repo '$k': fix cycle $cycle broke the gate - fixes ROLLED BACK. Review stage failed." -ForegroundColor Red
                break
            }
        }
        if (-not $repoPass) { $allPass = $false }
    }
    return $allPass
}

# FINISHING STEP - runs only when every task on the board is passes:true (all merges
# survived the gate, so the integration branches are verified green = safe to publish).
# 1) finish_docs: one docs agent per touched repo refreshes the ralph structure reference
#    and the repo's own docs (README/behavior docs) to match what the board changed.
# 2) finish_push: git push each touched repo + the ralph repo itself (board/activity/refs).
# Failures here are WARNINGS - the board result is already safe locally.
function Invoke-FinishingStep {
    $t = Read-Tasks
    $repoKeys = @($t | ForEach-Object { $_.repo } | Where-Object { $_ } | Select-Object -Unique)
    if ($repoKeys.Count -eq 0) { return }
    Write-Host ""
    Write-Host "==================== FINISHING STEP ====================" -ForegroundColor Cyan

    if ($finishReview) {
        $reviewOk = Invoke-ReviewStage $t $repoKeys
        if (-not $reviewOk) {
            Write-Host "[X] FINISHING ABORTED: review acceptance not met (blockers/important remain or reviewer failed)." -ForegroundColor Red
            Write-Host "    Reports: $reviewDirBase\<repo>. Fix manually (or re-run) - docs/push were NOT executed." -ForegroundColor Red
            Write-Host "========================================================" -ForegroundColor Cyan
            return
        }
    }

    if ($finishDocs) {
        $taskList = ($t | ForEach-Object { "#$($_.id) [$($_.repo)] $($_.description)" }) -join "`n"
        foreach ($k in $repoKeys) {
            $r = $reposMap.repos.$k
            if (-not $r) { continue }
            $refPath = Join-Path (Join-Path $scriptDir "ralph reference\project reference") $r.reference
            $prompt = @"
You are the FINISHING agent after a completed Ralph board. Every task below is merged into
'$($r.mainBranch)' and the verify gate kept it green. Your job is DOCUMENTATION ONLY.

Completed board:
$taskList

Working repo: $($r.location) (you are IN it; the integration branch is checked out and clean).

Do, in this order:
1. Inspect what changed: git log --oneline -30 and the diffs of the ralph merge commits.
2. Update the architecture reference file at:
   $refPath
   so it matches the NEW reality: file map, modules/tabs/services inventory, persistence
   model, test state (spec list/counts), red lines. Keep its existing structure and language
   (Bulgarian) - update stale facts, add new sections only where the board introduced
   something new. Do NOT rewrite style.
3. Update this repo's own human docs IF the board changed behavior they describe
   (README, BEHAVIOR_DOCUMENTATION.md, TEST_CASES.md or equivalents). Skip if untouched.
4. Commit doc changes IN EACH repo you edited (the ralph repo for the reference file, this
   repo for its docs) with message: "docs: refresh after ralph board (tasks $(($t | ForEach-Object { $_.id }) -join ','))".
5. STRICT limits: touch ONLY documentation files. NO code, NO tests, NO configs, NO git push
   (the orchestrator pushes), NO servers/e2e. If nothing is stale, say so and commit nothing.
"@
            $tempP = Join-Path $env:TEMP "ralph-finishing-$k.txt"
            $prompt | Out-File $tempP -Encoding UTF8
            Write-Host "[f] Docs agent for repo '$k' (timeout 25 min)..." -ForegroundColor Cyan
            $job = Start-Job -ScriptBlock {
                param($dir, $pf, $model, $useKey)
                Set-Location $dir
                if (-not $useKey) { Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue }
                & claude -p "@$pf" --model $model --dangerously-skip-permissions 2>&1 | Out-String
            } -ArgumentList $r.location, $tempP, $agentModel, $useApiKeyCfg
            $done = Wait-Job $job -Timeout 1500
            if (-not $done) {
                Stop-Job $job -ErrorAction SilentlyContinue
                Write-Host "[!] Docs agent for '$k' timed out - skipping (docs can be refreshed manually)" -ForegroundColor Yellow
            } else {
                $out = (Receive-Job $job | Out-String)
                $ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
                $out | Out-File (Join-Path $scriptDir "logs\finishing-$k-$ts.txt") -Encoding UTF8
                Write-Host "[f] Docs agent for '$k' done (log: logs\finishing-$k-$ts.txt)" -ForegroundColor Green
            }
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            Remove-Item $tempP -ErrorAction SilentlyContinue
        }
    }

    if ($finishPush) {
        # The orchestrator edits tasks.json/activity.md WITHOUT committing (single-writer,
        # in-place). Commit the ralph repo state (board + activity + any doc/reference
        # leftovers) so the push actually carries something. Runtime dirs are gitignored.
        $ralphDirty = @(& git -C $scriptDir status --porcelain 2>$null).Count
        if ($ralphDirty -gt 0) {
            & git -C $scriptDir add -A 2>&1 | Out-Null
            $idList = ($t | ForEach-Object { $_.id }) -join ','
            & git -C $scriptDir commit -m "ralph: board complete (tasks $idList) - state and docs sync" 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[f] Ralph repo state committed (tasks.json, activity.md, references)" -ForegroundColor Green
            } else {
                Write-Host "[!] Ralph repo commit failed - its push may carry nothing new" -ForegroundColor Yellow
            }
        }

        $pushRoots = @{}
        foreach ($k in $repoKeys) {
            $r = $reposMap.repos.$k
            if ($r) { $pushRoots[$r.gitRoot] = $k }
        }
        $pushRoots[$scriptDir] = "ralph"
        foreach ($root in $pushRoots.Keys) {
            $remotes = @(& git -C $root remote 2>$null)
            if ($remotes.Count -eq 0) {
                Write-Host "[!] Push skipped for '$($pushRoots[$root])' - no git remote configured" -ForegroundColor Yellow
                continue
            }
            $pushOut = (& git -C $root push 2>&1 | Out-String)
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[f] Pushed '$($pushRoots[$root])' ($root)" -ForegroundColor Green
            } else {
                $tail = $pushOut.Trim(); if ($tail.Length -gt 200) { $tail = $tail.Substring(0, 200) }
                Write-Host "[!] Push FAILED for '$($pushRoots[$root])': $tail" -ForegroundColor Yellow
            }
        }
    }

    # GitNexus re-index: ONCE, at the very end, FIRE-AND-FORGET (analyze can run 30+ min
    # on big repos and is banned mid-run - the board is done, so a detached refresh means
    # the NEXT board starts with a fresh code graph at zero wall-clock cost here.
    # --no-install: fail fast into the log if gitnexus is not set up for the repo.
    if ($finishIndex) {
        foreach ($k in $repoKeys) {
            $r = $reposMap.repos.$k
            if (-not $r) { continue }
            $ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
            $logF = Join-Path $scriptDir "logs\gitnexus-$k-$ts.txt"
            # Minimized (not Hidden): the taskbar console IS the progress indicator -
            # it disappears when indexing completes. Log keeps the full output.
            Start-Process powershell.exe -ArgumentList "-NoProfile", "-Command", "`$host.UI.RawUI.WindowTitle = 'GitNexus re-index: $k'; Set-Location '$($r.location)'; npx --no-install gitnexus analyze *> '$logF'" -WindowStyle Minimized | Out-Null
            Write-Host "[f] GitNexus re-index launched for '$k' (detached console in taskbar; gone = done; log: logs\gitnexus-$k-$ts.txt)" -ForegroundColor Cyan
        }
    }
    Write-Host "========================================================" -ForegroundColor Cyan
}

# Eligible = for each lane, the FIRST pending task in array order (lane preserves order),
# whose lane has no running task, whose dependsOn are all done, not failed this session.
function Get-Eligible($tasks, $runningIds, $runningLanes, $failedIds) {
    $doneIds = @($tasks | Where-Object { $_.passes -eq $true } | ForEach-Object { $_.id })
    $eligible = @()
    $seenLanes = @{}
    foreach ($t in $tasks) {
        if ($t.passes -eq $true) { continue }
        $lane = Get-LaneKey $t
        $isFirstInLane = -not $seenLanes.ContainsKey($lane)
        $seenLanes[$lane] = $true
        if (-not $isFirstInLane) { continue }          # later tasks in a lane wait their turn
        if ($runningIds -contains $t.id) { continue }
        if ($failedIds -contains $t.id) { continue }
        if ($runningLanes -contains $lane) { continue } # one agent per lane at a time
        $depsOk = $true
        if ($t.PSObject.Properties['dependsOn'] -and $t.dependsOn) {
            foreach ($d in @($t.dependsOn)) {
                if ($doneIds -notcontains $d) { $depsOk = $false; break }
            }
        }
        if (-not $depsOk) { continue }
        $eligible += $t
    }
    return $eligible
}

function Start-AgentForTask($task, $slot) {
    $rKey = "frontend"
    if ($task.PSObject.Properties['repo'] -and $task.repo) { $rKey = $task.repo }
    $r = $reposMap.repos.$rKey
    if (-not $r) {
        Write-Host "[!] Task #$($task.id): repo '$rKey' not found in repos.json - skipping" -ForegroundColor Yellow
        return $null
    }
    $gitRoot = $r.gitRoot
    if (-not $gitRoot) { $gitRoot = $r.location }
    $baseBranch = $r.mainBranch
    # rev-parse --abbrev-ref, NOT branch --show-current: the latter needs git >= 2.22 and
    # silently returns '' on older gits (this machine runs 2.21) - see the merge check too.
    if (-not $baseBranch) { $baseBranch = (& git -C $gitRoot rev-parse --abbrev-ref HEAD 2>$null) }

    $branchName = "ralph/task-$($task.id)"
    $wtPath = Join-Path $worktreeRoot "$rKey-task-$($task.id)"

    # CONTINUATION RETRY: when a retry context exists AND the predecessor's worktree+branch
    # are still on disk, REUSE them as-is - the new agent FIXES/COMPLETES the previous work
    # instead of regenerating everything from scratch. Clean spawn only for first attempts
    # or when the leftovers are incomplete (missing branch/worktree).
    $retryCtx = Join-Path $retryDir "task-$($task.id).md"
    $branchOk = $false
    & git -C $gitRoot rev-parse --verify --quiet $branchName 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $branchOk = $true }
    $resume = (Test-Path $retryCtx) -and (Test-Path $wtPath) -and $branchOk
    if ($resume) {
        Write-Host "[i] Task #$($task.id): CONTINUATION retry - reusing predecessor's worktree/branch (fix, don't regenerate)" -ForegroundColor Yellow
    } else {
        # clean leftovers from previous sessions, then (re)create branch off the integration branch
        if (Test-Path $wtPath) {
            & git -C $gitRoot worktree remove --force $wtPath 2>$null | Out-Null
            Remove-Item -Recurse -Force $wtPath -ErrorAction SilentlyContinue
        }
        & git -C $gitRoot worktree prune 2>$null | Out-Null
        & git -C $gitRoot branch -D $branchName 2>$null | Out-Null
        & git -C $gitRoot worktree add -b $branchName $wtPath $baseBranch 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[!] Task #$($task.id): 'git worktree add' failed (gitRoot=$gitRoot, base=$baseBranch)" -ForegroundColor Yellow
            return $null
        }
    }

    $workSub = ""
    if ($r.PSObject.Properties['workSubdir'] -and $r.workSubdir) { $workSub = $r.workSubdir }
    $agentDir = $wtPath
    if ($workSub) { $agentDir = Join-Path $wtPath $workSub }

    # untracked env files do not travel with worktrees - copy them from the main checkout
    # (skip on continuation - they are already there from the previous attempt)
    if (-not $resume) {
        Get-ChildItem -Path $r.location -Filter ".env*" -File -Force -ErrorAction SilentlyContinue |
            Copy-Item -Destination $agentDir -Force -ErrorAction SilentlyContinue
    }

    $resFile = Join-Path $resultsDir "task-$($task.id).json"
    Remove-Item $resFile -Force -ErrorAction SilentlyContinue

    # -iterationNumber = task id => unique %TEMP% prompt/output files per concurrent agent
    # -NoExit (via -keepWindows) leaves the agent's console open after it finishes
    $argList = @("-ExecutionPolicy", "Bypass", "-NoProfile")
    if ($keepWindows) { $argList += "-NoExit" }
    $argList += @(
        "-File", "`"$scriptDir\ralph-iteration.ps1`"",
        "-iterationNumber", "$($task.id)",
        "-configFile", "`"$configFile`"",
        "-taskId", "$($task.id)",
        "-workDir", "`"$agentDir`"",
        "-branch", "`"$branchName`"",
        "-resultFile", "`"$resFile`"",
        "-agentSlot", "$slot"
    )
    # failure context from previous attempt(s) -> the retry is informed, not blind
    if (Test-Path $retryCtx) {
        $argList += @("-retryFile", "`"$retryCtx`"")
        Write-Host "[i] Task #$($task.id): injecting retry context from previous failed attempt(s)" -ForegroundColor Yellow
    }
    # continuation mode -> the agent is told to FIX the inherited worktree, not start over.
    # Mode ladder: conflict (merge-main mandate) > escalate (scope lifted after
    # escalate_after consumed retries) > continue (in-scope fix).
    if ($resume) {
        $mode = "continue"
        $fc = $script:failCounts[$task.id]; if (-not $fc) { $fc = 0 }
        if ($script:conflictPending.ContainsKey($task.id)) {
            $mode = "conflict"
            $script:conflictPending.Remove($task.id)
        } elseif ($fc -ge $escalateAfter) {
            $mode = "escalate"
        }
        $argList += @("-retryMode", $mode)
        if ($mode -ne "continue") {
            Write-Host "[i] Task #$($task.id): retry mode = $mode" -ForegroundColor Yellow
        }
    }
    $proc = Start-Process powershell.exe -ArgumentList ($argList -join ' ') -PassThru -WindowStyle $agentWindows
    Write-Host "[>] SLOT $slot -> task #$($task.id) [$rKey / lane '$(Get-LaneKey $task)'] branch $branchName (pid $($proc.Id))" -ForegroundColor Green

    return @{
        proc = $proc; task = $task; lane = (Get-LaneKey $task); slot = $slot
        branch = $branchName; gitRoot = $gitRoot; baseBranch = $baseBranch
        wtPath = $wtPath; resFile = $resFile; started = Get-Date
    }
}

function Set-TaskPassed($id) {
    # single-writer update of the shared board (only the orchestrator ever writes tasks.json)
    $tasks = Read-Tasks
    foreach ($t in $tasks) { if ($t.id -eq $id) { $t.passes = $true } }
    $tasks | ConvertTo-Json -Depth 16 | Out-File $tasksFile -Encoding UTF8
}

function Add-ActivityEntry($entryText) {
    if (-not $entryText) { return }
    $af = Join-Path $scriptDir "activity.md"
    if (Test-Path $af) {
        $content = Get-Content $af -Raw -Encoding UTF8
        $ix = $content.IndexOf('-->')   # end of the header comment marker in the template
        if ($ix -ge 0) {
            $head = $content.Substring(0, $ix + 3)
            $tail = $content.Substring($ix + 3)
            $newContent = $head + "`n`n" + $entryText.Trim() + "`n" + $tail
        } else {
            $newContent = $entryText.Trim() + "`n`n---`n`n" + $content
        }
        $newContent | Out-File $af -Encoding UTF8
    } else {
        $entryText | Out-File $af -Encoding UTF8
    }
}

function Complete-Agent($info) {
    $t = $info.task
    $result = $null
    if (Test-Path $info.resFile) {
        try { $result = Get-Content $info.resFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
            Write-Host "[!] Task #$($t.id): result file is not valid JSON" -ForegroundColor Yellow
        }
    }

    $outcome = "failed"
    if ($result -and $result.status -eq "done") {
        # -------- sequential merge back into the integration branch (single-threaded here)
        # rev-parse works on any git version (branch --show-current needs >= 2.22 and
        # returns '' on git 2.21 -> every merge got skipped as "on '' expected 'main'").
        # Detached HEAD returns literal 'HEAD' which correctly fails the branch check.
        $cur = (& git -C $info.gitRoot rev-parse --abbrev-ref HEAD 2>$null)
        $dirty = (& git -C $info.gitRoot status --porcelain 2>$null)
        if ($cur -ne $info.baseBranch) {
            Write-Host "[!] Task #$($t.id): main checkout is on '$cur' (expected '$($info.baseBranch)') - MERGE SKIPPED. Branch kept: $($info.branch)" -ForegroundColor Yellow
            $outcome = "merge_skipped"
        } elseif ($dirty) {
            Write-Host "[!] Task #$($t.id): main checkout is dirty - MERGE SKIPPED. Branch kept: $($info.branch)" -ForegroundColor Yellow
            $outcome = "merge_skipped"
        } else {
            $desc = "$($t.description)" -replace '"', "'"
            $preMergeSha = (& git -C $info.gitRoot rev-parse HEAD 2>$null)
            & git -C $info.gitRoot merge --no-ff $info.branch -m "ralph: merge task #$($t.id) - $desc" 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                # Capture the conflicting files BEFORE aborting, then send the task back for
                # IN-WORKTREE resolution: the agent is permitted (exception) to merge the
                # integration branch into its own branch and resolve, budgeted like a fail.
                $confFiles = ((& git -C $info.gitRoot diff --name-only --diff-filter=U 2>$null) -join "`n")
                & git -C $info.gitRoot merge --abort 2>$null | Out-Null
                $n = $script:failCounts[$t.id]; if (-not $n) { $n = 0 }
                if ($n -lt $maxFailRetries) {
                    $script:failCounts[$t.id] = $n + 1
                    $script:conflictPending[$t.id] = $true
                    Save-RetryContext $t.id ($n + 1) ("MERGE CONFLICT: your branch conflicts with the integration branch '$($info.baseBranch)'. Conflicting files:`n$confFiles`n`nResolve IN YOUR WORKTREE: you are PERMITTED (exception to the git rules) to run 'git merge $($info.baseBranch)' on your current branch, resolve the conflicts preserving BOTH sides' intent, commit the merge, re-run the repo's unit tests, then write the result file.")
                    Write-Host "[~] Task #$($t.id): MERGE CONFLICT - RE-QUEUED for in-worktree resolution ($($n + 1)/$maxFailRetries)" -ForegroundColor Yellow
                    Release-Claim $t.id
                    return "conflict_requeue"
                }
                Write-Host "[X] Task #$($t.id): MERGE CONFLICT - retry budget exhausted. Branch kept for manual resolve: $($info.branch)" -ForegroundColor Red
                $outcome = "merge_conflict"
            } else {
                # ---- post-merge verification gate (semantic-conflict catcher) ----
                $verifyErr = Invoke-VerifyGate $t
                if (-not $verifyErr) {
                    $outcome = "merged"
                } else {
                    # The integration branch must stay green at all times - undo the merge
                    # (checkout was clean pre-merge, so a hard reset is safe), then send the
                    # task through the informed-retry path with the verify report as context.
                    & git -C $info.gitRoot reset --hard $preMergeSha 2>&1 | Out-Null
                    Write-Host "[X] Task #$($t.id): VERIFY GATE RED - merge undone (reset to $preMergeSha), worktree preserved for continuation" -ForegroundColor Red
                    $n = $script:failCounts[$t.id]; if (-not $n) { $n = 0 }
                    if ($n -lt $maxFailRetries) {
                        $script:failCounts[$t.id] = $n + 1
                        Save-RetryContext $t.id ($n + 1) $verifyErr
                        Write-Host "[~] Task #$($t.id): RETRY $($n + 1)/$maxFailRetries with verify failure context injected" -ForegroundColor Yellow
                        Release-Claim $t.id
                        return "verify_requeue"
                    }
                    Write-Host "[X] Task #$($t.id): verify gate red - retry budget ($maxFailRetries) exhausted. Branch kept: $($info.branch)" -ForegroundColor Red
                    Release-Claim $t.id
                    return "failed"
                }
            }
        }

        if ($outcome -eq "merged") {
            $script:fastFails = 0
            Set-TaskPassed $t.id
            if ($result.PSObject.Properties['activity']) { Add-ActivityEntry $result.activity }
            & git -C $info.gitRoot worktree remove --force $info.wtPath 2>$null | Out-Null
            & git -C $info.gitRoot branch -d $info.branch 2>$null | Out-Null
            # task succeeded -> its retry context is spent; delete so no stale state survives
            Remove-Item (Join-Path $retryDir "task-$($t.id).md") -Force -ErrorAction SilentlyContinue
            Write-Host "[+] Task #$($t.id): DONE + MERGED into '$($info.baseBranch)' (commit $($result.commit)). passes:true" -ForegroundColor Green
        }
        # merge_skipped / merge_conflict: work exists on the branch but is NOT in the
        # integration branch => passes stays FALSE; worktree/branch kept for a human.
    } else {
        # Exit code 2 = quota hit; the agent already WAITED for the reset inside its own
        # window and then exited. Re-queue the task (it becomes eligible again on the next
        # scheduler pass with a FRESH worktree) instead of counting it as failed.
        $exitCode = $null
        try { $exitCode = $info.proc.ExitCode } catch {}
        if ($exitCode -eq 2) {
            Write-Host "[~] Task #$($t.id): QUOTA hit (agent waited for reset) - RE-QUEUED (worktree preserved, will continue)" -ForegroundColor Yellow
            Save-RetryContext $t.id "resume" "QUOTA interrupt - the agent waited for reset and exited. Work in the worktree is PRESERVED (committed and/or uncommitted). Continue from where the previous attempt stopped."
            Release-Claim $t.id
            return "quota_requeue"
        }

        # Exit code 4 = fatal environment error (API credit balance / auth). NOT the task's
        # fault - do not touch its retry budget or failedIds; signal the main loop to abort
        # the entire run so a human can fix billing/model and re-run.
        if ($exitCode -eq 4) {
            Save-RetryContext $t.id "resume" "FATAL ENV interrupt (credits/auth) - not the task's fault. Work in the worktree is PRESERVED; continue from where the previous attempt stopped after the environment is fixed."
            Release-Claim $t.id
            return "fatal_env"
        }

        # Exit code 3 = watchdog kill (180 min hard timeout / 60 min stale). Hangs are the
        # most STOCHASTIC failure mode (stuck dev server, network stall, wedged prompt) -
        # a blind re-run with a fresh worktree usually clears them. Re-queue up to budget.
        if ($exitCode -eq 3) {
            $n = $script:timeoutCounts[$t.id]; if (-not $n) { $n = 0 }
            if ($n -lt $maxTimeoutRequeues) {
                $script:timeoutCounts[$t.id] = $n + 1
                Save-RetryContext $t.id "resume" "TIMEOUT/STALE - the previous agent was killed by the watchdog mid-work. Work in the worktree is PRESERVED but may be mid-edit; run git status/diff, sanity-check the last touched files, then continue."
                Write-Host "[~] Task #$($t.id): TIMEOUT/STALE kill - RE-QUEUED, worktree preserved ($($n + 1)/$maxTimeoutRequeues)" -ForegroundColor Yellow
                Release-Claim $t.id
                return "timeout_requeue"
            }
            Write-Host "[X] Task #$($t.id): timed out again after $maxTimeoutRequeues re-queue(s) - FAILED for this session. Worktree + branch kept: $($info.branch)" -ForegroundColor Red
            Release-Claim $t.id
            return "failed"
        }

        # Real failure (status:"failed" or no/invalid result file). Retry up to budget, but
        # INFORMED: the failure reason + the agent's log tail go to retry\task-<id>.md and
        # the next attempt gets them via -retryFile. Attempt N+1 differs from attempt N, so
        # this also catches deterministic failures, not just unlucky ones.
        # Instant deaths (<60s) are almost never task failures - they are config/CLI/API
        # problems (bad model name, expired auth, API 400s). Count them; the main loop
        # aborts the whole run after 3 consecutive ones instead of burning every task's
        # retry budget on the same environment error. Any merge or slow failure resets.
        $runtimeSec = ((Get-Date) - $info.started).TotalSeconds
        if ($runtimeSec -lt 60) { $script:fastFails++ } else { $script:fastFails = 0 }
        $why = "no result file"
        if ($result) { $why = "status=$($result.status): $($result.summary)" }
        $n = $script:failCounts[$t.id]; if (-not $n) { $n = 0 }
        if ($n -lt $maxFailRetries) {
            $script:failCounts[$t.id] = $n + 1
            Save-RetryContext $t.id ($n + 1) $why
            Write-Host "[~] Task #$($t.id): FAILED ($why) - RETRY $($n + 1)/$maxFailRetries, worktree preserved for continuation" -ForegroundColor Yellow
            Release-Claim $t.id
            return "fail_requeue"
        }
        Write-Host "[X] Task #$($t.id): FAILED ($why) - retry budget ($maxFailRetries) exhausted. Worktree + branch kept: $($info.branch)" -ForegroundColor Red
    }

    Release-Claim $t.id
    return $outcome
}

# ---------------------------------------------------------------- main rolling loop
$running   = @{}    # taskId -> agent info
$failedIds = @()
$script:timeoutCounts = @{}   # taskId -> watchdog-kill re-queues used this session
$script:failCounts    = @{}   # taskId -> informed retries used this session
$script:fastFails     = 0     # consecutive instant (<60s) agent deaths -> environment problem guard
$script:fatalEnv      = $false # exit 4 seen (credits/auth) -> abort the whole run immediately
$script:conflictPending = @{} # taskId -> next spawn is a conflict-resolution retry (merge main in-worktree)
# Snapshot each touched repo's HEAD at run start - the finishing review stage reviews
# exactly what THIS run changed (startSha..HEAD).
$script:startShas = @{}
foreach ($t0 in (Read-Tasks)) {
    if ($t0.PSObject.Properties['repo'] -and $t0.repo -and $reposMap.repos.$($t0.repo)) {
        $gr0 = $reposMap.repos.$($t0.repo).gitRoot
        if (-not $script:startShas.ContainsKey($gr0)) {
            $script:startShas[$gr0] = (& git -C $gr0 rev-parse HEAD 2>$null)
        }
    }
}
$stats = @{ merged = 0; conflicts = 0; skipped = 0; failed = 0; requeued = 0; timeoutRequeues = 0; failRetries = 0; verifyReverts = 0; conflictRequeues = 0 }
$freeSlots = New-Object System.Collections.ArrayList
1..$agents | ForEach-Object { [void]$freeSlots.Add($_) }
$launchedTotal = 0

while ($true) {
    $tasks = Read-Tasks
    $pendingCount = @($tasks | Where-Object { $_.passes -eq $false }).Count

    if ($pendingCount -eq 0 -and $running.Count -eq 0) {
        Write-Host ""; Write-Host "[+] ALL TASKS COMPLETE!" -ForegroundColor Green
        Invoke-FinishingStep
        break
    }

    # fill free slots (unless maxTasks budget is exhausted)
    $budgetLeft = $true
    if ($maxTasks -gt 0 -and ($launchedTotal -ge $maxTasks)) { $budgetLeft = $false }
    if ($budgetLeft -and $freeSlots.Count -gt 0) {
        $runningIds   = @($running.Keys)
        $runningLanes = @($running.Values | ForEach-Object { $_.lane })
        $elig = Get-Eligible $tasks $runningIds $runningLanes $failedIds
        foreach ($t in $elig) {
            if ($freeSlots.Count -eq 0) { break }
            if ($maxTasks -gt 0 -and $launchedTotal -ge $maxTasks) { break }
            if (-not (Try-Claim $t.id)) { continue }
            $slot = $freeSlots[0]
            $info = Start-AgentForTask $t $slot
            if ($info) {
                $running[$t.id] = $info
                $freeSlots.Remove($slot)
                $launchedTotal++
            } else {
                Release-Claim $t.id
                $failedIds += $t.id
                $stats.failed++
            }
        }
    }

    if ($running.Count -eq 0) {
        Write-Host ""
        Write-Host "[!] No agents running and no eligible tasks left." -ForegroundColor Yellow
        Write-Host "    Causes: unmet dependsOn (blocked), failed tasks this session, or maxTasks reached." -ForegroundColor Yellow
        break
    }

    Start-Sleep -Seconds 15

    # collect finished agents (rolling: freed slot is refilled on the next loop pass)
    foreach ($id in @($running.Keys)) {
        $info = $running[$id]
        if ($info.proc.HasExited) {
            $outcome = Complete-Agent $info
            switch ($outcome) {
                "merged"          { $stats.merged++ }
                "merge_conflict"  { $stats.conflicts++; $failedIds += $id }
                "merge_skipped"   { $stats.skipped++;  $failedIds += $id }
                "quota_requeue"   { $stats.requeued++ }        # NOT failed - eligible again next pass
                "timeout_requeue" { $stats.timeoutRequeues++ } # watchdog kill - fresh blind re-run
                "fail_requeue"    { $stats.failRetries++ }     # informed retry (failure context injected)
                "verify_requeue"  { $stats.verifyReverts++ }   # merge undone by verify gate - informed retry
                "conflict_requeue" { $stats.conflictRequeues++ } # in-worktree conflict resolution retry
                "fatal_env"       { $script:fatalEnv = $true } # credits/auth dead - abort below, task NOT failed
                default           { $stats.failed++;   $failedIds += $id }
            }
            $running.Remove($id)
            [void]$freeSlots.Add($info.slot)
        }
    }

    # Fatal billing/auth error reported by an agent (exit 4): abort the whole run NOW.
    # No retry can fix an empty credit balance; tasks stay pending for the next run.
    if ($script:fatalEnv) {
        Write-Host ""
        Write-Host "[X] FATAL: agent reported billing/auth failure (API credit balance too low)." -ForegroundColor Red
        Write-Host "    Run aborted. Top up credits or switch swarm model (ralph-config.json" -ForegroundColor Red
        Write-Host "    claude_args --model), then re-run - pending tasks are untouched." -ForegroundColor Red
        break
    }

    # Environment-failure guard (mirrors ralph.ps1's silent-failure guard): 3 consecutive
    # agents dying in <60s = config/CLI/API problem (bad model, expired auth, API 400),
    # not task failures. Abort instead of burning every task's retry budget on it.
    if ($script:fastFails -ge 3) {
        Write-Host ""
        Write-Host "[X] FATAL: 3 consecutive agents died in under 60s each." -ForegroundColor Red
        Write-Host "    This is an ENVIRONMENT problem, not task failures. Check the newest" -ForegroundColor Red
        Write-Host "    logs\iteration-*.txt for the real error (API 400 / bad --model /" -ForegroundColor Red
        Write-Host "    expired auth / claude CLI too old), fix it, then re-run the swarm." -ForegroundColor Red
        break
    }

    $rIds = (@($running.Keys) | Sort-Object) -join ', '
    Write-Host ("[{0}] running: [{1}] | merged {2} | conflicts {3} | skipped {4} | failed {5}" -f (Get-Date -Format 'HH:mm:ss'), $rIds, $stats.merged, $stats.conflicts, $stats.skipped, $stats.failed) -ForegroundColor DarkCyan
}

# ---------------------------------------------------------------- summary
Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   SWARM SUMMARY" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "Merged           : $($stats.merged)"    -ForegroundColor Green
Write-Host "Merge conflicts  : $($stats.conflicts)" -ForegroundColor $(if ($stats.conflicts) { 'Red' } else { 'Gray' })
Write-Host "Merge skipped    : $($stats.skipped)"   -ForegroundColor $(if ($stats.skipped)   { 'Yellow' } else { 'Gray' })
Write-Host "Failed           : $($stats.failed)"    -ForegroundColor $(if ($stats.failed)    { 'Red' } else { 'Gray' })
Write-Host "Quota re-queues  : $($stats.requeued)"  -ForegroundColor $(if ($stats.requeued)  { 'Yellow' } else { 'Gray' })
Write-Host "Timeout re-queues: $($stats.timeoutRequeues)" -ForegroundColor $(if ($stats.timeoutRequeues) { 'Yellow' } else { 'Gray' })
Write-Host "Fail retries     : $($stats.failRetries)"     -ForegroundColor $(if ($stats.failRetries)     { 'Yellow' } else { 'Gray' })
Write-Host "Verify reverts   : $($stats.verifyReverts)"   -ForegroundColor $(if ($stats.verifyReverts)   { 'Yellow' } else { 'Gray' })
Write-Host "Conflict re-queues: $($stats.conflictRequeues)" -ForegroundColor $(if ($stats.conflictRequeues) { 'Yellow' } else { 'Gray' })
Write-Host ""
Write-Host "Conflict/skipped branches are kept as ralph/task-<id> for manual resolve." -ForegroundColor Gray
Write-Host "Stale worktrees (if any): git worktree list  (in each gitRoot)" -ForegroundColor Gray
if ($stats.conflicts -gt 0 -or $stats.failed -gt 0) { exit 1 } else { exit 0 }
