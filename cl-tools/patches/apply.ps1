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

$specifyAgent = Join-Path $ProjectRoot ".github/agents/speckit.specify.agent.md"

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
        # Upstream heading: "2. **Create the feature branch** by running the script..."
        StartAnchor = '^2\. \*\*Create the feature branch\*\* by running'
        # Next section heading starts with "3. "
        EndAnchor   = '^3\. '
        SnippetPath = Join-Path $ScriptDir 'snippets/specify-step2.md'
        Name        = 'specify.agent — step 2: Git Flow mode + current-branch reuse'
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
