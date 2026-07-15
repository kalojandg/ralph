<#
.SYNOPSIS
    Select a subset of Playwright E2E specs to run based on git diff and Admin-App/e2e/feature-map.json.

.DESCRIPTION
    Inner-loop optimization for ralph iterations. Reads the feature map, gathers the changed files
    (committed-vs-base + uncommitted + untracked), and prints either:
      - "FULL"                 → cross-cutting path touched; run the entire E2E suite
      - <spec1> <spec2> ...    → space-separated spec paths; pass directly to npm run e2e --
      - (nothing, exit 0)      → no E2E required (e.g. pure docs/refactor/backend-only change)

    Path mapping is best-effort and intentionally conservative: any cross-cutting hit forces full
    suite; the ignored list excludes things that genuinely don't need E2E (docs, ralph/, test files
    themselves). CI/PR pipelines should still run the full suite — this script is for the agent's
    inner loop where iteration speed matters.

.PARAMETER BaseRef
    Git ref to diff against. Defaults to origin/develop.

.PARAMETER AdminAppDir
    Path to Admin-App. Auto-detected by default.

.EXAMPLE
    .\select-e2e.ps1
    # Uses origin/develop as base

.EXAMPLE
    .\select-e2e.ps1 -BaseRef origin/main
    # Custom base

.EXAMPLE
    $specs = .\select-e2e.ps1
    if ($specs -eq 'FULL') { npm run e2e } elseif ($specs) { npm run e2e -- $specs.Split() }
#>
[CmdletBinding()]
param(
    [string] $BaseRef = 'origin/develop',
    [string] $AdminAppDir = ''
)

$ErrorActionPreference = 'Stop'

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

if (-not $AdminAppDir) {
    # $PSScriptRoot is unreliable in param defaults under -File invocation; resolve in body.
    $AdminAppDir = Join-Path (Split-Path -Parent $scriptDir) 'Admin-App'
}

# Feature map lives alongside this script in ralph/ — keeps the optimization
# self-contained (no commits required in the Admin-App repo).
$mapPath = Join-Path $scriptDir 'feature-map.json'
if (-not (Test-Path $mapPath)) {
    Write-Error "feature-map.json not found at $mapPath"
    exit 3
}

$map = Get-Content -Raw -LiteralPath $mapPath | ConvertFrom-Json

# --- Collect changed files (deduped union of three sources) ---
Push-Location $AdminAppDir
try {
    $changedCommitted = & git diff --name-only "$BaseRef...HEAD" 2>$null
    $changedWorking   = & git diff --name-only HEAD 2>$null
    $changedUntracked = & git ls-files --others --exclude-standard 2>$null
} finally {
    Pop-Location
}

$changed = @($changedCommitted + $changedWorking + $changedUntracked) |
    Where-Object { $_ -and $_.Trim() } |
    Sort-Object -Unique

if ($changed.Count -eq 0) {
    # No changes detected — no E2E needed
    exit 0
}

# --- Glob → regex converter (** = recursive, * = single segment) ---
function Convert-GlobToRegex {
    param([string] $Glob)
    $escaped = [regex]::Escape($Glob)
    # Escape produced backslashes for * and / — undo only what we need
    $escaped = $escaped -replace '\\\*\\\*', '__DSTAR__'    # **  → placeholder
    $escaped = $escaped -replace '\\\*',     '[^/]*'         # *   → anything but /
    $escaped = $escaped -replace '__DSTAR__', '.*'           # placeholder → .*
    $escaped = $escaped -replace '/',         '/'            # keep / as-is
    return "^$escaped$"
}

function Test-FileMatchesAny {
    param(
        [string]   $File,
        [string[]] $Globs
    )
    # Normalize to forward slashes (git diff always uses /, but be safe)
    $f = $File -replace '\\', '/'
    foreach ($g in $Globs) {
        $re = Convert-GlobToRegex -Glob $g
        if ($f -match $re) { return $true }
    }
    return $false
}

# --- Step 1: cross-cutting check — single hit forces FULL ---
$ccPaths = @($map.crossCutting.paths)
foreach ($file in $changed) {
    if (Test-FileMatchesAny -File $file -Globs $ccPaths) {
        Write-Output 'FULL'
        exit 0
    }
}

# --- Step 2: filter out ignored paths ---
$ignored = @($map.ignored.paths)
$relevant = @($changed | Where-Object { -not (Test-FileMatchesAny -File $_ -Globs $ignored) })

if ($relevant.Count -eq 0) {
    # All changes are in ignored category — no E2E needed
    exit 0
}

# --- Step 3: for each feature, see if any source glob matches any relevant file ---
$specsOut = [System.Collections.Generic.HashSet[string]]::new()

foreach ($featureName in $map.features.PSObject.Properties.Name) {
    $feature = $map.features.$featureName
    $sources = @($feature.sources)
    $matched = $false
    foreach ($file in $relevant) {
        if (Test-FileMatchesAny -File $file -Globs $sources) {
            $matched = $true
            break
        }
    }
    if ($matched) {
        foreach ($spec in @($feature.specs)) {
            [void]$specsOut.Add($spec)
        }
    }
}

if ($specsOut.Count -eq 0) {
    # Files changed but none mapped — agent should still run lint/type-check/unit, no E2E.
    # Emit a hint to stderr so the caller knows we processed something but found no match.
    [Console]::Error.WriteLine("select-e2e: $($relevant.Count) changed file(s) found but none matched any feature in feature-map.json. Consider adding a mapping.")
    exit 0
}

# Output specs space-separated on a single line (easy to interpolate into `npm run e2e -- $out`)
Write-Output (($specsOut | Sort-Object) -join ' ')
exit 0
