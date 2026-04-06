---
agent: 'agent'
description: 'Bootstrap CL, CP, and optionally CG feature worktrees and spec folders from the current branch. Use when you want to create parallel implementation branches for a canonical feature name.'
tools: ['runCommands', 'search', 'changes']
---

# Bootstrap Parallel Worktrees

Create parallel feature branches and worktrees by running the repository bootstrap script.

## Expected Input

Use either of these forms:

- `<canonical-name>`
- `<canonical-name> <count>`

Examples:

- `DATA-5330-Migrate-v1-to-v2-go`
- `DATA-5330-Migrate-v1-to-v2-go 3`

If count is omitted, default to `2`.

## Required Behavior

1. Parse the canonical name and optional count from the user input.
2. If the count is omitted, use `2`.
3. Run this command from the repository root:

```powershell
.specify/scripts/powershell/create-parallel-worktrees.ps1 -CanonicalName "<canonical-name>" -Count <count> -Json
```

4. Summarize the result using the returned JSON.

## Notes

- The script always forks from the currently checked-out branch.
- Worktree paths are derived automatically as siblings of the current repo folder with `.CL`, `.CP`, `.CG` suffixes. For example, if the repo is at `D:\Work\MyProject`, worktrees will be at `D:\Work\MyProject.CL`, `D:\Work\MyProject.CP`, `D:\Work\MyProject.CG`.
- Individual paths can be overridden with `-ClPath`, `-CpPath`, or `-CgPath` if needed.
- The suffix order is always `CL`, `CP`, `CG`.