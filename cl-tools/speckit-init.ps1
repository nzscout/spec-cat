#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Drop-in replacement for: specify init --here --force --ai copilot
    Runs specify init then immediately applies CL patches and extras.

.PARAMETER ProjectRoot
    Defaults to CWD.

.PARAMETER WhatIf
    Dry-run: pass -WhatIf through to post-init without writing files.

.EXAMPLE
    C:\Tools\CL-Speckit-updates\speckit-init.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

Write-Host "Running: specify init --here --force --ai copilot"
specify init --here --force --ai copilot
if ($LASTEXITCODE -ne 0) {
    Write-Error "specify init failed (exit $LASTEXITCODE)."
    exit $LASTEXITCODE
}

$postInit = Join-Path $PSScriptRoot 'post-init.ps1'
if ($WhatIfPreference) {
    & $postInit -ProjectRoot $ProjectRoot -WhatIf
} else {
    & $postInit -ProjectRoot $ProjectRoot
}
exit $LASTEXITCODE
