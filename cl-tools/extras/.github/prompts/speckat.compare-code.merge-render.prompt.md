---
description: Render a speckat.compare-code merged YAML report into a formatted markdown report for human review.
argument-hint: <yaml-file-path>
---

## User Input

```text
$ARGUMENTS
```

You MUST consider the user input before proceeding.

## Required Input

This prompt renders a single merged `speckat.compare-code` YAML review report.

You need the following before proceeding:

1. One YAML file path whose top-level key is `merged_report`

If the provided YAML instead uses the `report` schema, stop and instruct the caller to use `speckat.compare-code.render`.

## Task

Read the merged YAML file at the path provided in the user input and render it into a formatted markdown report.

1. Read the YAML file at the provided path.
2. Produce a markdown report that maps exactly to the YAML schema — no sections added, no sections omitted, no section order changed.
3. Save the rendered markdown to a file next to the YAML source with the same base name but a `.md` extension. For example, if the input is `specs/reviews/DATA-5330-Migrate-v1-to-v2-go-merged.yaml`, write the output to `specs/reviews/DATA-5330-Migrate-v1-to-v2-go-merged.md`.
4. Output only the rendered markdown. Do not add commentary, preamble, or code fences around the output.

## File Handling Rules

Treat the input YAML file as read-only.

- Do not edit, overwrite, rename, or delete the input YAML file.
- You may create the rendered markdown file required by this prompt.
- If the target markdown file already exists, stop and ask the user whether to overwrite it.
- The markdown file created by this prompt is an output artifact, not a source-file modification.

## Metadata Header

Add this block above all sections:

```
> **Merged report from:** <count> independent reviews
> **Source reviews:** <comma-separated list of source_reviews[].file>
> **Reviewers:** <for each reviewer_keys entry: `XX` = full_name, comma-separated>
> **Agreement level:** <executive_consensus.agreement_level>
> **Generated:** <merged_report.meta.generated_at>
```

Example reviewers line: `> **Reviewers:** `OP` = opus-4.6, `GP` = gpt-5.4, `SO` = sonnet-4`

This line serves as the legend for all 2-letter reviewer keys used throughout the report.

If `agreement_level` is `"split"`, append immediately after the metadata block:

```
> **⚠️ No reviewer consensus — see [Divergences](#divergences) for details.**
```

If `merged_report.spec_drift` is non-empty and contains any entry where `classification` is `"substantial"`, append:

```
> **⚠️ Spec drift detected — see [Spec Files Drift](#spec-files-drift) for details.**
```

---

## Section Mapping

Render sections in this exact order using `##` headings, separated by `---` horizontal rules.

### 1. Executive Consensus

Source: `merged_report.executive_consensus`

Open with: `**Agreement level: <agreement_level>**`

Then: `**Consolidated recommendation: <consolidated_recommendation>**` (include `(<hybrid_base> base)` when hybrid).

Follow with the `summary` field as a paragraph.

Then render a **Reviewer Positions** table:

| Key | Recommendation | Key Reasoning |
|---|---|---|
| `<reviewer>` | `<preferred_team>` | `<summary_excerpt>` |

### 2. Scope And Inputs

Source: `merged_report.meta`

Render as a two-column table (Item | Value):

| Item | Value |
|---|---|
| Team-CL Feature Path | `<team_cl_feature_path>` |
| Team-CP Feature Path | `<team_cp_feature_path>` |
| Canonical Base Branch | `<canonical_base_branch>` |
| Product Documents | comma-separated list of `product_docs` entries; "None" if empty |
| Source Reviews | numbered list: `1. <file> (<reviewed_by_llm>, <generated_at>)` |

### 3. Comparison Matrix

Source: `merged_report.comparison_matrix`

For each criterion, render a sub-section:

#### `<criterion>`

Two-column layout per team:

**Team-CL** — Consolidated: **`<consolidated_score>`**/10

| Key | Score | Original | Notes |
|---|---|---|---|
| `<reviewer>` | `<score>`/10 | `<original_score>` | `<notes>` |

> `<consolidated_notes>`

**Team-CP** — same format.

If `original_score` equals the normalized `score` (i.e., original was already 1-10), the Original column may show `—`.

### 4. Alignment Findings

Source: `merged_report.alignment_findings`

Render as a table with columns: ID | Requirement | Expected | Team-CL Observation | Team-CP Observation | Impact | Flagged By | Single Reviewer.

Bold `single_reviewer` values that are `true`: **Yes**.

If the list is empty, write: "No alignment findings."

### 5. Team-CL Review

Source: `merged_report.team_cl`

Open with a blockquote showing tasks.md status (same format as individual render prompt).

Then: `> Reviewer agreement: <reviewer_agreement>`

Follow with **Pros** and **Cons** bullet lists.

### 6. Team-CP Review

Source: `merged_report.team_cp`

Same structure as Team-CL Review.

### 7. Implementation Findings

Source: `merged_report.findings`

Render as a table with columns: ID | Team | Severity | Category | Description | Impact | Evidence | Flagged By | Single Reviewer.

Bold the severity value. Bold `single_reviewer` values that are `true`.

If the list is empty, write: "No implementation findings."

### 8. Cherry-Pick Recommendations

Source: `merged_report.cherry_picks`

Render as a table with columns: ID | From | Description | Rationale | Target Files | Recommended By | Confidence.

Bold confidence `"high"` values: **high**.

If the list is empty, write: "No cherry-picks recommended."

### 9. Remediation Plan

Source: `merged_report.remediation_plan`

Group steps by `agreement` tier with sub-headings:

#### Unanimous (all reviewers agree)

Steps where `agreement` is `"all"`.

#### Majority

Steps where `agreement` is `"majority"`.

#### Single Reviewer

Steps where `agreement` is `"single"`.

Within each tier, render as a table with columns: Step | Description | Priority | Owner | Corroborated By.

Bold priority values: `**Before merge**` or `**After merge**`.

If a tier has no steps, omit the sub-heading entirely.

### 10. Spec Files Drift

Source: `merged_report.spec_drift`

If the list is empty, write: "No spec file drift detected."

Otherwise, open with:

> **⚠️ Spec artifact drift detected.** The following differences were found across reviewer reports. Substantial differences should be reconciled.

Then render as a table with columns: ID | File | Classification | Team-CL Value | Team-CP Value | Description | Impact | Flagged By | Single Reviewer.

Bold the classification: `**Trivial**` or `**Substantial**`.

### 11. Divergences

Source: `merged_report.divergences`

**This is the most important section of the report.** Render it with maximum clarity.

If the list is empty, write: "All reviewers are in full agreement. No divergences found."

Otherwise, for each divergence render a sub-section:

#### D-`<N>`: `<description>` (`<area>`)

**Type:** `<divergence_type>`

**Perspectives:**

For each perspective, render as a blockquote:

> **`<reviewer>`**: `<position>`
>
> `<reasoning>`

**Merger's assessment:** `<merger_assessment>`

---

### 12. Final Verdict

Source: `merged_report.final_verdict`

Render as a plain paragraph.

---

## Style Rules

- Use inline code (backticks) for all file paths, identifiers, method names, and field names.
- Bold severity values, scores, and confidence levels everywhere they appear.
- Use 2-letter reviewer keys (`OP`, `GP`, etc.) for all inline attribution throughout the report. Never use full model names outside the metadata header legend.
- Use `**STALE**` (uppercase) for stale `tasks.md`; `**Current**` for current.
- Separate all top-level sections with `---` horizontal rules.
- Do not add any content beyond what the YAML fields provide.
- Do not reorder, merge, or rename any section.
- The Divergences section should stand out visually — it's the primary decision-making tool.
