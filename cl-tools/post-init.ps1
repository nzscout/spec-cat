#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run after every: specify init --here --force --ai copilot
    Applies patches and copies once-only extras into the target project.

.DESCRIPTION
    Two-phase post-init script:

    Phase 1 — Patches (always runs):
      Calls patches/apply.ps1, which surgically replaces step 1 and step 2
      inside the generated speckit.specify.agent.md with Git Flow / short-name
      logic, without touching any other upstream-generated file.

    Phase 2 — Extras (skipped if file already exists in project):
      Copies custom agents, prompts, and memory files that are not generated
      by `specify init`. Existing files are NEVER overwritten — so per-project
      customizations to these files are safe.

.PARAMETER ProjectRoot
    Root of the project where `specify init` was run. Defaults to CWD.

.PARAMETER SkipExtras
    Skip Phase 2 (extras copy). Useful if you only want to re-apply patches
    after an upstream sync + re-init, without touching extras.

.PARAMETER WhatIf
    Dry-run both phases: check patch anchors and report what would be copied,
    without writing any files.

.EXAMPLE
    # From the project root — normal use after every specify init
    C:\Tools\CL-Speckit-updates\post-init.ps1

    # Only re-apply patches (skip extras)
    C:\Tools\CL-Speckit-updates\post-init.ps1 -SkipExtras

    # Dry-run — check patch anchors and preview extras
    C:\Tools\CL-Speckit-updates\post-init.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipExtras
)

$ErrorActionPreference = 'Stop'
$ScriptDir  = $PSScriptRoot
$PatchesDir = Join-Path $ScriptDir 'patches'
$ExtrasDir  = Join-Path $ScriptDir 'extras'

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host " CL-Speckit post-init"
Write-Host " Project : $ProjectRoot"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ---------------------------------------------------------------------------
# Phase 1 — Patches
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Phase 1 — patches"
Write-Host "------------------"

$patchScript = Join-Path $PatchesDir 'apply.ps1'

if (-not (Test-Path $patchScript)) {
    Write-Error "Patch script not found: $patchScript`nEnsure this script is located inside the CL-Speckit-updates folder."
    exit 1
}

if ($WhatIfPreference) {
    & $patchScript -ProjectRoot $ProjectRoot -WhatIf
} else {
    & $patchScript -ProjectRoot $ProjectRoot
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Patch phase failed — see warnings above."
    exit 1
}

# ---------------------------------------------------------------------------
# Phase 2 — Extras (copy-once)
# ---------------------------------------------------------------------------
if ($SkipExtras) {
    Write-Host ""
    Write-Host "Phase 2 — extras (skipped via -SkipExtras)"
} else {
    Write-Host ""
    Write-Host "Phase 2 — extras (copy-once; existing files are never overwritten)"
    Write-Host "--------------------------------------------------------------------"

    # Relative paths under both $ExtrasDir (source) and $ProjectRoot (destination)
    $extras = @(
        '.github/agents/speckit.comparer-code.agent.md'
        '.github/agents/speckit.comparer-spec.agent.md'
        '.github/agents/speckit.reviewer-code.agent.md'
        '.github/agents/context7.agent.md'
        '.github/prompts/speckit.reconcile-code.prompt.md'
        '.github/prompts/speckit.reconcile-spec.prompt.md'
        '.specify/memory/constitution.dotnet.md'
        '.specify/memory/go-constitution.md'
    )

    $copied  = 0
    $skipped = 0
    $missing = 0

    foreach ($rel in $extras) {
        $srcPath = Join-Path $ExtrasDir ($rel -replace '/', '\')
        $dstPath = Join-Path $ProjectRoot ($rel -replace '/', '\')

        if (-not (Test-Path $srcPath)) {
            Write-Warning "  [WARN]  source not found: extras\$rel"
            $missing++
            continue
        }

        if (Test-Path $dstPath) {
            Write-Host "  [SKIP]  $rel (already exists)"
            $skipped++
            continue
        }

        $dstDir = Split-Path $dstPath -Parent
        if (-not (Test-Path $dstDir)) {
            New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        }

        if ($PSCmdlet.ShouldProcess($dstPath, "copy extra")) {
            Copy-Item $srcPath $dstPath
            Write-Host "  [OK]    $rel"
            $copied++
        } else {
            Write-Host "  [DRY]   $rel (would copy)"
        }
    }

    Write-Host ""
    Write-Host "  Extras summary: $copied copied, $skipped already existed, $missing sources missing"
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host " Done."
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
