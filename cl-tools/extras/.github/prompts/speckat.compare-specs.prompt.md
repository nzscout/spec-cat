---
description: Compare two independently generated Speckit document sets for the same feature, validate both against a PRD, and recommend the best foundation.
argument-hint: <team-cl-path> <team-cp-path> <prd-path>
agent: speckat.comparer-spec
---

## User Input

```text
$ARGUMENTS
```

You MUST consider the user input before proceeding.

## Required Arguments

Interpret the arguments in this exact order:

1. `team-cl-path`
2. `team-cp-path`
3. `prd-path`

Refer to the inputs as:

- Team-CL: `[team-cl-path]`
- Team-CP: `[team-cp-path]`
- PRD: `[prd-path]`

If fewer than 3 arguments are provided, stop and ask the user for the missing path or paths.

The first two arguments must identify the exact Speckit feature directories for the same feature. They may be provided as either:

- an absolute path to the feature directory, for example `C:\Projects\Eclypsium\VLS.V1\vls.cp\specs\DATA-5331-implement-health-ready-endpoints`
- a repo-relative feature directory path, for example `specs/DATA-5331-implement-health-ready-endpoints`

Normalize each team path before review:

1. If the user provides an absolute path to a feature directory, derive:
	- `repo-dir`: the parent repository root before the `specs/` segment
	- `feature-dir`: the repo-relative path beginning with `specs/`
2. If the user provides a repo-relative feature path, treat that as `feature-dir` and infer `repo-dir` from the current workspace or from the shared repository context when obvious.
3. Use the normalized `feature-dir` for comparison and reporting.

Example normalization:

- input: `C:\Projects\Eclypsium\VLS.V1\vls.cp\specs\DATA-5331-implement-health-ready-endpoints`
- `repo-dir`: `C:\Projects\Eclypsium\VLS.V1\vls.cp`
- `feature-dir`: `specs/DATA-5331-implement-health-ready-endpoints`

If either team path is a repo root, a shared `specs/` folder, or any path that appears to contain multiple feature directories, do not guess which feature to inspect. Stop and ask the user for the specific feature directory path.

## Scope

Compare and review two independently generated sets of Speckit framework documents that were created to implement the same feature.

The comparison must:

- Verify both document sets are aligned with the PRD.
- Identify gaps, spec drift, contradictions, missing requirements, weak acceptance criteria, and incomplete coverage.
- Identify anti-patterns, unnecessary complexity, over-engineering, and fragile approaches.
- Prefer simpler designs over more complex ones when both satisfy the PRD.
- Prefer robustness, operability, and clarity over brittle or tightly coupled solutions.
- Call out any strong ideas, requirements, flows, constraints, or artifacts that should be cherry-picked from the non-preferred set.

## What To Review

Review the Speckit artifacts inside each normalized feature directory, including `spec.md`, `plan.md`, `tasks.md`, checklists, research, quickstart, data model, and contracts when present.

If a team argument points to a single file instead of a feature directory, stop and ask the user for the feature directory path.

Use the PRD as the source of truth for product intent.

## Review Priorities

Evaluate both sets against these priorities:

1. Fidelity to the PRD
2. Internal consistency across Speckit artifacts
3. Completeness of requirements, scenarios, edge cases, and testability
4. Simplicity and maintainability of the proposed approach
5. Operational robustness and resistance to fragile assumptions
6. Clear separation between requirements, design, and implementation work

## Output Requirements

Produce a clean, structured, actionable report. Prefer tables where they improve clarity.

The report must include:

1. An executive recommendation stating which set should be the baseline: Team-CL, Team-CP, or a hybrid with a clearly named base plus cherry-picks.
2. A comparison table covering PRD alignment, completeness, simplicity, robustness, risks, and overall quality.
3. A pros and cons section for Team-CL.
4. A pros and cons section for Team-CP.
5. A list of gaps, spec drift, anti-patterns, and over-engineering issues with severity and impact.
6. A cherry-pick table describing exactly what should be taken from the non-preferred set and why.
7. A remediation plan with concrete steps to fix the chosen baseline.
8. A short final verdict explaining why the recommendation is the best tradeoff.

## Reporting Guidance

- Be explicit about where the PRD and the spec sets disagree.
- Distinguish missing information from incorrect information.
- Call out when one set introduces implementation detail or complexity that is not justified by the PRD.
- Prefer decisive recommendations over vague summaries.
- Keep the report informative and practical for engineers deciding which branch artifacts to keep.

## Suggested Report Shape

Use this structure unless a better equivalent improves clarity:

### Executive Summary

### Comparison Matrix

### PRD Alignment Findings

### Team-CL Review

### Team-CP Review

### Cherry-Pick Recommendations

### Remediation Plan

### Final Verdict
