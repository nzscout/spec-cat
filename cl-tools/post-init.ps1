#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run after every: specify init --here --force --ai copilot
    Applies patches and copies once-only extras into the target project.

.DESCRIPTION
    Two-phase post-init script:

    Phase 1 — Patches (always runs):
      Calls patches/apply.ps1, which surgically replaces targeted sections in
      upstream-generated files with Git Flow / short-name logic:
        - speckit.specify.agent.md  (steps 1 & 2 — short-name + branch creation)
        - common.ps1                (Get-CurrentBranch fallback, Test-FeatureBranch
                                     pattern, new Get-FeatureName, Get-FeatureDir)
        - create-new-feature.ps1    (param block, help text, branch generation)

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
    Write-Host "Phase 2 — extras (always overwritten to stay current)"
    Write-Host "------------------------------------------------------"

    $copied  = 0
    $updated = 0

    Get-ChildItem -Path $ExtrasDir -Recurse -File | Sort-Object FullName | ForEach-Object {
        $srcPath = $_.FullName
        $rel     = $srcPath.Substring($ExtrasDir.Length).TrimStart('\', '/')
        $dstPath = Join-Path $ProjectRoot $rel
        $isUpdate = Test-Path $dstPath

        $dstDir = Split-Path $dstPath -Parent
        if (-not (Test-Path $dstDir)) {
            New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        }

        if ($PSCmdlet.ShouldProcess($dstPath, "copy extra")) {
            Copy-Item $srcPath $dstPath -Force
            if ($isUpdate) {
                Write-Host "  [UP]    $rel"
                $updated++
            } else {
                Write-Host "  [OK]    $rel"
                $copied++
            }
        } else {
            $verb = if ($isUpdate) { 'would overwrite' } else { 'would copy' }
            Write-Host "  [DRY]   $rel ($verb)"
        }
    }

    Write-Host ""
    Write-Host "  Extras summary: $copied new, $updated updated"
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host " Done."
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
