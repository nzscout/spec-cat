Set-StrictMode -Version Latest

function Get-ParallelWorktreeSuffixes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet(2, 3)]
        [int]$Count
    )

    $suffixes = @('CL', 'CP', 'CG')
    return $suffixes[0..($Count - 1)]
}

function Get-ParallelWorktreePathMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [string]$ClPath = '',
        [string]$CpPath = '',
        [string]$CgPath = ''
    )

    $repoName = Split-Path $RepoRoot -Leaf
    $parentDir = Split-Path $RepoRoot -Parent

    if (-not $ClPath) { $ClPath = Join-Path $parentDir "$repoName.CL" }
    if (-not $CpPath) { $CpPath = Join-Path $parentDir "$repoName.CP" }
    if (-not $CgPath) { $CgPath = Join-Path $parentDir "$repoName.CG" }

    return @{
        CL = [System.IO.Path]::GetFullPath($ClPath)
        CP = [System.IO.Path]::GetFullPath($CpPath)
        CG = [System.IO.Path]::GetFullPath($CgPath)
    }
}

function Invoke-Git {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [switch]$AllowFailure,

        [string]$ErrorMessage
    )

    Push-Location $RepoRoot
    try {
        $output = & git @Arguments 2>&1
        if (-not $AllowFailure -and $LASTEXITCODE -ne 0) {
            $message = if ($ErrorMessage) { $ErrorMessage } else { "git $($Arguments -join ' ') failed." }
            $details = ($output | Out-String).Trim()
            if ($details) {
                throw "$message $details"
            }

            throw $message
        }

        return ,$output
    }
    finally {
        Pop-Location
    }
}

function Get-GitCurrentBranch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $branch = (Invoke-Git -RepoRoot $RepoRoot -Arguments @('rev-parse', '--abbrev-ref', 'HEAD') -ErrorMessage 'Unable to determine the current git branch.' | Select-Object -First 1).Trim()
    if (-not $branch -or $branch -eq 'HEAD') {
        throw 'The current repository is in a detached HEAD state. Check out the source branch you want to fork from and rerun the bootstrap script.'
    }

    return $branch
}

function Test-GitBranchExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$BranchName
    )

    Invoke-Git -RepoRoot $RepoRoot -Arguments @('show-ref', '--verify', '--quiet', "refs/heads/$BranchName") -AllowFailure | Out-Null
    return $LASTEXITCODE -eq 0
}

function Get-GitWorktrees {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $lines = Invoke-Git -RepoRoot $RepoRoot -Arguments @('worktree', 'list', '--porcelain') -ErrorMessage 'Unable to query git worktrees.'
    $items = @()
    $current = @{}

    foreach ($line in $lines) {
        $text = [string]$line
        if ([string]::IsNullOrWhiteSpace($text)) {
            if ($current.ContainsKey('Path')) {
                $items += [PSCustomObject]$current
            }

            $current = @{}
            continue
        }

        if ($text.StartsWith('worktree ')) {
            $current.Path = [System.IO.Path]::GetFullPath($text.Substring(9).Trim())
            continue
        }

        if ($text.StartsWith('branch ')) {
            $current.BranchRef = $text.Substring(7).Trim()
            $current.BranchName = $current.BranchRef -replace '^refs/heads/', ''
            continue
        }

        if ($text.StartsWith('HEAD ')) {
            $current.Head = $text.Substring(5).Trim()
        }
    }

    if ($current.ContainsKey('Path')) {
        $items += [PSCustomObject]$current
    }

    return $items
}

function Ensure-ParallelWorktree {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$BaseBranch,

        [Parameter(Mandatory = $true)]
        [string]$CanonicalName,

        [Parameter(Mandatory = $true)]
        [string]$Suffix,

        [Parameter(Mandatory = $true)]
        [string]$WorktreePath,

        [Parameter(Mandatory = $true)]
        [object[]]$RegisteredWorktrees
    )

    $branchName = "feature/$CanonicalName-$Suffix"
    $normalizedPath = [System.IO.Path]::GetFullPath($WorktreePath)
    $specDirectory = Join-Path 'specs' "$CanonicalName-$Suffix"
    $specPath = Join-Path $normalizedPath $specDirectory

    $existingByPath = $RegisteredWorktrees | Where-Object { $_.Path -eq $normalizedPath } | Select-Object -First 1
    $existingByBranch = $RegisteredWorktrees | Where-Object { $_.BranchName -eq $branchName } | Select-Object -First 1

    $worktreeStatus = 'created'
    $branchStatus = 'created'

    if ($existingByPath) {
        if ($existingByPath.BranchName -ne $branchName) {
            throw "Worktree path '$normalizedPath' already exists for branch '$($existingByPath.BranchName)'. Expected '$branchName'."
        }

        $worktreeStatus = 'existing'
        $branchStatus = 'existing'
    }
    elseif (Test-Path $normalizedPath) {
        throw "Path '$normalizedPath' already exists but is not registered as a git worktree. Remove or relocate it before bootstrapping '$branchName'."
    }
    else {
        if ($existingByBranch) {
            throw "Branch '$branchName' is already checked out at '$($existingByBranch.Path)'. Reuse that worktree or remove it before creating a new one."
        }

        if (Test-GitBranchExists -RepoRoot $RepoRoot -BranchName $branchName) {
            $branchStatus = 'existing'
            Invoke-Git -RepoRoot $RepoRoot -Arguments @('worktree', 'add', $normalizedPath, $branchName) -ErrorMessage "Failed to add worktree '$normalizedPath' for existing branch '$branchName'." | Out-Null
        }
        else {
            Invoke-Git -RepoRoot $RepoRoot -Arguments @('worktree', 'add', '-b', $branchName, $normalizedPath, $BaseBranch) -ErrorMessage "Failed to create branch '$branchName' from '$BaseBranch' at '$normalizedPath'." | Out-Null
        }
    }

    if (-not (Test-Path $normalizedPath)) {
        throw "Expected worktree path '$normalizedPath' to exist after git worktree setup."
    }

    New-Item -ItemType Directory -Path $specPath -Force | Out-Null

    return [PSCustomObject]@{
        Suffix = $Suffix
        BranchName = $branchName
        Path = $normalizedPath
        SpecDirectory = $specDirectory
        WorktreeStatus = $worktreeStatus
        BranchStatus = $branchStatus
    }
}

function Invoke-ParallelWorktreeBootstrap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$CanonicalName,

        [Parameter(Mandatory = $true)]
        [ValidateSet(2, 3)]
        [int]$Count,

        [string]$ClPath = '',
        [string]$CpPath = '',
        [string]$CgPath = ''
    )

    if (-not (Test-Path (Join-Path $RepoRoot '.git'))) {
        throw "Repository root '$RepoRoot' does not look like a git working tree."
    }

    $baseBranch = Get-GitCurrentBranch -RepoRoot $RepoRoot
    $paths = Get-ParallelWorktreePathMap -RepoRoot $RepoRoot -ClPath $ClPath -CpPath $CpPath -CgPath $CgPath
    $suffixes = Get-ParallelWorktreeSuffixes -Count $Count
    $registeredWorktrees = Get-GitWorktrees -RepoRoot $RepoRoot
    $created = @()

    foreach ($suffix in $suffixes) {
        $created += Ensure-ParallelWorktree -RepoRoot $RepoRoot -BaseBranch $baseBranch -CanonicalName $CanonicalName -Suffix $suffix -WorktreePath $paths[$suffix] -RegisteredWorktrees $registeredWorktrees
        $registeredWorktrees = Get-GitWorktrees -RepoRoot $RepoRoot
    }

    return [PSCustomObject]@{
        RepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
        BaseBranch = $baseBranch
        CanonicalName = $CanonicalName
        Worktrees = $created
    }
}