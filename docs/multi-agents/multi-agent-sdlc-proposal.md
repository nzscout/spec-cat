# Multi-Agent Parallel Implementation SDLC

**Status**: Proposal  
**Date**: 2026-04-01  
**Context**: VLS.Cloud — SpecKit SDD workflow with GitHub Copilot (primary)

---

## Executive Summary

Run 2–3 LLM agents implementing the **same feature from the same spec** in
isolated git worktrees. Compare, select the winner, cherry-pick the best of
the rest, and consolidate a single feature branch for merge to `main`. Repeat
per feature. The spec is written once; only implementation diverges.

---

## 1. Branching Model

Trunk-based development remains the governance model (per constitution). Parallel
implementation branches are short-lived and disposable — they exist only during
the implementation race and are deleted after consolidation.

```
main ─────────────────────────────────────────────────────────► time
  │
  └─ feature/NNN-feature-name                 ← spec branch (shared artifacts)
       │
       ├─ feature/NNN-feature-name/cp         ← Copilot implementation
       ├─ feature/NNN-feature-name/cl         ← Claude implementation
       ├─ feature/NNN-feature-name/gm         ← Gemini implementation (optional)
       │
       └─ feature/NNN-feature-name/win        ← consolidated winner
                                                 ↓
                                            merge → main
```

**Branch naming convention** (extends current Git Flow mode):

| Branch | Purpose |
|---|---|
| `feature/NNN-name` | Spec-only branch. Contains `specs/NNN-name/` artifacts (spec.md, plan.md, tasks.md, etc.) and no implementation code. |
| `feature/NNN-name/cp` | Copilot implementation worktree. |
| `feature/NNN-name/cl` | Claude implementation worktree. |
| `feature/NNN-name/gm` | Gemini implementation worktree. |
| `feature/NNN-name/win` | Consolidated best-of-breed branch for merge to `main`. |

The `/cp`, `/cl`, `/gm` suffixes are agent tags. You can substitute any
mnemonic (`/o1`, `/sonnet`, `/gpt`, etc.) — the key is consistency per project.

---

## 2. Directory Layout — Worktrees

```
C:\Projects\Eclypsium\
├── VLS.Cloud\                          ← main worktree (main branch)
│
├── worktrees\
│   ├── NNN-feature\                    ← spec worktree (feature/NNN-feature)
│   │
│   ├── NNN-feature-cp\                 ← Copilot worktree (feature/NNN-feature/cp)
│   ├── NNN-feature-cl\                 ← Claude worktree  (feature/NNN-feature/cl)
│   ├── NNN-feature-gm\                 ← Gemini worktree  (feature/NNN-feature/gm)
│   │
│   └── NNN-feature-win\               ← consolidation worktree (feature/NNN-feature/win)
│
│   # When running multiple features in parallel:
│   ├── MMM-other-feature\
│   ├── MMM-other-feature-cp\
│   ├── MMM-other-feature-cl\
│   └── ...
```

Each worktree gets its own VS Code window (or agent CLI session). Worktrees
share the same `.git` object store so they are lightweight and branches are
immediately visible across all worktrees.

**Workspace files**: Each agent worktree should open the appropriate
`.code-workspace` file (e.g., `VLS.Cloud.Go.code-workspace` for Go features).

---

## 3. The Five-Phase Lifecycle

### Phase 0 — Spec (Single Author, Human-Gated)

**Who**: You + one LLM of your choice.  
**Where**: Spec worktree (`worktrees/NNN-feature/`).  
**Goal**: Produce a reviewed, approved specification that all agents implement from.

```
/speckit.specify   → specs/NNN-feature/spec.md
/speckit.clarify   → interactive refinement
/speckit.plan      → specs/NNN-feature/plan.md, research.md, data-model.md, contracts/
/speckit.tasks     → specs/NNN-feature/tasks.md
/speckit.analyze   → cross-artifact consistency check
/speckit.checklist → specs/NNN-feature/checklists/ (optional quality gates)
```

**Gate**: You review and approve all spec artifacts before proceeding.
This is the most critical gate — a bad spec produces two bad implementations.

**Commit**: All spec artifacts are committed on `feature/NNN-feature-name`.

### Phase 1 — Fork & Implement (Parallel, Multi-Agent)

**Who**: Each LLM independently.  
**Where**: Separate worktrees forked from the spec branch.

**Setup** (one-time per feature):

```powershell
# From the main repo directory
$feature = "NNN-feature-name"
$base    = "feature/$feature"

# Create implementation branches from the spec branch
git worktree add ../worktrees/$feature-cp  -b "feature/$feature/cp"  $base
git worktree add ../worktrees/$feature-cl  -b "feature/$feature/cl"  $base
git worktree add ../worktrees/$feature-gm  -b "feature/$feature/gm"  $base  # optional
```

**Each agent** opens its worktree in a separate VS Code window and runs:

```
/speckit.implement
```

Agents work from the same `specs/NNN-feature/tasks.md` and the same
`plan.md`. They share the constitution and all project-level steering files
(`.specify/memory/constitution.md`, `AGENTS.md`, etc.) because those come from
the spec branch which is their common ancestor.

**Rules for parallel implementation**:
- Agents MUST NOT modify spec artifacts (`spec.md`, `plan.md`, `tasks.md`).
  If an agent encounters ambiguity, it should document the assumption in a local
  `specs/NNN-feature/implementation-notes-{agent}.md` file.
- Each agent maintains its own commit history on its branch.
- Agents follow the constitution's commit strategy (atomic, buildable commits).
- Quality gates (build, test, lint) should pass on each branch independently.

### Phase 2 — Compare & Select (Human + Comparer Agents)

**Who**: You, assisted by `speckat.comparer-code` and `speckat.comparer-spec`.  
**Where**: Any worktree (typically the main worktree or a dedicated review window).

**Step 2a — Automated Quality Gates**

Run build + test + lint on each implementation branch. Record pass/fail:

```powershell
# For each agent worktree:
Push-Location ../worktrees/$feature-cp
dotnet build; dotnet test      # or: go test ./... ; go vet ./...
Pop-Location
# repeat for -cl, -gm
```

If a branch doesn't build or pass tests, it's eliminated or penalized.

**Step 2b — Spec Comparison** (if spec artifacts diverged)

Invoke `@speckat.comparer-spec` from VS Code with the two implementation
branches. It compares `specs/` artifacts across branches and identifies:
- Gaps and contradictions.
- Missing NFRs.
- Ambiguity in requirements.

**Step 2c — Code Comparison**

Invoke `@speckat.comparer-code` with the two (or three) implementation branches.
It evaluates across seven dimensions:

1. Correctness & robustness
2. Architecture & maintainability
3. Design patterns
4. Testing & quality gates
5. Performance & scalability
6. Security
7. Operational readiness

Output: A comparison report with:
- **Recommended foundation** (the branch to base consolidation on).
- **Cherry-pick list** (specific files, types, or patterns from other branches).
- **Risk assessment** for each cherry-pick.

**Step 2d — Human Decision**

You review the comparer output and make the final call:
- Select the winner branch.
- Approve/reject each cherry-pick recommendation.
- Note any manual adjustments needed.

### Phase 3 — Consolidate (Human-Guided)

**Who**: You + your preferred LLM.  
**Where**: Consolidation worktree.

```powershell
# Create the winner branch from the winning implementation
$winner = "cl"  # or "cp" or "gm"
git worktree add ../worktrees/$feature-win -b "feature/$feature/win" "feature/$feature/$winner"
```

In the consolidation worktree:

1. **Cherry-pick** approved items from non-winner branches.
2. **Resolve conflicts** if any.
3. **Run the full quality gate suite**:
   - .NET: `dotnet build` (zero warnings), `dotnet test`
   - Go: `go test ./...`, `go vet ./...`, `staticcheck ./...`, `golangci-lint run`
4. **Invoke `@speckat.reviewer-code`** on the consolidated branch for a
   final Principal-Engineer-grade review.
5. **Run `/speckit.verify`** (or equivalent) to confirm spec compliance.

### Phase 4 — Merge & Clean Up

**Who**: You.  
**Where**: Main worktree.

1. **Create MR/PR** from `feature/NNN-feature/win` → `main`.
2. **GitLab CI/CD pipeline** runs all required jobs.
3. **Constitution compliance check** per merge request requirements.
4. **Merge** on green pipeline.
5. **Clean up**:

```powershell
$feature = "NNN-feature-name"
# Remove worktrees
git worktree remove ../worktrees/$feature-cp  --force
git worktree remove ../worktrees/$feature-cl  --force
git worktree remove ../worktrees/$feature-gm  --force
git worktree remove ../worktrees/$feature-win --force
git worktree remove ../worktrees/$feature     --force

# Delete remote branches
git push origin --delete "feature/$feature/cp"
git push origin --delete "feature/$feature/cl"
git push origin --delete "feature/$feature/gm"
git push origin --delete "feature/$feature/win"
git push origin --delete "feature/$feature"
```

---

## 4. Running Multiple Features in Parallel

When you pipeline features (feature A is in Phase 2 while feature B is in
Phase 1), the worktree layout scales horizontally:

```
worktrees/
├── 015-auth-redesign/          ← feature A spec
├── 015-auth-redesign-cp/       ← feature A — Copilot
├── 015-auth-redesign-cl/       ← feature A — Claude
├── 015-auth-redesign-win/      ← feature A — consolidation
│
├── 016-mcp-pagination/         ← feature B spec
├── 016-mcp-pagination-cp/      ← feature B — Copilot
├── 016-mcp-pagination-cl/      ← feature B — Claude
└── ...
```

Each feature is fully isolated. Features that touch different parts of the
codebase can run in parallel without conflict. Features that overlap should be
serialized (merge A before starting B's implementation phase).

---

## 5. Tooling Map

| Phase | SpecKit Command / Agent | Purpose |
|---|---|---|
| 0 — Spec | `/speckit.specify`, `/speckit.clarify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.analyze` | Produce spec artifacts |
| 0 — Spec | `/speckit.checklist` | Optional quality gate for spec |
| 1 — Implement | `/speckit.implement` | Each LLM implements independently |
| 2 — Compare | `@speckat.comparer-spec` | Compare spec artifacts if they diverged |
| 2 — Compare | `@speckat.comparer-code` | Compare implementations, select winner |
| 3 — Consolidate | `@speckat.reviewer-code` | Review consolidated branch |
| 3 — Consolidate | `speckit.verify` / quality gates | Final validation |
| 4 — Merge | GitLab CI/CD | Pipeline gate before merge |

---

## 6. Automation Script — `setup-parallel-impl.ps1`

A helper script to automate Phase 1 worktree creation:

```powershell
#!/usr/bin/env pwsh
# Usage: ./setup-parallel-impl.ps1 -Feature "NNN-feature-name" -Agents cp,cl,gm
param(
    [Parameter(Mandatory)] [string]$Feature,
    [string[]]$Agents = @("cp", "cl"),
    [string]$WorktreeRoot = "../worktrees"
)

$specBranch = "feature/$Feature"

# Verify spec branch exists
$branches = git branch --list $specBranch 2>&1
if (-not $branches) {
    Write-Error "Spec branch '$specBranch' not found. Run Phase 0 first."
    exit 1
}

# Create worktrees
foreach ($agent in $Agents) {
    $branch = "feature/$Feature/$agent"
    $path   = Join-Path $WorktreeRoot "$Feature-$agent"

    if (Test-Path $path) {
        Write-Host "Worktree already exists: $path" -ForegroundColor Yellow
        continue
    }

    Write-Host "Creating worktree: $path → $branch" -ForegroundColor Cyan
    git worktree add $path -b $branch $specBranch
}

Write-Host "`nWorktrees ready. Open each in a separate VS Code window:" -ForegroundColor Green
foreach ($agent in $Agents) {
    $path = Resolve-Path (Join-Path $WorktreeRoot "$Feature-$agent")
    Write-Host "  code `"$path`""
}
```

---

## 7. Automation Script — `cleanup-parallel-impl.ps1`

A helper script to automate Phase 4 cleanup:

```powershell
#!/usr/bin/env pwsh
# Usage: ./cleanup-parallel-impl.ps1 -Feature "NNN-feature-name" -Agents cp,cl,gm
param(
    [Parameter(Mandatory)] [string]$Feature,
    [string[]]$Agents = @("cp", "cl"),
    [switch]$IncludeSpec,
    [switch]$DeleteRemote,
    [string]$WorktreeRoot = "../worktrees"
)

# Remove agent worktrees
foreach ($agent in $Agents) {
    $path = Join-Path $WorktreeRoot "$Feature-$agent"
    if (Test-Path $path) {
        Write-Host "Removing worktree: $path" -ForegroundColor Yellow
        git worktree remove $path --force
    }
    if ($DeleteRemote) {
        git push origin --delete "feature/$Feature/$agent" 2>$null
    }
}

# Remove winner worktree
$winPath = Join-Path $WorktreeRoot "$Feature-win"
if (Test-Path $winPath) {
    git worktree remove $winPath --force
    if ($DeleteRemote) {
        git push origin --delete "feature/$Feature/win" 2>$null
    }
}

# Remove spec worktree (optional — you may want to keep it)
if ($IncludeSpec) {
    $specPath = Join-Path $WorktreeRoot $Feature
    if (Test-Path $specPath) {
        git worktree remove $specPath --force
        if ($DeleteRemote) {
            git push origin --delete "feature/$Feature" 2>$null
        }
    }
}

git worktree prune
Write-Host "Cleanup complete." -ForegroundColor Green
```

---

## 8. Decision Framework — When to Use Multi-Agent vs. Single-Agent

Not every feature warrants running 2–3 agents in parallel. Use this heuristic:

| Criteria | Multi-Agent | Single-Agent |
|---|---|---|
| Feature complexity | High (new domain, multiple user stories) | Low (bug fix, config change, small feature) |
| Architectural risk | High (multiple valid approaches exist) | Low (clear single approach) |
| Learning goal | Want to compare model strengths | Know which model is best for this task |
| Time budget | Can afford parallel implementation time | Tight deadline |
| Feature size | Medium to large (multi-day) | Small (< half day) |

---

## 9. Comparison Checklist

When running Phase 2, use this structured checklist:

```markdown
## Comparison: feature/NNN-feature/cp vs feature/NNN-feature/cl

### Quality Gates
- [ ] CP: builds cleanly (zero warnings)
- [ ] CL: builds cleanly (zero warnings)
- [ ] CP: all tests pass
- [ ] CL: all tests pass
- [ ] CP: lint/vet clean
- [ ] CL: lint/vet clean

### Comparer Output
- [ ] speckat.comparer-spec ran (if applicable)
- [ ] speckat.comparer-code ran
- [ ] Winner selected: ___
- [ ] Cherry-pick list reviewed and approved

### Consolidation
- [ ] Winner branch forked to /win
- [ ] Cherry-picks applied
- [ ] Conflicts resolved
- [ ] Full quality gate re-run on /win
- [ ] speckat.reviewer-code passed
- [ ] Ready for MR
```

---

## 10. Integration with Existing Agents

Your existing agent definitions already support this workflow:

| Agent | Role in This Flow |
|---|---|
| `speckat.comparer-code` | Phase 2 — Compares two implementations, selects foundation, recommends cherry-picks. Already aligned to your spec conventions and seven review dimensions. |
| `speckat.comparer-spec` | Phase 2 — Reconciles spec artifacts if implementations interpreted specs differently. |
| `speckat.reviewer-code` | Phase 3 — Final review of the consolidated branch before MR. |
| `speckit.implement` | Phase 1 — Each LLM's implementation agent. |
| `speckit.specify`, `speckit.plan`, `speckit.tasks` | Phase 0 — Standard SDD spec authoring. |

No new agents are required. The existing comparer agents are designed exactly
for this workflow — they already reference "CP" and "CL" worktrees in their
documentation and expect parallel branch structures.

---

## 11. SpecKit Ecosystem Alignment

This workflow aligns with established patterns in the SpecKit community:

- **MAQA extension** (`spec-kit-maqa-ext`): Similar coordinator → feature → QA
  agent pattern with parallel worktree-based implementation.
- **cc-spex** (formerly cc-sdd): Composable `worktrees` trait for git worktree
  isolation and `teams` trait for parallel agent execution.
- **SpecKit "Creative Exploration" phase**: Officially lists "Parallel
  implementations — Explore diverse solutions" as a development phase.

Your approach is a natural fit for how the SDD community handles parallel
exploration. The key differentiator in your setup is that you're comparing
across LLM vendors (model-level parallelism) rather than across architectural
approaches — though the git mechanics are identical.

---

## 12. Flow Diagram

```
                    ┌─────────────────────┐
                    │   Phase 0: Spec     │
                    │   (single author)   │
                    │                     │
                    │ specify → clarify   │
                    │ → plan → tasks      │
                    │ → analyze           │
                    └─────────┬───────────┘
                              │
                    ┌─────────▼───────────┐
                    │   Human Gate:       │
                    │   Approve Spec      │
                    └─────────┬───────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
    ┌─────────▼──────┐ ┌─────▼──────┐ ┌──────▼─────────┐
    │  Phase 1: CP   │ │ Phase 1: CL│ │ Phase 1: GM    │
    │  (Copilot)     │ │ (Claude)   │ │ (Gemini)       │
    │                │ │            │ │                │
    │  /implement    │ │ /implement │ │ /implement     │
    │  in worktree   │ │ in worktree│ │ in worktree    │
    └───────┬────────┘ └─────┬──────┘ └──────┬─────────┘
            │                │               │
            └────────────────┼───────────────┘
                             │
                   ┌─────────▼───────────┐
                   │  Phase 2: Compare   │
                   │                     │
                   │ quality gates       │
                   │ comparer-spec       │
                   │ comparer-code       │
                   │ → select winner     │
                   │ → cherry-pick list  │
                   └─────────┬───────────┘
                             │
                   ┌─────────▼───────────┐
                   │  Human Gate:        │
                   │  Approve Winner     │
                   └─────────┬───────────┘
                             │
                   ┌─────────▼───────────┐
                   │  Phase 3:           │
                   │  Consolidate        │
                   │                     │
                   │  fork winner → /win │
                   │  cherry-pick        │
                   │  reviewer-code      │
                   │  verify             │
                   └─────────┬───────────┘
                             │
                   ┌─────────▼───────────┐
                   │  Phase 4: Merge     │
                   │                     │
                   │  MR → main          │
                   │  CI/CD pipeline     │
                   │  cleanup worktrees  │
                   └─────────────────────┘
```

---

## 13. Constitution Amendment Required

To formalize this workflow, consider adding the following to the constitution's
Development Workflow section:

```markdown
### Parallel Implementation Strategy (Optional)

For features where architectural risk or model-quality comparison justifies it,
parallel implementation across multiple AI agents MAY be used.

- Spec artifacts MUST be authored once and shared across all implementation branches.
- Implementation branches MUST fork from the spec branch.
- Implementation branches MUST NOT modify shared spec artifacts.
- Each implementation branch MUST independently pass all quality gates.
- A formal comparison (using comparer agents or manual review) MUST be performed
  before selecting the winner.
- Consolidation MUST produce a single branch that passes all quality gates
  before creating a merge request.
- All parallel branches and worktrees MUST be cleaned up after merge.
```

---

## 14. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Spec ambiguity causes divergent interpretations | Invest more in Phase 0 clarify/checklist; run comparer-spec early |
| Merge conflicts during cherry-pick | Keep cherry-picks surgical (individual files/functions, not whole directories) |
| Worktree proliferation on disk | Enforce cleanup script after every merge; limit to 2 features in parallel |
| Agent modifies spec artifacts | Constitution rule + pre-commit hook checking `specs/` on impl branches |
| Time cost of running 3 agents | Start with 2 agents; add third only for high-risk features |
| Context window limits for comparers | Point comparer at specific directories/files rather than whole repo |
