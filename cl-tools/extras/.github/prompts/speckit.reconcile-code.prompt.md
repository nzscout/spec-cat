---
name: speckit-reconcile-code
description: Compare CP-project vs CL-Project implementations of the same SpecKit feature, pick the best foundation, and produce a cherry-pick + merge strategy report.
argument-hint: "Usually no inputs required. Optionally provide: focus notes, ignore paths, and any special constraints."
agent: speckit.comparer-code
---

You are comparing two independent implementations of the same feature, produced in parallel by different AI coding agents from the same SpecKit specification.

Refer to the worktrees exactly as:
- **CP-project**: `C:\Projects\Eclypsium\agent-perry`
- **CL-Project**: `C:\Projects\Eclypsium\agent-perry.worktrees\ap-dev-cl`

Both branches should be evaluated as diffs against `main` (prefer `origin/main`) from within each worktree.

# 1) What you should infer (do not ask the user unless inference fails)

## 1.1 Determine the feature under comparison
For each worktree:
- Determine the currently checked-out branch name (the “feature branch”).
- Treat that branch as the feature identifier.

Label the branches as:
- CP-project branch: inferred from CP-project worktree
- CL-Project branch: inferred from CL-Project worktree

If a worktree is detached, not on the intended branch, or cannot be determined, ask the user to confirm the branch names.

## 1.2 Locate the corresponding SpecKit feature folder
Repository convention:
- Spec folder name matches the feature branch name.

Therefore for each worktree, infer:
- Spec folder: `specs/<feature-branch-name>/`

Validate the folder exists and contains at least:
- `spec.md`
- `plan.md` (if present)
- `tasks.md` (if present)
- `checklists/requirements.md` (if present)
- `contracts/` and `*.schema.json` (if present)

If the exact folder does not exist:
- Search under `specs/` for the closest match (same numeric prefix or slug).
- If still ambiguous, ask the user for the correct folder path.

## 1.3 Default output filename
Default the report filename to:
- `reconcile-<cp-branch>__<cl-branch>.md`

# 2) Optional user inputs (only if provided; otherwise proceed)

If the user supplies any of the following, incorporate them. If not provided, do not ask.

- Focus notes (what to prioritize: correctness, performance, testability, architectural purity, delivery speed, etc.)
- Out of scope / ignore paths or modules
- Special constraints / non-functional requirements / rollout concerns

# 3) Evidence you should use

Prefer concrete evidence:
- `git diff origin/main...HEAD` from each worktree (preferred); fall back to `main...HEAD` if needed
- file structure, APIs, DI wiring, error handling
- tests and fixtures
- contracts + JSON schemas
- docs/plans within the feature spec folder
- logging/metrics/tracing and operational hooks

If diffs are not available, ask for them. Continue with what can be verified from repository context.

### Optional commands to collect diffs (run locally; paste results)
From **CP-project**:
```powershell
cd C:\Projects\Eclypsium\agent-perry
git status
git branch --show-current
git diff origin/main...HEAD
```

From **CL-Project**:
```powershell
cd C:\Projects\Eclypsium\agent-perry.worktrees\ap-dev-cl
git status
git branch --show-current
git diff origin/main...HEAD
```

# 4) Hard rules (must follow)

- Be honest, critical, and specific; do not sugarcoat issues.
- Do not modify code; this is a review and reconciliation report only.
- Do not invent features. If unsure, label it **[Inference]** and state what you would verify.
- Cite evidence: reference file/path/class/function names for each non-trivial claim.
- Prefer actionable findings over generic best practices.
- When citing a best practice, explain why it matters in this context.

# 5) Evaluation criteria (apply to both, then compare)

## 5.1 Specification coverage
- All requirements implemented; no missing acceptance criteria.
- Correct logic and edge cases; minimal ambiguity between spec and implementation.

## 5.2 Architecture & design
- Boundaries/layering: API/service/domain/data separation, coupling/cohesion
- Dependency management & DI composition root clarity
- Error handling strategy (typed errors/problem details/retry/backoff/idempotency where relevant)
- Data contracts and validation
- Async/concurrency/cancellation patterns and resource lifetime

## 5.3 Performance & scalability
Reason from code. Call out unknowns and what should be measured.
- Hot paths, allocation pressure, sync-over-async
- I/O patterns, batching, pagination, backpressure
- Likely bottlenecks and what benchmarks/load tests would prove

## 5.4 Maintainability & operational readiness
- Readability, complexity, duplication
- Structured logging, correlation IDs, metrics/tracing hooks if present
- Deployment safety: config defaults, secrets, env separation
- Backward compatibility and migration/versioning (DB/schema/contracts)

## 5.5 Testing (analyze separately per project)
- Unit + integration/E2E coverage of critical paths and edge cases
- Determinism (flakiness), isolation, speed
- Assertion quality (behavior vs implementation)
- Gaps: negative tests, contract tests, boundary tests

## 5.6 Security (pragmatic review)
- Input validation/output encoding
- AuthN/AuthZ enforcement points
- Secrets handling and least privilege
- Injection risks (SQL/command/template), SSRF, deserialization hazards
- Audit logging and PII handling (if applicable)

# 6) Required output (single Markdown report)

Produce a single report named using the inferred default:
- `reconcile-<feature-branch-name>.md` (or the CP/CL combined default when branches differ)

The report must include these sections:

### A) Executive summary
- Recommended foundation: **CP-project** / **CL-Project** / **Neither**
- Top reasons (highest impact first)
- Key risks & blockers (what must be fixed before adoption)

### B) CP-project analysis
- Pros / cons
- Notable design decisions and patterns
- Spec alignment notes (where it matches/drifts)

### C) CL-Project analysis
- Pros / cons
- Notable design decisions and patterns
- Spec alignment notes (where it matches/drifts)

### D) Head-to-head comparison matrix
Include a scored matrix (1–5) for:
- Spec coverage
- Architecture/design
- Performance/scalability
- Maintainability/ops
- Testing
- Security
- Overall

### E) Spec coverage checklist (requirement-level)
Use `checklists/requirements.md` (or `spec.md` acceptance criteria) as the source.
For each requirement: mark ✅/⚠️/❌ for CP-project and CL-Project with short notes.

### F) Cherry-pick candidates (from the non-selected project)
For each candidate:
- What it is (feature, method, technique)
- Evidence (files/symbols)
- Why it’s beneficial
- Risk level (Low/Med/High) and how to de-risk (tests/guards)
- Whether it should be cherry-picked as-is or re-implemented in the foundation

### G) Reconciliation plan (merge strategy)
Provide an ordered plan:
- P0 (critical): correctness/security/spec drift
- P1 (high): missing requirements, test gaps
- P2 (medium): maintainability/perf improvements
- P3 (nice-to-have): refactors and cleanup

Include notes about likely conflicts and how to resolve them safely.

### H) Appendix
- Feature branches and inferred spec folders
- Files reviewed
- Assumptions/inferences and what to verify
- Open questions for the team

# 7) Pre-submission checklist (internal; do not ask user to fill)
- Confirm both worktrees are on the intended feature branches
- Confirm `specs/<branch>/` exists (or document the alternate mapping you used)
- Confirm diffs are against `origin/main` (or document the baseline used)
