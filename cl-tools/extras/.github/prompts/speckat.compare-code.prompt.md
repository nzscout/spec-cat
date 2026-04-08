---
description: Compare two independent implementations of the same feature on different branches or worktrees against the same Speckit feature set and recommend the best foundation.
argument-hint: <team-cl-path> <team-cp-path> [product-doc-path]...
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

1. One Team-CL repository or worktree root
2. One Team-CP repository or worktree root
3. Zero or more higher-level product documents, strongly recommended when they exist

Interpret the inputs in this order:

1. `shared-feature-dir`
2. `team-cl-path`
3. `team-cp-path`
4. any remaining arguments are `product-doc-path` values

Refer to the inputs as:

- Team-CL: `[team-cl-path]`
- Team-CP: `[team-cp-path]`
- Product-Docs: `[product-doc-path]...`

If fewer than 3 arguments are provided, stop and ask the user for the missing path or paths.

If the user provides additional product documents after the first 3 arguments, include all of them in the review.

Stop and ask the user if any of the following is missing or ambiguous:

- Team-CL implementation root
- Team-CP implementation root
- a path that points to a single file when a feature directory or implementation root is required
- the relevant feature directory under `specs/` cannot be identified in one or both team paths
- a path that appears to be a shared parent containing multiple candidate features and the intended feature is not obvious

## Path Normalization

Assume Team-CL and Team-CP are the same repository on different branches or worktrees unless the user explicitly says otherwise.

Assume the currently checked out branch in each worktree is the feature branch being reviewed for that implementation.

Identify the relevant feature directory under `specs/` from each team path before review.

Normalize each team's Speckit feature path before review:

1. If the user provides an absolute path to a feature directory, derive:
	- `repo-dir`: the parent repository root before the `specs/` segment
	- `feature-dir`: the repo-relative path beginning with `specs/`
2. If the user provides a repository or worktree root, locate the relevant feature directory under `specs/` conservatively.
3. If the user provides a repo-relative feature path, treat that as `feature-dir` and infer `repo-dir` from the current workspace or from the shared repository context when obvious.
4. Use the normalized `feature-dir` for reporting.

Team implementation paths may be provided as any of the following:

- repository roots
- worktree roots
- repo-relative subdirectories
- absolute subdirectories

Normalize each team path for reporting. Always refer to them as `Team-CL` and `Team-CP`.

When a team path is a worktree root, treat the checked out branch at that path as the authoritative implementation branch for that team.

If a team path is a repository root, inspect only the implementation that is relevant to the feature. Do not treat the entire repository as equally in scope.

Assume the Speckit feature directories in the two branches or worktrees are identical except for `tasks.md`, unless evidence shows otherwise. Review both feature directories anyway and explicitly call out any unexpected drift outside `tasks.md`.

## Scope

Compare and review two independently produced implementations of the same feature in different branches or worktrees of the same repository, built from the same Speckit feature set.

The comparison must:

- Verify each implementation is aligned with the Speckit artifacts and any higher-level product documents.
- Identify implementation gaps, incorrect behavior, missing acceptance-criteria coverage, and spec drift.
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
2. The Speckit feature directory for feature-level requirements, flows, contracts, acceptance criteria, tasks, and operational expectations
3. The implementations themselves for evidence of behavior and quality

If the product documents and the Speckit artifacts conflict, call it out explicitly. Do not silently choose one.

If the two branches or worktrees differ in Speckit artifacts other than `tasks.md`, call that out explicitly as unexpected drift and assess whether it affects the implementation comparison.

## What To Review

Review the Speckit artifacts inside the normalized feature directory for both Team-CL and Team-CP, including `spec.md`, `plan.md`, `tasks.md`, checklists, research, quickstart, data model, and contracts when present.

Treat `spec.md`, `plan.md`, research, quickstart, data model, contracts, and checklists as expected to be functionally identical between Team-CL and Team-CP. Treat `tasks.md` as the only normally variable Speckit artifact.

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

1. Fidelity to product documents and the shared Speckit artifacts
2. Functional completeness and correctness
3. Coverage of acceptance criteria, edge cases, failure handling, and tests
4. Simplicity and maintainability of the implementation approach
5. Operational robustness, deployability, rollback safety, and observability
6. Code quality, cohesion, and avoidance of unnecessary complexity
7. Consistency between each implementation and the intended feature scope in the matching branch or worktree

## Output Requirements

Produce a clean, structured, actionable report. Prefer tables where they improve clarity.

The report must include:

1. An executive recommendation stating whether Team-CL or Team-CP should be the baseline to merge, or whether a hybrid is preferred with a clearly named base plus cherry-picks
2. A comparison table covering PRD Alignment, Speckit Alignment, correctness, completeness, code quality, tests, simplicity, robustness, operational readiness, merge risk, and overall quality
3. A pros and cons section for Team-CL
4. A pros and cons section for Team-CP
5. An alignment findings table covering key requirement or contract checks, with a stable reference ID, expected behavior, branch observations, and impact
6. A findings table listing implementation gaps, technical debt, anti-patterns, over-engineering, missing tests, and spec misalignment, with a stable reference ID, severity, impact, and evidence
7. A cherry-pick table describing exactly what should be taken from the non-preferred implementation and why, with a stable reference ID
8. A remediation plan with concrete steps to fix the chosen baseline before or immediately after merge
9. A short final verdict explaining why the recommendation is the best tradeoff

## Reporting Guidance

- Be explicit about where code diverges from the Speckit artifacts or the product documents.
- Distinguish missing implementation from incorrect implementation.
- Separate code-quality concerns from product-behavior gaps.
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