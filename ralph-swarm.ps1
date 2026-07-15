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
    [string]$worktreeRoot = ""    # default: <parent-of-ralph>\.ralph-worktrees
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

$tasksFile  = Join-Path $scriptDir "tasks.json"
$reposFile  = Join-Path $scriptDir "ralph reference\project reference\repos.json"
$claimsDir  = Join-Path $scriptDir "claims"
$resultsDir = Join-Path $scriptDir "results"

if (-not (Test-Path $tasksFile)) { Write-Host "[X] tasks.json not found" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $reposFile)) { Write-Host "[X] repos.json not found ($reposFile)" -ForegroundColor Red; exit 1 }
$reposMap = Get-Content $reposFile -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($d in @($claimsDir, $resultsDir, $worktreeRoot)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}
# stale claims are from a previous session - this orchestrator is the only claimer, so reset
Remove-Item (Join-Path $claimsDir "*.claim") -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   Ralph SWARM - parallel agents over worktrees"      -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "Agents (slots) : $agents"       -ForegroundColor White
Write-Host "Max tasks      : $(if ($maxTasks -gt 0) { $maxTasks } else { 'until done' })" -ForegroundColor White
Write-Host "Worktree root  : $worktreeRoot" -ForegroundColor White
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
    if (-not $baseBranch) { $baseBranch = (& git -C $gitRoot branch --show-current 2>$null) }

    $branchName = "ralph/task-$($task.id)"
    $wtPath = Join-Path $worktreeRoot "$rKey-task-$($task.id)"

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

    $workSub = ""
    if ($r.PSObject.Properties['workSubdir'] -and $r.workSubdir) { $workSub = $r.workSubdir }
    $agentDir = $wtPath
    if ($workSub) { $agentDir = Join-Path $wtPath $workSub }

    # untracked env files do not travel with worktrees - copy them from the main checkout
    Get-ChildItem -Path $r.location -Filter ".env*" -File -Force -ErrorAction SilentlyContinue |
        Copy-Item -Destination $agentDir -Force -ErrorAction SilentlyContinue

    $resFile = Join-Path $resultsDir "task-$($task.id).json"
    Remove-Item $resFile -Force -ErrorAction SilentlyContinue

    # -iterationNumber = task id => unique %TEMP% prompt/output files per concurrent agent
    $argList = @(
        "-ExecutionPolicy", "Bypass", "-NoProfile",
        "-File", "`"$scriptDir\ralph-iteration.ps1`"",
        "-iterationNumber", "$($task.id)",
        "-configFile", "`"$configFile`"",
        "-taskId", "$($task.id)",
        "-workDir", "`"$agentDir`"",
        "-branch", "`"$branchName`"",
        "-resultFile", "`"$resFile`"",
        "-agentSlot", "$slot"
    )
    $proc = Start-Process powershell.exe -ArgumentList ($argList -join ' ') -PassThru -WindowStyle Normal
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
        $cur = (& git -C $info.gitRoot branch --show-current 2>$null)
        $dirty = (& git -C $info.gitRoot status --porcelain 2>$null)
        if ($cur -ne $info.baseBranch) {
            Write-Host "[!] Task #$($t.id): main checkout is on '$cur' (expected '$($info.baseBranch)') - MERGE SKIPPED. Branch kept: $($info.branch)" -ForegroundColor Yellow
            $outcome = "merge_skipped"
        } elseif ($dirty) {
            Write-Host "[!] Task #$($t.id): main checkout is dirty - MERGE SKIPPED. Branch kept: $($info.branch)" -ForegroundColor Yellow
            $outcome = "merge_skipped"
        } else {
            $desc = "$($t.description)" -replace '"', "'"
            & git -C $info.gitRoot merge --no-ff $info.branch -m "ralph: merge task #$($t.id) - $desc" 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                & git -C $info.gitRoot merge --abort 2>$null | Out-Null
                Write-Host "[X] Task #$($t.id): MERGE CONFLICT - aborted. Branch kept for manual resolve: $($info.branch)" -ForegroundColor Red
                $outcome = "merge_conflict"
            } else {
                $outcome = "merged"
            }
        }

        if ($outcome -eq "merged") {
            Set-TaskPassed $t.id
            if ($result.PSObject.Properties['activity']) { Add-ActivityEntry $result.activity }
            & git -C $info.gitRoot worktree remove --force $info.wtPath 2>$null | Out-Null
            & git -C $info.gitRoot branch -d $info.branch 2>$null | Out-Null
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
            Write-Host "[~] Task #$($t.id): QUOTA hit (agent waited for reset) - RE-QUEUED" -ForegroundColor Yellow
            & git -C $info.gitRoot worktree remove --force $info.wtPath 2>$null | Out-Null
            Release-Claim $t.id
            return "quota_requeue"
        }
        $why = "no result file"
        if ($result) { $why = "status=$($result.status): $($result.summary)" }
        Write-Host "[X] Task #$($t.id): FAILED ($why). Worktree removed, branch kept: $($info.branch)" -ForegroundColor Red
        & git -C $info.gitRoot worktree remove --force $info.wtPath 2>$null | Out-Null
    }

    Release-Claim $t.id
    return $outcome
}

# ---------------------------------------------------------------- main rolling loop
$running   = @{}    # taskId -> agent info
$failedIds = @()
$stats = @{ merged = 0; conflicts = 0; skipped = 0; failed = 0; requeued = 0 }
$freeSlots = New-Object System.Collections.ArrayList
1..$agents | ForEach-Object { [void]$freeSlots.Add($_) }
$launchedTotal = 0

while ($true) {
    $tasks = Read-Tasks
    $pendingCount = @($tasks | Where-Object { $_.passes -eq $false }).Count

    if ($pendingCount -eq 0 -and $running.Count -eq 0) {
        Write-Host ""; Write-Host "[+] ALL TASKS COMPLETE!" -ForegroundColor Green; break
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
                "merged"         { $stats.merged++ }
                "merge_conflict" { $stats.conflicts++; $failedIds += $id }
                "merge_skipped"  { $stats.skipped++;  $failedIds += $id }
                "quota_requeue"  { $stats.requeued++ }   # NOT failed - eligible again next pass
                default          { $stats.failed++;   $failedIds += $id }
            }
            $running.Remove($id)
            [void]$freeSlots.Add($info.slot)
        }
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
Write-Host ""
Write-Host "Conflict/skipped branches are kept as ralph/task-<id> for manual resolve." -ForegroundColor Gray
Write-Host "Stale worktrees (if any): git worktree list  (in each gitRoot)" -ForegroundColor Gray
if ($stats.conflicts -gt 0 -or $stats.failed -gt 0) { exit 1 } else { exit 0 }
