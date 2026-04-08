#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Apply custom patches to speckit-generated agent files.
    Run after: specify init --here --force --ai copilot

.DESCRIPTION
    Injects custom content snippets into specific sections of upstream-generated
    speckit agent files without replacing the files wholesale. Each patch is
    delimited by two line-pattern anchors:

      StartAnchor — regex that matches the first line of the section to replace
      EndAnchor   — regex that matches the first line of the NEXT section (kept)

    If an anchor is not found the patch is skipped with a warning and the script
    exits 1, so CI can detect when an upstream rename breaks an anchor.

    Pass -WhatIf to check anchors and preview which patches would apply without
    writing any files.

.PARAMETER ProjectRoot
    Root of the project where speckit was initialized. Defaults to CWD.

.PARAMETER WhatIf
    Dry-run: check anchors and report, but do not write any files.

.EXAMPLE
    # Normal use after specify init
    ./patches/apply.ps1

    # Dry-run — useful in CI after an upstream sync to verify anchors still exist
    ./patches/apply.ps1 -WhatIf

    # Explicit project root
    ./patches/apply.ps1 -ProjectRoot C:\Projects\MyRepo
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot

# ---------------------------------------------------------------------------
# Core engine
# ---------------------------------------------------------------------------

function Invoke-SectionPatch {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$FilePath,
        [string]$StartAnchor,   # Regex: matches the first line of the section to replace
        [string]$EndAnchor,     # Regex: matches the first line of the following section (preserved)
        [string]$SnippetPath,   # File whose content replaces the matched section
        [string]$Name           # Friendly name shown in output
    )

    if (-not (Test-Path $FilePath)) {
        Write-Warning "  [SKIP] $Name"
        Write-Warning "         File not found: $FilePath"
        return $false
    }

    if (-not (Test-Path $SnippetPath)) {
        Write-Warning "  [SKIP] $Name"
        Write-Warning "         Snippet not found: $SnippetPath"
        return $false
    }

    $lines = [System.IO.File]::ReadAllLines($FilePath)

    $startIdx = -1
    $endIdx   = $lines.Count

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($startIdx -eq -1 -and $lines[$i] -match $StartAnchor) {
            $startIdx = $i
        } elseif ($startIdx -ge 0 -and $lines[$i] -match $EndAnchor) {
            $endIdx = $i
            break
        }
    }

    if ($startIdx -eq -1) {
        Write-Warning "  [WARN] $Name"
        Write-Warning "         Start anchor not found: '$StartAnchor'"
        Write-Warning "         Upstream may have renamed this section. Update the anchor in apply.ps1."
        return $false
    }

    $snippet = (Get-Content $SnippetPath -Raw -Encoding UTF8).TrimEnd("`r", "`n")

    if ($PSCmdlet.ShouldProcess($FilePath, "patch section '$Name' (lines $startIdx–$($endIdx-1))")) {
        $before = if ($startIdx -gt 0) { ($lines[0..($startIdx - 1)] -join "`n") } else { "" }
        $after  = if ($endIdx -lt $lines.Count) { ($lines[$endIdx..($lines.Count - 1)] -join "`n") } else { "" }

        $newContent = if ($after) { "$before`n$snippet`n`n$after" } else { "$before`n$snippet`n" }

        [System.IO.File]::WriteAllText($FilePath, $newContent, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  [OK]   $Name  (lines $startIdx–$($endIdx-1) replaced)"
    } else {
        # -WhatIf branch: anchor was found, just report
        Write-Host "  [DRY]  $Name  (anchor found at line $startIdx, end at $endIdx — would apply)"
    }

    return $true
}

# ---------------------------------------------------------------------------
# Patch definitions
# ---------------------------------------------------------------------------
# Anchors target the GENERATED .github/agents/ files (post specify-init output),
# not the upstream template source. Key difference: {ARGS} → $ARGUMENTS,
# {SCRIPT} → .specify/scripts/... paths.
#
# StartAnchor: the exact heading line that begins the section you own.
# EndAnchor:   the exact heading line that begins the NEXT section (not replaced).
#
# When upstream renames a heading, apply.ps1 -WhatIf will warn and exit 1
# so you can update the anchor strings here.
# ---------------------------------------------------------------------------

$specifyAgent       = Join-Path $ProjectRoot ".github/agents/speckit.specify.agent.md"
$commonScript       = Join-Path $ProjectRoot ".specify/scripts/powershell/common.ps1"
$createFeatureScript = Join-Path $ProjectRoot ".specify/scripts/powershell/create-new-feature.ps1"

$patches = @(
    @{
        FilePath    = $specifyAgent
        # Upstream heading: "1. **Generate a concise short name** (2-4 words) for the branch:"
        StartAnchor = '^1\. \*\*Generate a concise short name\*\*'
        # Next section heading starts with "2. **"
        EndAnchor   = '^2\. \*\*'
        SnippetPath = Join-Path $ScriptDir 'snippets/specify-step1.md'
        Name        = 'specify.agent — step 1: short-name param / Git Flow support'
    },
    @{
        FilePath    = $specifyAgent
        # Match the stable step-2 heading prefix; upstream may append extra guidance.
        StartAnchor = '^2\. \*\*Create the feature branch\*\*'
        # Next section heading starts with "3. "
        EndAnchor   = '^3\. '
        SnippetPath = Join-Path $ScriptDir 'snippets/specify-step2.md'
        Name        = 'specify.agent — step 2: Git Flow mode + current-branch reuse'
    },

    # ---------------------------------------------------------------------------
    # common.ps1 — Git Flow support
    # ---------------------------------------------------------------------------
    @{
        FilePath    = $commonScript
        # The `if ($latestFeature)` early-return block inside Get-CurrentBranch.
        # Replaced with: Git Flow fallback (most-recently-modified dir) + same return.
        StartAnchor = '        if \(\$latestFeature\) \{'
        EndAnchor   = '    # Final fallback'
        SnippetPath = Join-Path $ScriptDir 'snippets/common-get-current-branch-gitflow.ps1'
        Name        = 'common.ps1 — Get-CurrentBranch: Git Flow dir fallback'
    },
    @{
        FilePath    = $commonScript
        # The condition block inside Test-FeatureBranch that validates branch naming.
        # Spec-cat upstream uses $hasMalformedTimestamp/$isSequential variables.
        # Replaced with: same logic + allow feature/* pattern; Get-FeatureName appended.
        StartAnchor = '    \$hasMalformedTimestamp = '
        EndAnchor   = '^function Get-FeatureDir'
        SnippetPath = Join-Path $ScriptDir 'snippets/common-test-feature-branch-get-feature-name.ps1'
        Name        = 'common.ps1 — Test-FeatureBranch: add feature/ pattern + insert Get-FeatureName'
    },
    @{
        FilePath    = $commonScript
        # Get-FeatureDir body — delegate to Get-FeatureName to strip feature/ prefix.
        StartAnchor = '^function Get-FeatureDir'
        EndAnchor   = '^function Get-FeaturePathsEnv'
        SnippetPath = Join-Path $ScriptDir 'snippets/common-get-feature-dir.ps1'
        Name        = 'common.ps1 — Get-FeatureDir: resolve via Get-FeatureName'
    },

    # ---------------------------------------------------------------------------
    # create-new-feature.ps1 — Git Flow support
    # ---------------------------------------------------------------------------
    @{
        FilePath    = $createFeatureScript
        # Param block — adds -GitFlow switch.
        StartAnchor = '^\[CmdletBinding\(\)\]'
        EndAnchor   = '^\$ErrorActionPreference'
        SnippetPath = Join-Path $ScriptDir 'snippets/create-new-feature-params.ps1'
        Name        = 'create-new-feature.ps1 — params: add -GitFlow switch'
    },
    @{
        FilePath    = $createFeatureScript
        # Help text block — updated usage / options / examples for Git Flow.
        StartAnchor = '^if \(\$Help\)'
        EndAnchor   = '^# Check if feature description provided'
        SnippetPath = Join-Path $ScriptDir 'snippets/create-new-feature-help.ps1'
        Name        = 'create-new-feature.ps1 — help: Git Flow usage + examples'
    },
    @{
        FilePath    = $createFeatureScript
        # Branch generation: adds GitFlow if/else while preserving Timestamp/DryRun paths.
        # Ends at the $featureDir line (not including it) so truncation stays in the patch.
        StartAnchor = '^# Generate branch name'
        EndAnchor   = '^\$featureDir = Join-Path \$specsDir \$branchName'
        SnippetPath = Join-Path $ScriptDir 'snippets/create-new-feature-branch-generation.ps1'
        Name        = 'create-new-feature.ps1 — branch generation: Git Flow mode + Timestamp/DryRun preserved'
    },
    @{
        FilePath    = $createFeatureScript
        # After $featureDir captures the short-name specs dir, reassign $branchName to
        # the full feature/ prefix so the downstream git checkout creates the right branch.
        StartAnchor = '^\$featureDir = Join-Path \$specsDir \$branchName$'
        EndAnchor   = '^\$specFile = Join-Path \$featureDir'
        SnippetPath = Join-Path $ScriptDir 'snippets/create-new-feature-featuredir-gitflow.ps1'
        Name        = 'create-new-feature.ps1 — featureDir: redirect branchName to feature/ for git checkout'
    }
)

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

$mode = if ($WhatIfPreference) { "DRY RUN — no files will be modified" } else { "applying patches" }
Write-Host "speckit patch: $mode"
Write-Host "Project root: $ProjectRoot"
Write-Host ""

$ok     = 0
$failed = 0

foreach ($p in $patches) {
    $result = Invoke-SectionPatch @p
    if ($result) { $ok++ } else { $failed++ }
}

Write-Host ""

if ($failed -eq 0) {
    Write-Host "Done. $ok/$($patches.Count) patches $(if ($WhatIfPreference) { 'verified' } else { 'applied' })."
} else {
    Write-Warning "Done. $ok/$($patches.Count) $(if ($WhatIfPreference) { 'verified' } else { 'applied' }), $failed skipped — review warnings above."
    exit 1
}
