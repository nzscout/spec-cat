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

Hard precondition:

1. `spec.md`, `plan.md`, research, quickstart, data model, contracts, and checklists must be identical between Team-CL and Team-CP.
2. `tasks.md` is the only Speckit artifact allowed to differ because it belongs to the implementation branch it lives in.
3. If any Speckit artifact other than `tasks.md` differs between the two feature directories, stop immediately and alert the user. Do not continue with the implementation comparison until the feature artifacts are reconciled.

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

If the two branches or worktrees differ in Speckit artifacts other than `tasks.md`, stop immediately and alert the user. Do not continue the implementation comparison.

If behavior already exists on the canonical base branch, treat it as baseline context rather than feature-specific evidence unless an implementation intentionally changes it.

## What To Review

Review the Speckit artifacts inside the normalized feature directory for both Team-CL and Team-CP, including `spec.md`, `plan.md`, `tasks.md`, checklists, research, quickstart, data model, and contracts when present.

Apply this review gate before comparing implementation code:

1. Compare all Speckit artifacts in both feature directories.
2. If any file other than `tasks.md` differs, stop and alert the user with the exact file or files that differ.
3. Only continue once the non-`tasks.md` artifacts are confirmed identical.

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

## Review Priorities

Evaluate Team-CL and Team-CP against these priorities:

1. Non-`tasks.md` feature artifacts are identical across Team-CL and Team-CP; if not, stop
2. Fidelity to the canonical base branch as the agreed root for measuring net-new feature work
3. Each branch's `tasks.md` is up to date with its own implementation branch
4. Functional completeness and correctness
5. Coverage of acceptance criteria, edge cases, failure handling, and tests
6. Simplicity and maintainability of the implementation approach
7. Operational robustness, deployability, rollback safety, and observability
8. Code quality, cohesion, and avoidance of unnecessary complexity
9. Consistency between each implementation and the intended feature scope in the matching branch or worktree

## Output Requirements

Produce a clean, structured, actionable report. Prefer tables where they improve clarity.

The report must include:

1. An executive recommendation stating whether Team-CL or Team-CP should be the baseline to merge, or whether a hybrid is preferred with a clearly named base plus cherry-picks
2. A scope-and-inputs summary that explicitly records the Team-CL feature path, Team-CP feature path, and canonical base branch used for the review
3. A comparison table covering PRD Alignment, Speckit Alignment, correctness, completeness, code quality, tests, simplicity, robustness, operational readiness, merge risk, and overall quality
4. A pros and cons section for Team-CL
5. A pros and cons section for Team-CP
6. An alignment findings table covering key requirement or contract checks, with a stable reference ID, expected behavior, branch observations, and impact
7. A findings table listing implementation gaps, technical debt, anti-patterns, over-engineering, missing tests, and spec misalignment, with a stable reference ID, severity, impact, and evidence
8. A cherry-pick table describing exactly what should be taken from the non-preferred implementation and why, with a stable reference ID
9. A remediation plan with concrete steps to fix the chosen baseline before or immediately after merge
10. A short final verdict explaining why the recommendation is the best tradeoff

## Reporting Guidance

- Be explicit about where code diverges from the Speckit artifacts or the product documents.
- Stop instead of continuing if any Speckit artifact other than `tasks.md` differs between Team-CL and Team-CP.
- Be explicit about which observations come from the canonical base diff versus the direct Team-CL and Team-CP comparison.
- Distinguish missing implementation from incorrect implementation.
- Separate code-quality concerns from product-behavior gaps.
- Verify each branch's `tasks.md` against the implementation in that same branch, not against the other branch.
- Stop and alert the user if either `tasks.md` is stale or materially inconsistent with its implementation branch.
- Treat code already present on the canonical base branch as baseline context, not feature-specific work.
- Call out unrelated drift on either implementation branch when its diff against the canonical base branch includes changes outside the feature scope.
- Call out unjustified abstractions, premature generalization, or infrastructure complexity that the spec does not require.
- Highlight where one team has stronger tests, safer rollout behavior, clearer contracts, or better failure handling even if that team is not the selected baseline.
- Use `PRD Alignment` to describe alignment with the higher-level product documents.
- Use `Speckit Alignment` to describe alignment with the feature-level Speckit artifacts.
- Use `Merge risk` instead of `Overall risk` for the final risk row in the comparison table.
- Number alignment findings using stable identifiers like `AF-1`, `AF-2`, `AF-3`.
- Number findings using stable identifiers like `F-1`, `F-2`, `F-3`.
- Number cherry-pick recommendations using stable identifiers like `C-1`, `C-2`, `C-3`.
- Use the labels `Team-CL` and `Team-CP` consistently.
- Prefer decisive recommendations over vague summaries.
- Keep the report practical for engineers deciding which branch or worktree to keep and what to cherry-pick.

## Suggested Report Shape

Use this structure unless a better equivalent improves clarity:

### Executive Summary

### Scope And Inputs

### Comparison Matrix

### Alignment Findings

### Team-CL Review

### Team-CP Review

### Cherry-Pick Recommendations

### Remediation Plan

### Final Verdict