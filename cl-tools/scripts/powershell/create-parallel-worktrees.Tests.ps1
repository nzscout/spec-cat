Set-StrictMode -Version Latest

$script:helperPath = Join-Path $PSScriptRoot 'parallel-worktrees.ps1'

Describe 'Get-ParallelWorktreeSuffixes' {
    BeforeAll {
        . $script:helperPath
    }

    It 'returns CL and CP when count is 2' {
        $result = Get-ParallelWorktreeSuffixes -Count 2

        $result.Count | Should Be 2
        $result[0] | Should Be 'CL'
        $result[1] | Should Be 'CP'
    }

    It 'returns CL, CP and CG when count is 3' {
        $result = Get-ParallelWorktreeSuffixes -Count 3

        $result.Count | Should Be 3
        $result[0] | Should Be 'CL'
        $result[1] | Should Be 'CP'
        $result[2] | Should Be 'CG'
    }
}

Describe 'Invoke-ParallelWorktreeBootstrap' {
    BeforeAll {
        . $script:helperPath
    }

    It 'creates worktrees, feature branches and spec folders from the current branch' {
        $repoRoot = Join-Path $TestDrive 'repo'
        $null = New-Item -ItemType Directory -Path $repoRoot
        Push-Location $repoRoot
        try {
            git init --initial-branch main | Out-Null
            git config user.email 'copilot@example.com'
            git config user.name 'GitHub Copilot'

            $null = New-Item -ItemType Directory -Path (Join-Path $repoRoot 'specs')
            Set-Content -Path (Join-Path $repoRoot 'README.md') -Value 'test repo'
            git add . | Out-Null
            git commit -m 'init' | Out-Null

            $result = Invoke-ParallelWorktreeBootstrap `
                -RepoRoot $repoRoot `
                -CanonicalName 'DATA-5330-Migrate-v1-to-v2-go' `
                -Count 2 `
                -ClPath (Join-Path $TestDrive 'VLS.Cloud.CL') `
                -CpPath (Join-Path $TestDrive 'VLS.Cloud.CP') `
                -CgPath (Join-Path $TestDrive 'VLS.Cloud.CG')

            $result.BaseBranch | Should Be 'main'
            $result.Worktrees.Count | Should Be 2
            $result.Worktrees[0].BranchName | Should Be 'feature/DATA-5330-Migrate-v1-to-v2-go-CL'
            $result.Worktrees[1].BranchName | Should Be 'feature/DATA-5330-Migrate-v1-to-v2-go-CP'

            foreach ($worktree in $result.Worktrees) {
                (Test-Path $worktree.Path) | Should Be $true
                (Test-Path (Join-Path $worktree.Path $worktree.SpecDirectory)) | Should Be $true
            }

            $branches = git branch --format '%(refname:short)'
            ($branches -contains 'feature/DATA-5330-Migrate-v1-to-v2-go-CL') | Should Be $true
            ($branches -contains 'feature/DATA-5330-Migrate-v1-to-v2-go-CP') | Should Be $true
        }
        finally {
            Pop-Location
        }
    }
}