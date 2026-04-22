---
description: Consolidate 2-3 independent speckat.compare-code YAML review reports (produced by different LLMs) into a single unified report that highlights reviewer alignment and divergences.
argument-hint: <review-yaml-1> <review-yaml-2> [review-yaml-3]
agent: speckat.comparer-code-merge
---

## User Input

```text
$ARGUMENTS
```

You MUST consider the user input before proceeding.

## Required Inputs

This prompt consolidates independent review reports. It does NOT perform a new code review.

You need all of the following before proceeding:

1. Two or three YAML file paths — each a `speckat.compare-code` report produced by a different LLM
2. All files must review the same pair of implementations (same normalized `team_cl_feature_path` and normalized `team_cp_feature_path`)

Interpret the arguments as an ordered list of YAML file paths:

1. `review-yaml-1` (required)
2. `review-yaml-2` (required)
3. `review-yaml-3` (optional)

If fewer than 2 arguments are provided, stop and ask the user for the missing path(s).

## Preconditions

Before analysis, validate:

1. All input files are valid YAML matching the `speckat.compare-code` schema (top-level `report` key with `meta`, `executive_recommendation`, `comparison_matrix`, etc.).
2. All reports review the same feature pair — compare `meta.team_cl_feature_path` and `meta.team_cp_feature_path` using normalized feature identity, not raw string equality.
3. All reports use the same `meta.canonical_base_branch`.

Normalize feature paths before comparing them:

1. Convert backslashes to forward slashes and trim trailing slashes.
2. If the path is absolute, strip everything through `/specs/`.
3. Canonicalize the result to repo-relative `specs/<feature-directory>` form.
4. Derive the feature alias stem by removing the final hyphen-delimited suffix segment from `<feature-directory>`.

Validation rules after normalization:

1. All `team_cl_feature_path` values across inputs must canonicalize to the same Team-CL feature directory.
2. All `team_cp_feature_path` values across inputs must canonicalize to the same Team-CP feature directory.
3. The CL and CP feature directories must share the same feature alias stem.

Valid examples:

- `DATA-5330-2-Migrate-v1-to-v2-go-CL`
- `DATA-5330-2-Migrate-v1-to-v2-go-CP`

- `DATA-5330-2-Migrate-v1-to-v2-go-A`
- `DATA-5330-2-Migrate-v1-to-v2-go-B`

Reject example:

- `DATA-5330-2-Migrate-v1-to-v2-go-CL`
- `DATA-5331-Migrate-v1-to-v2-go-CP`

Examples that must be treated as equivalent:

- `specs/DATA-5330-2-Migrate-v1-to-v2-go-CL`
- `C:/Projects/Eclypsium/VLS.Cloud.CL/specs/DATA-5330-2-Migrate-v1-to-v2-go-CL`

Only fail this precondition when the normalized feature identities differ or the alias stems do not match. Do not fail solely because one review used an absolute worktree path and another used a repo-relative path.

If any precondition fails, stop and explain the mismatch to the user.

## File Handling Rules

Treat all input review files as read-only.

- Do not edit, overwrite, rename, or delete any input review YAML files.
- Do not modify source code files as part of this prompt.
- You may create new output artifacts required by this prompt, including the merged YAML report and a rendered markdown report.
- Prefer creating new files rather than modifying existing merged artifacts.
- If the target merged output file already exists, stop and ask the user whether to overwrite it.

## Analysis Process

### Step 1 — Inventory and Key the Reviews

For each input file, extract:

- `meta.reviewed_by_llm` — the reviewer model identity
- `meta.generated_at` — when the review was produced
- `executive_recommendation.preferred_team` — the reviewer's top-level recommendation

Then derive a **2-letter reviewer key** for each reviewer. The key is used throughout the report for compact inline attribution.

Derivation rules:

1. Extract the primary model word from `reviewed_by_llm` (strip vendor prefixes like `claude-`).
2. Take the first two characters, uppercase.
3. If two reviewers collide, append the first version digit to the second reviewer (e.g., `SO` and `SO4`).

Common mappings:

| LLM identifier | Key | Reason |
|---|---|---|
| `gpt-5.4` | `GP` | **g**p**t** → GP |
| `opus-4.6` / `claude-opus-4.6` | `OP` | **op**us → OP |
| `sonnet-4` / `claude-sonnet-4` | `SO` | **so**nnet → SO |
| `gemini-2.5-pro` | `GE` | **ge**mini → GE |
| `o3` | `O3` | short name used as-is |
| `deepseek-v3` | `DE` | **de**epseek → DE |

Record the mapping in `meta.reviewer_keys` so the renderer can produce a legend.

Use these keys throughout the report: in `flagged_by` arrays, `corroborated_by` arrays, `recommended_by` arrays, `perspectives[].reviewer`, and with `[XX]` inline notation inside free-text fields for attribution (e.g., "Uses connection pooling [OP] but lacks retry logic [GP, SO]").

### Step 2 — Executive Alignment

Compare the `preferred_team` values across all reviewers:

- **Full agreement**: all reviewers select the same team (or all select hybrid with the same base). Record as `consensus`.
- **Majority agreement**: 2 of 3 agree, 1 diverges. Record as `majority` and note the dissenting reviewer.
- **No agreement**: no majority on preferred team. Record as `split`.

For hybrid recommendations, compare `hybrid_base` values as well.

### Step 3 — Comparison Matrix Consolidation

All scores must be integers on a **1-10 scale** (1 = worst, 10 = best). If a source review uses a different scale (e.g., 1-5, letter grades, qualitative labels), **normalize** it to 1-10 before consolidation by applying a linear mapping and rounding to the nearest integer.

For each of the 11 criteria in `comparison_matrix`:

1. Collect and normalize all reviewer scores for Team-CL and Team-CP.
2. Produce a consolidated score: use the **median** score when 3 reviewers are present; use the **lower** score when 2 reviewers diverge (conservative posture).
3. Synthesize reviewer notes into a single `consolidated_notes` paragraph — deduplicate conceptually equivalent observations, attribute unique insights with `[XX]` notation.
4. When scores **diverge** (differ by 3 or more points after normalization), create a divergence entry in the `divergences` section rather than recording alignment in-line. The comparison matrix shows only consolidated scores.

### Step 3A — Score Matrix Synthesis

Build a compact score matrix that summarizes reviewer-level and combined team-level scoring.

Use the **10 atomic criteria** below and explicitly **exclude `Overall Quality`** from all score-matrix calculations so the summary does not double-count a reviewer-authored rollup judgment.

Atomic criteria:

1. `PRD Alignment`
2. `Speckit Alignment`
3. `Correctness`
4. `Completeness`
5. `Code Quality`
6. `Tests`
7. `Simplicity`
8. `Robustness`
9. `Operational Readiness`
10. `Merge Risk`

For each team and each reviewer:

1. Compute `average_score` as the arithmetic mean across the 10 atomic criteria.
2. Compute `weighted_score` as a **real weighted reviewer score** using the default weights below.
3. Round both values to **2 decimal places**.

For each team, also add a `Combined` row:

1. `average_score` = arithmetic mean of all reviewer `average_score` values for that team.
2. `weighted_score` = arithmetic mean of all reviewer `weighted_score` values for that team.
3. Round both values to **2 decimal places**.

Weighted-score formula:

`weighted_score(team, reviewer) = Σ(weight(criterion) × normalized_score(team, reviewer, criterion))`

Default weights for IT implementation merge decisions:

<!-- Informational default weights for score_matrix. These reflect common implementation-review priorities: production correctness, test confidence, robustness, and requirements fit carry the most weight. Only change them when the user explicitly requests a different weighting model. -->

| Criterion | Weight |
|---|---:|
| `Correctness` | `0.20` |
| `Tests` | `0.18` |
| `Robustness` | `0.15` |
| `PRD Alignment` | `0.15` |
| `Completeness` | `0.10` |
| `Operational Readiness` | `0.08` |
| `Code Quality` | `0.06` |
| `Merge Risk` | `0.04` |
| `Speckit Alignment` | `0.03` |
| `Simplicity` | `0.01` |

### Step 4 — Findings Consolidation

Merge the `findings` arrays from all reports:

1. Group findings that describe the **same issue** (same file/location, same category, same team). Two findings are "the same" if they reference the same code location and describe the same problem, even if worded differently.
2. For each unique finding:
   - Record which reviewers flagged it (`flagged_by` list using 2-letter keys).
   - Use the **highest** severity assigned by any reviewer (conservative posture).
   - **Synthesize** a single description — do not concatenate multiple phrasings. Write one clear, concise description that captures the essence of the finding. Use `[XX]` attribution only for observations unique to one reviewer.
   - When reviewers assign **different severities**, create a divergence entry in the `divergences` section.
3. Flag findings identified by **only one reviewer** as `single_reviewer: true` — these need extra human scrutiny.
4. Re-number as `MF-1`, `MF-2`, etc. in the consolidated report.

### Step 5 — Alignment Findings Consolidation

Same grouping logic as implementation findings:

1. Group by the requirement being evaluated.
2. Note which reviewers identified each alignment gap.
3. Where reviewers describe the same gap differently, preserve both perspectives.
4. Re-number as `MAF-1`, `MAF-2`, etc.

### Step 6 — Cherry-Pick Consolidation

1. Group cherry-pick recommendations that target the same code/feature.
2. Note which reviewers recommended each cherry-pick.
3. Cherry-picks recommended by **multiple** reviewers have higher confidence.
4. Re-number as `MC-1`, `MC-2`, etc.

### Step 7 — Remediation Plan Synthesis

Build a unified, deduplicated remediation plan. Group conceptually equivalent steps from different reviewers — even when worded differently — into a single step with a synthesized description.

Sort the plan into three tiers, in this order:

1. **Tier 1 — Unanimous** (`agreement: "all"`): Steps that appear in every input report. These go at the top.
2. **Tier 2 — Majority** (`agreement: "majority"`): Steps corroborated by most but not all reviewers, plus single-reviewer steps that address High/Critical findings.
3. **Tier 3 — Single reviewer** (`agreement: "single"`): Steps from one report only, addressing Medium/Low findings. Include these for completeness but the human may deprioritize them.

Within each tier, order by priority (`before-merge` first, then `after-merge`).

Re-number steps sequentially across all tiers.

### Step 8 — Spec Drift Consolidation

1. Merge `spec_drift` arrays — group by file.
2. Use the **most severe** classification when reviewers disagree on trivial vs. substantial.
3. Note when only one reviewer flagged a drift item.
4. Re-number as `MSD-1`, `MSD-2`, etc.

### Step 9 — Divergence Analysis

This is the **single consolidated section** for all reviewer disagreements across the entire report. Every disagreement — whether in executive recommendation, comparison scores, finding severities, cherry-pick recommendations, remediation priorities, or spec drift classifications — must be captured here. No other section should contain inline divergence indicators.

For every point where reviewers **disagree**:

1. Identify the specific disagreement and tag it with the `area` it came from (e.g., `comparison_matrix / Code Quality`, `findings / MF-3 severity`, `executive_recommendation`).
2. Present **each reviewer's reasoning** using their 2-letter key.
3. Assess whether the divergence is:
   - **Perspective difference**: both are valid viewpoints; human judgment required.
   - **Information gap**: one reviewer noticed something the others missed.
   - **Analytical error**: one reviewer's reasoning appears flawed given the evidence.
4. Provide a consolidation recommendation but label it clearly as the merger's assessment, not a reviewer consensus.

Number as `D-1`, `D-2`, etc. Sort by impact — the disagreements that most affect the merge decision come first.

## Structured Output

Emit your complete report as a single fenced YAML block. Do not write any prose, markdown headers, or commentary outside the fence. The YAML block is the complete and only output.

In addition to emitting the fenced YAML block, create a new merged-report file at the required output path below. The source review files remain read-only; only newly created merged artifacts may be written by this prompt.

### Output File Location and Naming

Save the YAML output to a file under `specs/reviews/` in the repository root. Create the directory if it does not exist.

Derive the file name from the input review files:

1. Take the branch leaf from one of the input files (strip the model suffix). For example `DATA-5330-Migrate-v1-to-v2-go-opus-4_6.yaml` → `DATA-5330-Migrate-v1-to-v2-go`.
2. Append `-merged`.
3. Add the `.yaml` extension.

Final path pattern:

```
specs/reviews/<branch-leaf>-merged.yaml
```

Examples:

| Input files | Output file |
| --- | --- |
| `DATA-5330-...-opus-4_6.yaml`, `DATA-5330-...-gpt-5_4.yaml` | `specs/reviews/DATA-5330-Migrate-v1-to-v2-go-merged.yaml` |
| `DATA-1001-null-check-sonnet-4.yaml`, `DATA-1001-null-check-opus-4_6.yaml`, `DATA-1001-null-check-gpt-5_4.yaml` | `specs/reviews/DATA-1001-null-check-merged.yaml` |

The rendered markdown report follows the same convention but with a `.md` extension.

If the prompt later renders markdown from the merged YAML, that markdown file may also be created as a new output artifact. Do not overwrite an existing markdown render without user approval.

### YAML Schema

The YAML must contain a top-level `merged_report` key with the following structure. All fields are required; use `""` for empty strings and `[]` for empty lists rather than null.

```yaml
merged_report:
  meta:
    team_cl_feature_path: string         # canonical normalized repo-relative path derived from source reports, e.g. specs/<feature-directory>
    team_cp_feature_path: string         # canonical normalized repo-relative path derived from source reports, e.g. specs/<feature-directory>
    canonical_base_branch: string        # from source reports (validated identical)
    product_docs: [string, ...]          # union of all source product_docs
    generated_at: string                 # ISO-8601 timestamp of this merge
    reviewer_keys:                       # 2-letter key → full LLM name
      XX: string                         # e.g. GP: "gpt-5.4", OP: "opus-4.6"
    source_reviews:                      # one entry per input review file
      - file: string                     # input YAML file path
        reviewed_by_llm: string          # full model identifier from source meta
        key: string                      # 2-letter key (matches reviewer_keys)
        generated_at: string             # timestamp from source meta
        preferred_team: string           # from source executive_recommendation

  executive_consensus:
    agreement_level: string              # exactly: "consensus", "majority", or "split"
    consolidated_recommendation: string  # exactly: "Team-CL", "Team-CP", or "hybrid"
    hybrid_base: string | null           # "Team-CL" or "Team-CP" when hybrid; null otherwise
    summary: string                      # 3-5 sentence synthesis explaining the consolidated position
    per_reviewer:                        # one entry per source review
      - reviewer: string                 # 2-letter key
        preferred_team: string           # that reviewer's recommendation
        hybrid_base: string | null
        summary_excerpt: string          # key quote or paraphrase from the reviewer's summary

  comparison_matrix:                     # same 11 criteria as source reports
    - criterion: string
      team_cl:
        consolidated_score: integer      # median/conservative; 1-10 scale
        reviewer_scores:                 # one per source review
          - reviewer: string             # 2-letter key
            score: integer               # normalized to 1-10
            original_score: string       # raw value from source (for audit trail)
            notes: string
        consolidated_notes: string       # synthesized; use [XX] for reviewer-specific insights
      team_cp:
        consolidated_score: integer      # median/conservative; 1-10 scale
        reviewer_scores:
          - reviewer: string             # 2-letter key
            score: integer               # normalized to 1-10
            original_score: string       # raw value from source (for audit trail)
            notes: string
        consolidated_notes: string

  score_matrix:
    criteria_included: [string, ...]     # exactly the 10 atomic criteria used in score calculations
    excluded_criteria: [string, ...]     # must include "Overall Quality"
    weights:                             # criterion -> weight used for weighted_score
      criterion_name: number
    rows:
      - team: string                     # "Team-CL" or "Team-CP"
        reviewer: string                 # 2-letter key or "Combined"
        average_score: number            # arithmetic mean across atomic criteria; 2 decimals
        weighted_score: number           # weighted reviewer score; 2 decimals

  alignment_findings:                    # merged alignment findings; [] if none
    - id: string                         # "MAF-1", "MAF-2", ...
      requirement: string
      expected: string
      team_cl_observation: string        # synthesized; use [XX] for reviewer-specific details
      team_cp_observation: string        # synthesized; use [XX] for reviewer-specific details
      impact: string
      flagged_by: [string, ...]          # 2-letter keys
      single_reviewer: boolean           # true if only one reviewer flagged this

  team_cl:
    tasks_md_status: string              # use most-critical status across reviewers
    tasks_md_notes: string               # synthesized
    pros: [string, ...]                  # deduplicated union; use [XX] for unique items
    cons: [string, ...]                  # deduplicated union; use [XX] for unique items
    reviewer_agreement: string           # brief note on how reviewers aligned on this team

  team_cp:
    tasks_md_status: string
    tasks_md_notes: string
    pros: [string, ...]                  # deduplicated union; use [XX] for unique items
    cons: [string, ...]                  # deduplicated union; use [XX] for unique items
    reviewer_agreement: string

  findings:                              # merged implementation findings; [] if none
    - id: string                         # "MF-1", "MF-2", ...
      team: string                       # "Team-CL", "Team-CP", or "Both"
      severity: string                   # highest across reviewers (conservative)
      category: string
      description: string                # synthesized — one clear description, not concatenated
      impact: string
      evidence: string
      flagged_by: [string, ...]          # 2-letter keys
      single_reviewer: boolean

  cherry_picks:                          # merged cherry-picks; [] if none
    - id: string                         # "MC-1", "MC-2", ...
      from_team: string
      description: string
      rationale: string
      target_files: [string, ...]
      recommended_by: [string, ...]      # 2-letter keys
      confidence: string                 # "high" (multiple reviewers) or "single-reviewer"

  remediation_plan:                      # unified ordered steps; sorted by agreement tier
    - step: integer
      description: string                # synthesized — one description per unique action
      priority: string                   # "before-merge" or "after-merge"
      owner: string
      agreement: string                  # "all", "majority", or "single"
      corroborated_by: [string, ...]     # 2-letter keys

  spec_drift:                            # merged spec drift; [] if none
    - id: string                         # "MSD-1", "MSD-2", ...
      file: string
      classification: string             # most severe across reviewers
      team_cl_value: string
      team_cp_value: string
      description: string
      impact: string
      flagged_by: [string, ...]          # 2-letter keys
      single_reviewer: boolean

  divergences:                           # THE single section for ALL reviewer disagreements
    - id: string                         # "D-1", "D-2", ...
      area: string                       # source section (e.g. "comparison_matrix / Code Quality")
      description: string                # what exactly the reviewers disagree on
      perspectives:                      # one per disagreeing reviewer
        - reviewer: string               # 2-letter key
          position: string               # what this reviewer said/scored
          reasoning: string              # why — quote or paraphrase from the review
      divergence_type: string            # "perspective-difference", "information-gap", or "analytical-error"
      merger_assessment: string          # the consolidation agent's own take (clearly labeled)

  final_verdict: string                  # 3-6 sentence decisive closing; synthesized, not concatenated
```

### Reporting Guidance

- **Synthesize, don't concatenate.** If three reviewers say the same thing in three different ways, write it once clearly. The merged report should be shorter and more focused than any single input — not three times as long.
- **The divergences section is the single source of truth for all disagreements.** No other section should contain alignment/divergence indicators. Invest the most analytical effort here.
- The `score_matrix` is a convenience summary, not a replacement for the per-criterion evidence. It should make reviewer tendencies and team-level weighted standing easier to scan, while the `comparison_matrix`, `findings`, and `divergences` remain authoritative.
- When reviewers agree, be concise — the human doesn't need to re-read what they already know.
- When reviewers disagree, be thorough — present each perspective fairly and let the human decide.
- Never fabricate consensus. If reviewers genuinely disagree, say so. The `split` agreement level exists for a reason.
- Use the conservative posture throughout: highest severity, lowest score, most critical classification.
- Use 2-letter reviewer keys (`[XX]`) for all attribution. Reserve full model names for the legend and metadata only.
- Treat absolute worktree paths and repo-relative paths as equivalent when they normalize to the same `specs/<feature-directory>` identity. Emit the canonical repo-relative form in `merged_report.meta.team_cl_feature_path` and `merged_report.meta.team_cp_feature_path`.
- Where a single reviewer noticed something the others missed, flag it with `single_reviewer: true` — this doesn't mean they're wrong, but it means the finding hasn't been independently corroborated.
- The consolidated recommendation in `executive_consensus` must be defensible from the evidence. If the merger disagrees with the majority, explain why in the divergences section.

### Output Examples

See the individual review examples at [`.specify/examples/speckat.compare-code.example-1.yaml`](../../.specify/examples/speckat.compare-code.example-1.yaml) and [`.specify/examples/speckat.compare-code.example-2.yaml`](../../.specify/examples/speckat.compare-code.example-2.yaml) for the input format this prompt consumes.

To render the merged YAML output into a human-readable markdown report, use the rendering prompt:

```
@speckat.compare-code.merge-render <path-to-merged-yaml>
```
