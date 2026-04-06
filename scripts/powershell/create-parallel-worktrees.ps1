#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string]$CanonicalName,

    [ValidateSet(2, 3)]
    [int]$Count,

    [switch]$Json,

    [string]$ClPath = 'C:\Projects\Eclypsium\VLS.Cloud.CL',
    [string]$CpPath = 'C:\Projects\Eclypsium\VLS.Cloud.CP',
    [string]$CgPath = 'C:\Projects\Eclypsium\VLS.Cloud.CG',

    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host 'Usage: ./create-parallel-worktrees.ps1 -CanonicalName <name> -Count <2|3> [-Json]'
    Write-Host ''
    Write-Host 'Creates feature branches from the currently checked-out branch and attaches them to fixed worktree locations:'
    Write-Host '  CL -> C:\Projects\Eclypsium\VLS.Cloud.CL'
    Write-Host '  CP -> C:\Projects\Eclypsium\VLS.Cloud.CP'
    Write-Host '  CG -> C:\Projects\Eclypsium\VLS.Cloud.CG'
    Write-Host ''
    Write-Host 'Examples:'
    Write-Host "  ./create-parallel-worktrees.ps1 -CanonicalName 'DATA-5330-Migrate-v1-to-v2-go' -Count 2"
    Write-Host "  ./create-parallel-worktrees.ps1 -CanonicalName 'DATA-5330-Migrate-v1-to-v2-go' -Count 3 -Json"
    exit 0
}

if (-not $CanonicalName) {
    throw 'CanonicalName is required unless -Help is specified.'
}

if ($Count -notin @(2, 3)) {
    throw 'Count must be 2 or 3.'
}

. "$PSScriptRoot/common.ps1"
. "$PSScriptRoot/parallel-worktrees.ps1"

$repoRoot = Get-RepoRoot
$result = Invoke-ParallelWorktreeBootstrap -RepoRoot $repoRoot -CanonicalName $CanonicalName -Count $Count -ClPath $ClPath -CpPath $CpPath -CgPath $CgPath

if ($Json) {
    $result | ConvertTo-Json -Depth 5
    exit 0
}

Write-Host "Base branch: $($result.BaseBranch)"
Write-Host "Canonical name: $($result.CanonicalName)"
foreach ($worktree in $result.Worktrees) {
    Write-Host ''
    Write-Host "[$($worktree.Suffix)] $($worktree.BranchName)"
    Write-Host "  Path: $($worktree.Path)"
    Write-Host "  Spec: $($worktree.SpecDirectory)"
    Write-Host "  Branch status: $($worktree.BranchStatus)"
    Write-Host "  Worktree status: $($worktree.WorktreeStatus)"
}