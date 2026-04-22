---
description: Compare two independent implementations of the same feature using the feature directories from two different branches or worktrees against a shared canonical base branch, then recommend the best foundation.
argument-hint: <team-cl-feature-dir> <team-cp-feature-dir> [canonical-base-branch] [product-doc-path]...
agent: speckat.comparer-code
---

## User Input

```text
$ARGUMENTS
```

You MUST consider the user input before proceeding.

## Required Inputs

This prompt compares implementations, not competing spec sets.

You need all of the following before review:

1. One Team-CL Speckit feature directory path
2. One Team-CP Speckit feature directory path
3. An optional canonical base branch that both implementations should be diffed against
4. Zero or more higher-level product documents, strongly recommended when they exist

Interpret the inputs in this order:

1. `team-cl-feature-dir`
2. `team-cp-feature-dir`
3. optional `canonical-base-branch`
4. any remaining arguments are `product-doc-path` values

Refer to the inputs as:

- Team-CL Feature: `[team-cl-feature-dir]`
- Team-CP Feature: `[team-cp-feature-dir]`
- Canonical Base: `[canonical-base-branch]`
- Product-Docs: `[product-doc-path]...`

If fewer than 2 arguments are provided, stop and ask the user for the missing path or paths.

If the user provides a 3rd argument that is clearly a file or directory path, treat it as the first `product-doc-path` and use the default canonical base resolution instead.

If the user provides additional product documents after the two required feature-directory arguments and optional canonical base branch, include all of them in the review.

Default canonical base resolution:

1. If the user explicitly provides `canonical-base-branch`, use it.
2. Otherwise prefer `main`.
3. If `main` does not exist, use `master`.
4. If neither `main` nor `master` exists, stop and ask the user for the correct canonical base branch.

Stop and ask the user if any of the following is missing or ambiguous:

- Team-CL feature directory path
- Team-CP feature directory path
- the canonical base branch was provided but cannot be resolved in one or both team repositories or worktrees
- a path that points to a single file when a feature directory is required
- a provided path is a repository root, a shared `specs/` folder, or any path that appears to contain multiple feature directories
- a path that appears to be a shared parent containing multiple candidate features and the intended feature is not obvious

## Path Normalization

Assume Team-CL and Team-CP are the same repository on different branches or worktrees unless the user explicitly says otherwise.

Assume the provided Team-CL and Team-CP feature directory paths live in different git worktrees or branches for the same underlying repository unless evidence shows otherwise.

Treat the canonical base branch as the shared root for both implementations. The comparison must evaluate each implementation relative to that root first, then compare the two implementations against each other.

Treat the provided feature-directory paths as authoritative. Do not try to auto-discover a different feature directory unless a provided path is invalid or ambiguous.

Normalize each team's Speckit feature path before review:

1. If the user provides an absolute path to a feature directory, derive:
	- `repo-dir`: the parent repository root before the `specs/` segment
	- `feature-dir`: the repo-relative path beginning with `specs/`
2. If the user provides a repo-relative feature path, treat that as `feature-dir` and infer `repo-dir` only when the relevant worktree root is obvious from context.
3. If the repo root for a repo-relative feature path is not obvious, stop and ask the user for an absolute feature directory path.
4. Use the normalized `feature-dir` for reporting.

Team feature-directory paths may be provided as any of the following:

- absolute feature directories
- repo-relative feature directories when the corresponding worktree root is obvious

Normalize each team path for reporting. Always refer to them as `Team-CL` and `Team-CP`.

When a team feature path is absolute, treat the containing worktree or repository as the authoritative implementation root for that team.

When a team feature path is repo-relative, resolve it against the intended worktree before review. If multiple worktrees could match, stop and ask the user to disambiguate.

Normalize the canonical base branch before review:

1. Resolve it in both Team-CL and Team-CP repositories or worktrees.
2. If the same branch name resolves to different commits because one worktree is stale, call that out explicitly as review risk.
3. Use the canonical base branch as the root for all implementation diffs.
4. Prefer merge-base semantics when reasoning about branch deltas so unrelated history on either implementation branch is not misattributed to the feature.

Assume the Speckit feature directories in the two branches or worktrees describe the same feature.

Spec artifact precondition:

1. `tasks.md` is always expected to differ between Team-CL and Team-CP because it belongs to the implementation branch it lives in.
2. All other Speckit artifacts (`spec.md`, `plan.md`, research, quickstart, data model, contracts, checklists) should be identical between Team-CL and Team-CP.
3. Trivial differences are tolerated and ignored. A difference is trivial when it is limited to branch names, folder names, worktree paths, timestamps, or other environment-specific values that carry no behavioral or requirements meaning.
4. Substantial differences are those that change requirements, acceptance criteria, data models, contracts, flows, constraints, or any other content with behavioral implications.
5. If only trivial differences exist, proceed with the comparison as normal.
6. If any substantial difference exists in a non-`tasks.md` artifact, do **not** stop. Continue the full comparison but populate the `spec_drift` section in the YAML output with every difference found (trivial and substantial) and flag the substantial ones clearly.

## Scope

Compare and review two independently produced implementations of the same feature in different branches or worktrees of the same repository, built from the same Speckit feature set and diverging from the same canonical base branch.

The comparison must:

- Verify each implementation is aligned with the Speckit artifacts and any higher-level product documents.
- Verify each implementation's net-new changes relative to the canonical base branch are in scope for the feature.
- Verify that Team-CL `tasks.md` accurately reflects the current state of the Team-CL implementation branch.
- Verify that Team-CP `tasks.md` accurately reflects the current state of the Team-CP implementation branch.
- Identify implementation gaps, incorrect behavior, missing acceptance-criteria coverage, and spec drift.
- Identify unrelated drift or contamination on either implementation branch that does not belong to the feature when diffed against the canonical base branch.
- Identify technical debt, anti-patterns, over-engineering, unnecessary abstractions, tight coupling, brittle assumptions, and operational risk.
- Evaluate code quality, test quality, deployability, rollback safety, observability, and branch-to-branch consistency relative to the same feature scope.
- Prefer simpler implementations when they satisfy the requirements.
- Prefer robustness, maintainability, and clear operational behavior over clever or tightly coupled solutions.
- Call out strong ideas, code paths, tests, scripts, contracts, or rollout choices that should be cherry-picked from non-preferred implementations.

The recommendation should identify which branch or implementation should be merged as the foundation.

Do not change code. Provide a read-only review and recommendation report.

## Source Of Truth

Use sources in this order:

1. Higher-level product documents for product intent and non-feature-specific constraints
2. The two Speckit feature directories for feature-level requirements, flows, contracts, acceptance criteria, tasks, and operational expectations
3. The canonical base branch for pre-existing behavior and baseline context
4. The implementations themselves for evidence of behavior and quality

If the product documents and the Speckit artifacts conflict, call it out explicitly. Do not silently choose one.

If the two branches or worktrees differ substantially in Speckit artifacts other than `tasks.md`, continue the comparison but populate the `spec_drift` section with all differences found and flag the substantial ones.

If behavior already exists on the canonical base branch, treat it as baseline context rather than feature-specific evidence unless an implementation intentionally changes it.

## What To Review

Review the Speckit artifacts inside the normalized feature directory for both Team-CL and Team-CP, including `spec.md`, `plan.md`, `tasks.md`, checklists, research, quickstart, data model, and contracts when present.

Apply this review gate before comparing implementation code:

1. Compare all Speckit artifacts in both feature directories.
2. If any file other than `tasks.md` differs, classify each difference as trivial or substantial.
3. If only trivial differences exist, proceed normally — do not populate `spec_drift`.
4. If any substantial difference exists, proceed with the comparison but populate the `spec_drift` section in the YAML output with **all** differences found (both trivial and substantial), marking each as `trivial` or `substantial`.

Treat `tasks.md` as the only normally variable Speckit artifact because it belongs to the implementation layer and may legitimately differ between worktrees.

For each branch-specific `tasks.md`, verify that it is up to date with the implementation branch it belongs to:

1. Completed work in the branch should be reflected in `tasks.md`.
2. Incomplete or missing work claimed by `tasks.md` should be called out.
3. If `tasks.md` is stale, misleading, or materially inconsistent with the implementation branch, stop and alert the user before continuing with the comparison.

Review each implementation branch relative to the canonical base branch before doing direct Team-CL versus Team-CP comparison.

At minimum, determine:

1. What each implementation changes relative to the canonical base branch
2. Whether those changes are required by the feature scope described by the reconciled non-`tasks.md` feature artifacts
3. Whether each branch's `tasks.md` accurately reflects those implementation changes
4. Whether either implementation carries unrelated drift beyond the feature

Review each implementation across the supplied path and any clearly in-scope related feature paths, including relevant:

- application code
- tests
- configuration
- infrastructure or deployment manifests
- scripts and migration logic
- docs directly tied to implementation or rollout
- CI/CD changes relevant to the feature

When the implementation spans multiple repos, also review:

- interface boundaries between repos
- versioning or dependency assumptions
- deployment ordering and failure modes
- backward compatibility and rollback implications
- consistency of naming, contracts, and operational flow

### Paths to Exclude from Diff Review

When diffing against the canonical base branch, unconditionally exclude `.github/` and `.specify/` and all their children from the implementation comparison. These are Speckit and IDE infrastructure files installed by project setup tooling and are expected to be identical on both branches. Do not report them as unrelated drift, scope violations, or findings of any kind.

The Speckit feature directories themselves (e.g. within `specs/`) are still reviewed for artifact consistency as described above.

## Review Priorities

Evaluate Team-CL and Team-CP against these priorities:

1. Non-`tasks.md` feature artifacts are consistent across Team-CL and Team-CP; substantial drift triggers the `spec_drift` section
2. Fidelity to the canonical base branch as the agreed root for measuring net-new feature work
3. Each branch's `tasks.md` is up to date with its own implementation branch
4. Functional completeness and correctness
5. Coverage of acceptance criteria, edge cases, failure handling, and tests
6. Simplicity and maintainability of the implementation approach
7. Operational robustness, deployability, rollback safety, and observability
8. Code quality, cohesion, and avoidance of unnecessary complexity
9. Consistency between each implementation and the intended feature scope in the matching branch or worktree

## Structured Output

Emit your complete report as a single fenced YAML block. Do not write any prose, markdown headers, or commentary outside the fence. The YAML block is the complete and only output.

The consolidation agent and the human markdown renderer both consume this YAML directly. A separate rendering prompt (`speckat.compare-code.render`) converts it to a formatted markdown report for human review.

### Output File Location and Naming

Save the YAML output to a file under `specs/reviews/` in the repository root. Create the directory if it does not exist.

Derive the file name as follows:

1. Take the current git branch name (the branch the user is on when invoking this prompt).
2. Strip any parent prefix up to and including the last `/`. For example `feature/DATA-5330-Migrate-v1-to-v2-go` becomes `DATA-5330-Migrate-v1-to-v2-go`.
3. Append a hyphen and the LLM model identifier with dots replaced by underscores. For example `opus-4.6` becomes `opus-4_6`.
4. Add the `.yaml` extension.

Final path pattern:

```
specs/reviews/<branch-leaf>-<model_id>.yaml
```

Examples:

| Branch                                     | Model       | Output file                                                    |
| ------------------------------------------ | ----------- | -------------------------------------------------------------- |
| `feature/DATA-5330-Migrate-v1-to-v2-go`   | opus-4.6    | `specs/reviews/DATA-5330-Migrate-v1-to-v2-go-opus-4_6.yaml`   |
| `feature/DATA-5330-Migrate-v1-to-v2-go`   | gpt-5.4     | `specs/reviews/DATA-5330-Migrate-v1-to-v2-go-gpt-5_4.yaml`    |
| `fix/DATA-1001-null-check`                | sonnet-4    | `specs/reviews/DATA-1001-null-check-sonnet-4.yaml`             |

The rendered markdown report follows the same convention but with a `.md` extension (e.g. `specs/reviews/DATA-5330-Migrate-v1-to-v2-go-opus-4_6.md`).

### YAML Schema

The YAML must contain a top-level `report` key with the following structure. All fields are required; use `""` for empty strings and `[]` for empty lists rather than null.

```yaml
report:
  meta:
    team_cl_feature_path: string         # normalized team-cl feature-dir
    team_cp_feature_path: string         # normalized team-cp feature-dir
    canonical_base_branch: string
    product_docs: [string, ...]          # empty list if none provided
    generated_at: string                 # ISO-8601 timestamp
    reviewed_by_llm: string              # model identifier

  executive_recommendation:
    preferred_team: string               # exactly: "Team-CL", "Team-CP", or "hybrid"
    hybrid_base: string | null           # "Team-CL" or "Team-CP" when hybrid; null otherwise
    summary: string                      # 2-4 sentence plain-text summary

  comparison_matrix:                     # exactly these criteria, in this order
    - criterion: string
      team_cl: { score: integer, notes: string }   # score: 1-10 (10 = best)
      team_cp: { score: integer, notes: string }   # score: 1-10 (10 = best)
    # required criteria (exact strings):
    # PRD Alignment, Speckit Alignment, Correctness, Completeness, Code Quality,
    # Tests, Simplicity, Robustness, Operational Readiness, Merge Risk, Overall Quality

  alignment_findings:                    # one entry per AF-N finding; [] if none
    - id: string                         # "AF-1", "AF-2", ...
      requirement: string
      expected: string
      team_cl_observation: string
      team_cp_observation: string
      impact: string

  team_cl:
    tasks_md_status: string              # exactly: "current" or "stale"
    tasks_md_notes: string
    pros: [string, ...]
    cons: [string, ...]

  team_cp:
    tasks_md_status: string              # exactly: "current" or "stale"
    tasks_md_notes: string
    pros: [string, ...]
    cons: [string, ...]

  findings:                              # one entry per F-N finding; [] if none
    - id: string                         # "F-1", "F-2", ...
      team: string                       # "Team-CL", "Team-CP", or "Both"
      severity: string                   # "Critical", "High", "Medium", or "Low"
      category: string                   # gap | missing-test | anti-pattern | spec-drift | debt | unrelated-drift
      description: string
      impact: string
      evidence: string                   # file path + line reference

  cherry_picks:                          # empty list if none
    - id: string                         # "C-1", "C-2", ...
      from_team: string                  # "Team-CL" or "Team-CP"
      description: string
      rationale: string
      target_files: [string, ...]

  remediation_plan:                      # ordered steps
    - step: integer
      description: string
      priority: string                   # "before-merge" or "after-merge"
      owner: string

  spec_drift:                            # [] if no substantial spec artifact differences
    - id: string                         # "SD-1", "SD-2", ...
      file: string                       # artifact filename, e.g. "spec.md"
      classification: string             # exactly: "trivial" or "substantial"
      team_cl_value: string              # what Team-CL has
      team_cp_value: string              # what Team-CP has
      description: string                # what differs and why it matters (or not)
      impact: string                     # "none" for trivial; describe impact for substantial

  final_verdict: string                  # 2-5 sentence decisive closing statement
```

### Reporting Guidance

Apply these constraints when populating the YAML fields:

- Be explicit about where code diverges from the Speckit artifacts or the product documents.
- If any Speckit artifact other than `tasks.md` has substantial differences, populate `spec_drift` with all diffs found and flag the substantial ones. Include trivial diffs in the same section for completeness when substantial diffs are present.
- Be explicit in finding descriptions about whether observations come from the canonical base diff versus the direct Team-CL and Team-CP comparison.
- Distinguish "missing implementation" from "incorrect implementation" in finding `description` fields.
- Separate code-quality concerns from product-behavior gaps using the `category` field.
- Verify each branch's `tasks.md` against the implementation in its own branch only.
- If either `tasks.md` is stale or materially inconsistent with its implementation, report it in the `team_cl` or `team_cp` section with `tasks_md_status: "stale"` and explain in `tasks_md_notes`.
- Treat code already on the canonical base branch as baseline context, not feature-specific evidence.
- Call out unrelated drift on either branch in the `findings` array using category `unrelated-drift`.
- Highlight where the non-preferred team has stronger approaches in their `pros` entries even when their team is not selected.
- Use exactly `PRD Alignment` and `Speckit Alignment` as criterion names in `comparison_matrix`.
- Use exactly `Merge Risk` as the criterion name for the risk row (not "Overall Risk" or "Merge risk").
- All `comparison_matrix` scores must be integers on a **1-10 scale** (1 = worst, 10 = best). Do not use 5-point scales, letter grades, or qualitative labels ("High", "Low").
- `preferred_team` must be exactly one of: `Team-CL`, `Team-CP`, `hybrid`. Never leave it ambiguous.
- Number alignment findings `AF-1`, `AF-2`, etc.; implementation findings `F-1`, `F-2`, etc.; cherry-picks `C-1`, `C-2`, etc.; spec drift items `SD-1`, `SD-2`, etc.

### Output Examples

See [`.specify/examples/speckat.compare-code.example-1.yaml`](../../.specify/examples/speckat.compare-code.example-1.yaml) (single winner — Team-CP preferred) and [`.specify/examples/speckat.compare-code.example-2.yaml`](../../.specify/examples/speckat.compare-code.example-2.yaml) (hybrid — Team-CL base with cherry-picks from Team-CP) for complete worked examples of the expected YAML output.

To render the YAML output into a human-readable markdown report, use the rendering prompt:

```
@speckat.compare-code.render <path-to-yaml-output>
```