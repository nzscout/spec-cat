---
description: Render a speckat.compare-code YAML report into a formatted markdown report for human review.
argument-hint: <yaml-file-path>
---

## User Input

```text
$ARGUMENTS
```

## Task

Read the YAML file at the path provided in the user input and render it into a formatted markdown report.

1. Read the YAML file at the provided path.
2. Produce a markdown report that maps exactly to the YAML schema — no sections added, no sections omitted, no section order changed.
3. Save the rendered markdown to a file next to the YAML source with the same base name but a `.md` extension. For example, if the input is `specs/reviews/DATA-5330-Migrate-v1-to-v2-go-opus-4_6.yaml`, write the output to `specs/reviews/DATA-5330-Migrate-v1-to-v2-go-opus-4_6.md`.
4. Output only the rendered markdown. Do not add commentary, preamble, or code fences around the output.

## Metadata Header

Add this block above all sections:

```
> **Rendered from:** `<yaml-file-path>`
> **Reviewed by LLM:** <report.meta.reviewed_by_llm>
> **Generated:** <report.meta.generated_at>
```

---

## Section Mapping

Render sections in this exact order using `##` headings, separated by `---` horizontal rules.

### 1. Executive Summary

Source: `report.executive_recommendation`

- If `preferred_team` is `hybrid`, open with: `**Recommended foundation: Hybrid — <hybrid_base> base with cherry-picks from the other team**`
- Otherwise open with: `**Recommended foundation: <preferred_team>**`
- Follow with the `summary` field as a paragraph.

### 2. Scope And Inputs

Source: `report.meta`

Render as a two-column table (Item | Value):

| Item | Value |
|---|---|
| Team-CL Feature Path | `<team_cl_feature_path>` |
| Team-CP Feature Path | `<team_cp_feature_path>` |
| Canonical Base Branch | `<canonical_base_branch>` |
| Product Documents | comma-separated list of `product_docs` entries; "None" if empty |

### 3. Comparison Matrix

Source: `report.comparison_matrix`

Render as a three-column table (Criterion | Team-CL | Team-CP).

Each cell: `**<score>** — <notes>`. Omit ` — <notes>` if notes is an empty string.

### 4. Alignment Findings

Source: `report.alignment_findings`

Render as a table with columns: ID | Requirement | Expected | Team-CL Observation | Team-CP Observation | Impact.

Each row is one `AF-N` entry in order.

If the list is empty, write: "No alignment findings."

### 5. Team-CL Review

Source: `report.team_cl`

Open with a blockquote:

- If `tasks_md_status` is `stale`: `` > `tasks.md` status: **STALE** — <tasks_md_notes> ``
- If `tasks_md_status` is `current`: `` > `tasks.md` status: **Current** — <tasks_md_notes> ``

Follow with a **Pros** bullet list and a **Cons** bullet list. Use inline code for file paths and identifiers.

### 6. Team-CP Review

Source: `report.team_cp`

Same structure as Team-CL Review.

### 7. Implementation Findings

Source: `report.findings`

Render as a table with columns: ID | Team | Severity | Category | Description | Impact | Evidence.

Bold the severity value: `**Critical**`, `**High**`, `**Medium**`, `**Low**`.

If the list is empty, write: "No implementation findings."

### 8. Cherry-Pick Recommendations

Source: `report.cherry_picks`

Render as a table with columns: ID | From | Description | Rationale | Target Files.

Render `target_files` as a comma-separated list of inline code items.

If the list is empty, write: "No cherry-picks recommended."

### 9. Remediation Plan

Source: `report.remediation_plan`

Render as a table with columns: Step | Description | Priority | Owner.

Bold priority values: `**Before merge**` or `**After merge**` (title-case).

### 10. Final Verdict

Source: `report.final_verdict`

Render as a plain paragraph.

---

## Style Rules

- Use inline code (backticks) for all file paths, identifiers, method names, and field names.
- Bold severity values and score values everywhere they appear.
- Use `**STALE**` (uppercase) for stale `tasks.md`; `**Current**` for current.
- Separate all top-level sections with `---` horizontal rules.
- Do not add any content beyond what the YAML fields provide.
- Do not reorder, merge, or rename any section.
