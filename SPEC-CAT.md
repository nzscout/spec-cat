# spec-cat — CL Fork of Spec Kit

This repository is a **CL-customized fork** of [github/spec-kit](https://github.com/github/spec-kit).
It extends the upstream toolkit with additional workflow automation, agent files, and a single
`speckit init` command that bootstraps a project in one step.

All upstream functionality is preserved unchanged. CL additions live entirely in `cl-tools/` and
`src/specify_cli/cl_commands.py` — files that upstream will never create.

---

## Table of Contents

- [What's Added](#whats-added)
- [Install](#install)
- [Usage](#usage)
- [Versioning Strategy](#versioning-strategy)
- [Sync Flow](#sync-flow)
- [Development Setup](#development-setup)
- [Branch Model](#branch-model)

---

## What's Added

| Addition | Location | Purpose |
|----------|----------|---------|
| `speckit init` CLI command | `src/specify_cli/cl_commands.py` | Single command: runs `specify init` + patches + extras |
| Anchor-based patches | `cl-tools/patches/` | Injects custom steps into the generated `speckit.specify` agent |
| Extra agent files | `cl-tools/extras/` | Reviewer, comparer, context7, reconcile agents and prompts |
| PowerShell scripts | `cl-tools/scripts/powershell/` | Parallel worktree helpers |
| Automated sync | `.github/workflows/sync-upstream.yml` | Weekly upstream rebase + auto-release tagging |
| CL release workflow | `.github/workflows/release-cl.yml` | Builds wheel and publishes GitHub Release on CL tags |
| CL tag trigger | `.github/workflows/tag-cl-release.yml` | Converts a `vcl*` tag into a combined `v{upstream}-{cl}` release |

### Extra agent files deployed by `speckit init`

| File | Purpose |
|------|---------|
| `.github/agents/speckit.reviewer-code.agent.md` | Principal-engineer code review agent |
| `.github/agents/speckit.comparer-code.agent.md` | Compares two parallel implementations |
| `.github/agents/speckit.comparer-spec.agent.md` | Reconciles two spec artifact sets |
| `.github/agents/context7.agent.md` | Up-to-date library docs via Context7 |
| `.github/prompts/speckit.reconcile-code.prompt.md` | Reconcile code prompt |
| `.github/prompts/speckit.reconcile-spec.prompt.md` | Reconcile spec prompt || `.github/prompts/speckat.bootstrap-worktrees.prompt.md` | Bootstrap parallel worktrees prompt |
| `.github/prompts/speckat.git-commit.prompt.md` | Speckit-style git commit prompt || `.specify/memory/constitution.dotnet.md` | .NET constitution template |
| `.specify/memory/go-constitution.md` | Go constitution template |

---

## Install

Requires [uv](https://docs.astral.sh/uv/) and Python 3.11+.

### Pinned release (recommended)

Check [Releases](https://github.com/nzscout/spec-cat/releases) for the latest `v*-cl*` tag.

```bash
uv tool install specify-cli --force --from "git+https://github.com/nzscout/spec-cat.git@v0.5.1-cl1"
```

### Latest from cl/main (unreleased changes)

```bash
uv tool install specify-cli --force --from "git+https://github.com/nzscout/spec-cat.git@cl/main"
```

### Verify installation

```bash
specify --version   # upstream specify CLI
speckit --help      # CL-added command
```

---

## Usage

### `speckit init` — one-command project bootstrap

Runs three phases in sequence:

1. **`specify init`** — upstream init (creates `.github/agents/`, `.specify/`, etc.)
2. **Patches** — injects custom workflow steps into the generated `speckit.specify` agent
3. **Extras** — copies reviewer, comparer, and context7 agent files into the project

```bash
# Full bootstrap (recommended)
speckit init

# Preview without writing any files
speckit init --dry-run

# Skip copying extra agent files
speckit init --skip-extras

# Set a specific project root (default: current directory)
speckit init --project-root /path/to/project
```

#### What gets created

After `speckit init` in a new directory (in addition to everything `specify init` creates):

```
.github/
  agents/
    speckit.reviewer-code.agent.md           ← code review agent
    speckit.comparer-code.agent.md           ← implementation comparer
    speckit.comparer-spec.agent.md           ← spec reconciler
    context7.agent.md                        ← library docs agent
  prompts/
    speckit.reconcile-code.prompt.md
    speckit.reconcile-spec.prompt.md
    speckat.bootstrap-worktrees.prompt.md    ← parallel worktree bootstrap
    speckat.git-commit.prompt.md             ← git commit helper
.specify/
  memory/
    constitution.dotnet.md                   ← .NET constitution template
    go-constitution.md                       ← Go constitution template
```

The `speckit.specify` agent also gets two extra workflow steps injected:
- **Step 1 inject** — short-name generation guidance
- **Step 2 inject** — feature branch creation with `speckit` context

### `specify init` — upstream command (unchanged)

All upstream flags work as-is. See [upstream README](./README.md) for the full reference.

```bash
specify init my-project --ai copilot --script ps
specify init --here --ai copilot --force
specify check
```

---

## Versioning Strategy

CL versions are tracked independently from upstream using `vcl*` tags. Combined release tags
are computed automatically by the CI workflows.

### Tag types

| Tag | Owned by | Example | Meaning |
|-----|----------|---------|---------|
| `v*` (no suffix) | Upstream | `v0.5.1` | Upstream spec-kit release — on `main` only |
| `vcl*` | You | `vcl1`, `vcl1.1` | CL version marker — pushed manually to `cl/main` |
| `v*-cl*` | CI (auto) | `v0.5.1-cl1.1` | Combined release tag — created by workflows, installable |

### CL version lifecycle

```
You push: vcl1
  └─ tag-cl-release.yml fires
       └─ finds latest upstream tag (e.g. v0.5.1)
            └─ creates + pushes: v0.5.1-cl1
                 └─ release-cl.yml fires → GitHub Release published

You make a CL fix, push: vcl1.1
  └─ tag-cl-release.yml fires
       └─ creates + pushes: v0.5.1-cl1.1 → release published

Upstream releases v0.5.2 (detected by weekly sync):
  └─ sync-upstream.yml fast-forwards main, rebases cl/main
       └─ reads latest vcl* tag (vcl1.1)
            └─ creates + pushes: v0.5.2-cl1.1 → release published

You make another CL fix, push: vcl1.2
  └─ creates: v0.5.2-cl1.2 → release published
```

### Increment rules

- **Upstream bumped, CL unchanged** — upstream version changes, `cl` suffix stays: `v0.5.1-cl1.1` → `v0.5.2-cl1.1`
- **CL changed, upstream unchanged** — push a new `vcl*` tag with a higher number: `vcl1.1` → `vcl1.2`
- **Both changed** — sync happens first (auto), then push new `vcl*` tag manually

---

## Sync Flow

```
                    ┌─────────────────────────────────┐
                    │  sync-upstream.yml (weekly/manual)│
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │  Fetch upstream/main + all tags  │
                    └────────────────┬────────────────┘
                                     │
              ┌──────────────────────▼──────────────────────┐
              │         New upstream release tag?            │
              └──────────┬───────────────────────┬──────────┘
                         │ YES                   │ NO
          ┌──────────────▼───────────┐    ┌──────▼──────────────────┐
          │ Fast-forward main        │    │ New commits only?        │
          │ Rebase cl/main onto main │    └──────┬──────────────────┘
          └──────────────┬───────────┘           │ YES
                         │                ┌──────▼──────────────────┐
              ┌──────────▼──────────┐     │ Fast-forward main        │
              │ Rebase succeeded?   │     │ Open informational PR    │
              └──────┬──────┬───────┘     │ into cl/main            │
                     │ YES  │ NO          └─────────────────────────┘
                     │      └──────────────────────────┐
          ┌──────────▼───────────┐          ┌──────────▼───────────┐
          │ Verify patch anchors │          │ Create manual-        │
          │ Compute v*-cl* tag   │          │ resolution PR         │
          │ Push cl/main + tag   │          │ (sync/v*-manual)      │
          └──────────┬───────────┘          └──────────────────────┘
                     │
          ┌──────────▼───────────┐
          │  release-cl.yml      │
          │  Build wheel         │
          │  Fetch upstream notes│
          │  Publish GitHub      │
          │  Release             │
          └──────────────────────┘
```

### When you push a `vcl*` tag manually

```
git tag vcl1.1
git push origin vcl1.1
        │
        ▼
tag-cl-release.yml
  ├─ Reads latest upstream v* tag from origin/main
  ├─ Computes combined tag: v{upstream}-cl1.1
  └─ Pushes combined tag
           │
           ▼
     release-cl.yml
       ├─ Builds wheel from cl/main
       ├─ Fetches upstream release notes
       └─ Publishes GitHub Release
```

---

## Development Setup

```bash
git clone git@github.com:nzscout/spec-cat.git
cd spec-cat
git checkout cl/main

# Install with test dependencies
uv sync --extra test

# Run tests
uv run pytest

# Run linter
uv tool run ruff check src/

# Test the speckit CLI locally (without installing)
uv run speckit --help
uv run speckit init --dry-run
```

### Adding new extras

Extras are files copied once into a project by Phase 2 of `post-init.ps1`. Existing project files are never overwritten.

To add a new extra file:

1. **Add the source file** to `cl-tools/extras/` under the same relative path it should land in the target project.
   - Agent files → `cl-tools/extras/.github/agents/`
   - Prompt files → `cl-tools/extras/.github/prompts/`
   - Memory files → `cl-tools/extras/.specify/memory/`

2. **Register it** in the `$extras` array in `cl-tools/post-init.ps1`:
   ```powershell
   $extras = @(
       # ... existing entries ...
       '.github/prompts/my-new-prompt.prompt.md'   # ← add here
   )
   ```
   The relative path must match exactly — source is resolved under `cl-tools/extras/`, destination under the project root.

3. **Update SPEC-CAT.md** — add the file to the "Extra agent files" table and the "What gets created" tree.

> **Common mistake**: adding a file to `cl-tools/extras/` but forgetting to register it in `$extras`. The file will be silently skipped during `speckit init`.

### Parallel worktrees scripts

The `cl-tools/scripts/powershell/` directory contains helpers for parallel SDD workflows:

| Script | Purpose |
|--------|---------|
| `create-parallel-worktrees.ps1` | Entry point — creates feature branches + worktrees |
| `parallel-worktrees.ps1` | Core library (functions only, no side effects) |
| `common.ps1` | Not included here — sourced from the deployed `.specify/scripts/powershell/common.ps1` at runtime |

Worktree paths are derived automatically as siblings of the current repo directory with `.CL`, `.CP`, `.CG` suffixes (e.g. `D:\Work\MyProject` → `D:\Work\MyProject.CL`). Override with `-ClPath`/`-CpPath`/`-CgPath` when needed.

These scripts are **not** currently deployed by `speckit init` — they are intended to be placed manually (or via a future `specify preset`) into `.specify/scripts/powershell/` of the target project.

### Testing `speckit init` end-to-end

```powershell
$test = "$env:TEMP\speckit-e2e"
New-Item -ItemType Directory -Path $test -Force
Set-Location $test
git init

# Preview
speckit init --dry-run

# Full run
speckit init

# Verify patches applied
Select-String -Path ".github\agents\speckit.specify.agent.md" -Pattern "short-name"

# Verify extras copied
Test-Path ".github\agents\speckit.reviewer-code.agent.md"
Test-Path ".github\agents\context7.agent.md"
```

---

## Branch Model

| Branch | Contents | Who writes | Used for |
|--------|----------|-----------|---------|
| `main` | Clean upstream mirror | CI only (fast-forward) | Upstream sync target |
| `cl/main` | CL customizations rebased on `main` | You + CI (rebase) | Install source, default branch |
| `sync/upstream-*` | Informational (non-release upstream commits) | CI | Review PRs |
| `sync/v*-manual` | Created only on rebase failure | CI | Manual conflict resolution |

> **`cl/main` is the default branch.** Install from here or from a `v*-cl*` release tag.
