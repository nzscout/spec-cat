---
description: Reconcile SpecKit-generated specification artifacts across CP vs CL branches (specify/clarify/plan stage) and propose a single unified spec set.
argument-hint: "Usually no inputs required. Optionally provide: focus notes, ignore paths, or special constraints."
agent: speckit.comparer-spec
---

You are reconciling two SpecKit-generated specification sets for the same feature. This is the **spec-writing stage** only:
- `/specify`, `/clarify`, `/plan` have been run
- No tasks have been generated yet
- No implementation work has started

You do **not** implement product code. You only reconcile SpecKit artifacts under the canonical locations inferred below.

## Worktrees (fixed references)

Use these worktrees and refer to them exactly as:
- **CP-project**: `C:\Projects\Eclypsium\agent-perry`
- **CL-Project**: `C:\Projects\Eclypsium\agent-perry.worktrees\ap-dev-cl`

---

# What you should infer (do not ask the user unless inference fails)

## 1) Infer branch names (feature identifiers)
For each worktree:
- Determine the currently checked-out branch name (the “feature branch”).
- Treat that branch as the feature identifier.

If a worktree is detached, cannot determine the branch, or branches are clearly not comparable, ask the user to confirm the intended branch names.

## 2) Infer SpecKit scaffold location
In each worktree, infer the SpecKit scaffold folder at repo root:
- `.specify/`

Use it as background guidance (templates/constitution) to normalize spec structure.
Do not compare `.specify/` content unless the user explicitly requests; only flag notable mismatches.

## 3) Infer spec roots (canonical spec artifact locations)
Repository convention:
- Spec folder name matches the feature branch name.

Therefore infer:
- CP spec root: `specs/<cp-branch>/`
- CL spec root: `specs/<cl-branch>/`

Validation requirements:
- Each root must exist on its branch and contain at least `spec.md` (or an obvious equivalent).
- If either root is missing, treat it as a **BLOCKER** and stop with diagnostics and next steps.

If the exact folder does not exist, run diagnostics first:
- List `specs/` folders on that branch and locate the closest match (same numeric prefix or slug).
- If a close match exists, propose the mapping, but still treat it as **BLOCKER** until the user confirms the mapping.

## 4) Infer stage (specify/clarify/plan)
Assume this stage unless evidence shows otherwise:
- `tasks.md` may be missing; do not treat it as an error.
- Missing `plan.md` or `checklists/requirements.md` are gaps to address (not blockers) unless repo conventions require them.

## 5) Infer default output filename
Default the report filename to:
- If branches match: `reconcile-spec-<branch>.md`
- If branches differ: `reconcile-spec-CP-<cp-branch>__CL-<cl-branch>.md`

---

# Optional user inputs (only if provided; otherwise proceed)

If the user supplies any of the following, incorporate them. If not provided, do not ask.
- Focus notes (e.g., correctness/clarity, architecture, NFRs, security, rollout, observability)
- Out-of-scope / ignore paths within the spec roots
- Special constraints / non-functional requirements / rollout concerns

---

# Hard rules (must follow)

1) Only review and propose changes to files under `specs/<cp-branch>/` and `specs/<cl-branch>/`.
2) Do not implement product code.
3) Do not commit, push, merge, rebase, or cherry-pick until the user explicitly says **GO**.
4) Avoid generic summaries. Every surfaced difference must map to an actionable **Issue/Decision** item.
5) Cite evidence: file + section heading, plus a minimal excerpt or diff hunk summary.
6) Prefer clarity and verifiability: each requirement should be measurable and testable later.

---

# Procedure (execute in order)

## Step 0 — Resolve inferred inputs
Within each worktree, capture:
- current branch name
- whether `.specify/` exists
- whether inferred spec root exists

If branch resolution fails, stop and ask for branch names.

## Step 1 — Worktree resolution (and fallback)
Attempt to locate worktree paths via git:

```bash
git worktree list --porcelain
```

If you cannot locate one of the branches’ worktree paths, do **not** stop:
- Use git object access (branch snapshots) instead of filesystem paths.

Object access primitives:
- List files:
  ```bash
  git ls-tree -r --name-only "<branch>" -- "specs/<branch>/"
  ```
- Read a file:
  ```bash
  git show "<branch>:specs/<branch>/<logical_path>"
  ```

Troubleshooting suggestions (do not execute unless asked):
- Verify worktrees:
  ```bash
  git worktree list
  ```
- Add missing worktree:
  ```bash
  git worktree add ../wt-<branch> <branch>
  ```

## Step 2 — Validate authoritative roots (BLOCKER if missing)
Set:
- `CP_ROOT="specs/<cp-branch>/"`
- `CL_ROOT="specs/<cl-branch>/"`

Validate each root exists in its branch:

```bash
git ls-tree -d "<cp-branch>" -- "specs/<cp-branch>"
git ls-tree -d "<cl-branch>" -- "specs/<cl-branch>"
```

If either root is missing:
- Mark **BLOCKER**
- Provide diagnostics: list what exists under `specs/` on that branch
- Stop without proceeding

Diagnostics:
```bash
git ls-tree -d "<branch>" -- "specs"
git ls-tree -r --name-only "<branch>" -- "specs/" | head -n 200
```

## Step 3 — Enumerate artifacts (ONLY under canonical roots)
Create file lists:

```bash
git ls-tree -r --name-only "<cp-branch>" -- "specs/<cp-branch>/"
git ls-tree -r --name-only "<cl-branch>" -- "specs/<cl-branch>/"
```

Define **logical path** = path relative to the team root:
- CP logical path = strip `specs/<cp-branch>/`
- CL logical path = strip `specs/<cl-branch>/`

Two files are counterparts if they share the same logical path.

Classify file type using heuristics:
- **Spec**: requirements, scope, user stories, acceptance criteria
- **Clarify**: questions, assumptions, clarify outputs
- **Plan**: approach, milestones, rollout/rollback, architecture notes
- **ADR**: architecture decisions
- **Diagram**: `.puml`, `.plantuml`, `.drawio`, `.png`, `.svg`
- **Other**: anything else under the roots

If unclear, inspect headers:
```bash
git show "<branch>:specs/<branch>/<logical_path>" | head -n 60
```

## Step 4 — Compute diffs (minimize noise)
For each logical path in the union, set status:
- `CP_ONLY` (missing in CL)
- `CL_ONLY` (missing in CP)
- `MATCH` (identical)
- `DIVERGENT` (different)

Diff approach (evidence-driven; keep excerpts minimal):

Preferred (if supported):
```bash
git diff "<cp-branch>:specs/<cp-branch>/<logical_path>" "<cl-branch>:specs/<cl-branch>/<logical_path>"
```

Fallback:
```bash
git show "<cp-branch>:specs/<cp-branch>/<logical_path>" > /tmp/cp_spec
git show "<cl-branch>:specs/<cl-branch>/<logical_path>" > /tmp/cl_spec
diff -u /tmp/cp_spec /tmp/cl_spec
```

Noise-control rules for your write-up:
- Do not surface cosmetic differences unless they cause ambiguity or inconsistency.
- Only surface diffs that drive a decision (scope, requirements, acceptance criteria, assumptions, architecture, NFRs, security, observability, rollout).
- Every surfaced difference must map to an **Issue/Decision** item.

## Step 5 — Issue/Decision Log (complete and actionable)
Create an **Issue/Decision Log** where each item includes:
- `ID` (e.g., `DEC-01`, `GAP-02`)
- `Category` (Scope / Functional / NFR / Security / Data / API / Testing / Observability / Rollout / ADR / Documentation)
- `Severity` (Blocker / High / Medium / Low)
- `Location` (logical path + section heading)
- `Evidence` (minimal excerpt and/or diff hunk summary)
- `Decision / Question`
- `Options` (explicit user actions; at least 2 when applicable)
- `Recommendation`
- `Rationale` (including risks of alternatives)
- `Resulting change` (what file edit would occur if accepted)

Options must be phrased as user actions, for example:
- “Adopt CP wording”
- “Adopt CL wording”
- “Merge both (preferred)”
- “Add missing acceptance criteria”
- “Defer; mark as open question (with default)”
- “Remove requirement (out of scope)”

Include a separate **Open Questions (Complete List)** subsection if some items require user input, but still provide a recommended default for each.

## Step 6 — Unified spec recommendation (amalgamation strategy)
Define one **canonical logical file set** that merges the best of both.

For each logical file, decide:
- `Source`: CP / CL / MERGED
- `Rationale`
- `Edits summary`

Target location rule (default):
- Apply unified changes into `specs/<cp-branch>/` (CP_ROOT)
Then mirror the same logical changes into `specs/<cl-branch>/` after approval.

## Step 7 — Proposed Patch (NOT applied)
Do **not** edit files, commit, or cherry-pick yet.

Provide the proposal in one of two formats:
- **Option A (preferred):** unified diff blocks per logical file (git-style), showing intended changes under the target root.
- **Option B:** complete file replacement blocks with clear delimiters.

Patch content requirements:
- Must implement your recommendations from the Issue/Decision Log.
- Must add missing acceptance criteria, NFRs, rollout/rollback, security, observability, and testability guidance where identified.
- Must normalize structure and terminology where it reduces ambiguity.

## Step 8 — Await approval
End with:
- What will happen after the user says **GO**
- A single explicit question:

**Approve applying the Proposed Patch to the working branch (YES/GO), or request changes?**

---

# Required output format (must follow exactly)

1. **Inputs (Inferred)**
   - cp-branch: `<...>`
   - cl-branch: `<...>`
   - working branch (HEAD): `<...>`
   - CP_ROOT: `specs/<cp-branch>/`
   - CL_ROOT: `specs/<cl-branch>/`
   - SpecKit scaffold: `.specify/` (present/missing)

2. **Worktree Resolution & Troubleshooting**
   - Worktree paths found (or “not found”)
   - If not found: object-access strategy and suggested commands to add/verify worktree (do not execute automatically)

3. **File Inventory (logical paths)**
   - Table: `Logical Path | CP Present | CL Present | Status (MATCH/DIVERGENT/CP_ONLY/CL_ONLY) | Type | Notes`

4. **Issue/Decision Log (Complete List)**
   - Table or numbered list with:
     `ID | Category | Severity | Location | Evidence | Decision | Options | Recommendation | Rationale | Resulting change`

5. **Unified Spec Recommendation**
   - Canonical logical file set + rationale
   - Per-file merge decisions
   - Target location rule used

6. **Proposed Patch (Not Applied)**
   - Unified diffs or replacement blocks

7. **Apply & Replication Instructions (after GO)**
Provide exact, safe, minimal commands the user can run (do not run them yourself), including:
- applying the patch to CP_ROOT
- committing the changes
- replicating to CL_ROOT (same edits mirrored), including any notes about conflict resolution

8. **Approval Request**
   - Approve applying the Proposed Patch to the working branch (YES/GO), or request changes?

---

## Start now
Proceed immediately with **Step 0 → Step 7**, using git object access or worktree paths as available. Be strict about scope: only files under the canonical roots. Avoid generic summaries; everything should map to an actionable Issue/Decision item.
