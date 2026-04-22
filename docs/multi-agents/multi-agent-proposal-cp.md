# Multi-Agent Spec-Driven Delivery Proposal

## Purpose

This document defines a practical multi-agent delivery process for running two or three LLM implementation routes against the same feature, comparing the results, selecting the best foundation, cherry-picking the best ideas from the losing routes, and integrating the final result with controlled risk.

The goal is not to maximize agent activity. The goal is to increase implementation quality while keeping the process auditable, reproducible, and safe to operate repeatedly across features.

This proposal assumes Spec-Driven Development with SpecKit and git worktrees.

## Primary Objectives

1. Keep one canonical feature specification.
2. Allow parallel implementation exploration across multiple LLMs or prompts.
3. Reduce model self-bias and route-identity bias during review.
4. Separate orchestration from judgment.
5. Make winner selection and cherry-pick decisions evidence-based.
6. Keep the process light enough to run repeatedly, not just once.

## Core Principles

### 1. One Canonical Spec, Many Implementation Routes

There must be exactly one canonical spec artifact set for a feature at any given time. Parallelism belongs in implementation and review, not in the definition of what the feature is supposed to do.

### 2. Reconcile Semantics, Not Text

When comparing specs, plans, tasks, reviews, or code, the system should reconcile meaning rather than line-by-line wording. Exact textual symmetry between routes is not required.

### 3. Blind Review Where Practical

Reviewers should evaluate Route A, Route B, and Route C without knowing which model or author produced them.

### 4. Conductor Is Procedural, Not Opinionated

The conductor runs the workflow, normalizes inputs, gathers reports, and manages disagreements. The conductor does not act as the deciding reviewer.

### 5. Adjudication Must Be Narrow

The adjudicator only resolves disagreements that fit pre-declared policy rules. Anything ambiguous, high-impact, or architectural should escalate to a human.

### 6. Re-Evaluate Only When Debate Changes Something Material

Do not automatically rerun full comparison after every debate. Add a targeted reevaluation step only when debate changes the factual basis for winner selection or cherry-pick recommendations.

## Recommended Topology

For each feature, create the following working routes:

1. `feature/<name>`
   This is the canonical spec branch.
2. `feature/<name>-route-a`
   Parallel implementation route A.
3. `feature/<name>-route-b`
   Parallel implementation route B.
4. `feature/<name>-route-c`
   Optional third implementation route.
5. `feature/<name>-integration`
   Final consolidation branch used to assemble the production candidate.

Use separate git worktrees for each route.

## Required Roles

### Spec Owner

Responsible for the canonical feature artifact set. This can be a human or a tightly-scoped agent flow supervised by a human.

### Implementation Routes

Each route is an isolated implementation attempt using the same canonical inputs.

### Reviewer A

Independent reviewer producing a structured comparison report.

### Reviewer B

Independent reviewer producing a second structured comparison report.

### Conductor

Runs the comparison workflow, anonymizes route identities, validates report completeness, extracts disagreements, launches debate, and prepares the adjudication packet.

### Adjudicator

Applies pre-approved decision policy to a narrow subset of disagreements.

### Human Gate

Approves the final winner, integration plan, and unresolved escalations.

## Canonical Artifact Set

The canonical feature artifact set should live in one spec root and be treated as the source of truth:

1. `spec.md`
2. `plan.md`
3. `tasks.md`
4. `research.md` when needed
5. `data-model.md` when needed
6. `contracts/` when needed
7. `checklists/requirements.md` when needed
8. `quickstart.md` when needed

If route branches use suffixes such as `-route-a` or `-route-b`, do not rely on automatic branch-name inference for the feature folder. Use an explicit `SPECIFY_FEATURE` value so every route points to the same canonical spec root.

## End-to-End Workflow

## Phase 1: Canonical Spec Creation

Run the spec flow once against the feature branch:

1. `specify`
2. `clarify`
3. `plan`

If you want model diversity during spec authoring, allow two models to draft or review these artifacts, but reconcile them before implementation starts. Do not let each implementation route carry its own independent spec or plan.

Output of Phase 1:

1. One approved `spec.md`
2. One approved `plan.md`
3. Optional supporting artifacts

## Phase 2: Task Generation

Recommended approach: generate tasks after spec and plan are reconciled, then reconcile tasks separately.

This is the preferred operating model.

Workflow:

1. Copy the canonical `spec.md` and `plan.md` to all implementation routes.
2. Run `tasks` independently in each route.
3. Compare task sets semantically.
4. Produce one canonical `tasks.md`.
5. Allow each route to keep route-local working notes if useful, but the canonical `tasks.md` remains the authoritative task list.

Why this is the recommended model:

1. It preserves implementation creativity.
2. It captures different decomposition strategies.
3. It prevents premature convergence.
4. It still restores a single execution contract before implementation begins.

Avoid these two extremes:

1. Forcing every route to use the first generated `tasks.md` removes useful route diversity.
2. Allowing each route to keep an unreconciled task set makes review and progress tracking inconsistent.

## Phase 3: Parallel Implementation

Each route receives the same canonical artifact set:

1. `spec.md`
2. `plan.md`
3. canonical `tasks.md`
4. any required supporting artifacts

Rules for implementation routes:

1. Routes may differ in internal approach.
2. Routes must not redefine requirements.
3. Routes may create route-local notes, but must not silently fork the canonical spec.
4. Any required requirement change must go back through canonical spec update, not route-local drift.

## Phase 4: Independent Comparison Reviews

When implementation routes are ready, run two independent comparison reviews.

Each reviewer should receive:

1. The canonical artifact set.
2. The code diff or worktree for each route.
3. Relevant tests, contracts, generated artifacts, and documentation.
4. Route labels anonymized as `Route A`, `Route B`, and `Route C`.

Each reviewer must produce a structured report instead of free-form prose.

Minimum required sections:

1. Executive recommendation
2. Per-route strengths and weaknesses
3. Spec coverage assessment
4. Testing and validation assessment
5. Risk register
6. Winner recommendation
7. Cherry-pick candidates
8. Integration concerns

## Required Review Issue Schema

Every material finding should use a structured record.

```json
{
  "id": "RISK-001",
  "title": "Route B omits retry backoff required by plan",
  "category": "spec-coverage",
  "severity": "high",
  "confidence": "high",
  "applies_to": ["Route B"],
  "spec_refs": ["spec.md#FR-4", "plan.md#resilience-strategy"],
  "evidence": [
    "worker loop retries immediately",
    "no bounded backoff configuration found"
  ],
  "recommendation": "Do not select Route B as foundation unless retry behavior is fixed.",
  "cherry_pick_candidate": false
}
```

## Phase 5: Conductor Normalization

The conductor consumes both reviewer outputs and performs only procedural work.

Conductor responsibilities:

1. Check that both reports are complete.
2. Normalize route names and issue IDs.
3. Merge duplicate findings.
4. Identify direct conflicts.
5. Separate factual disagreement from recommendation disagreement.
6. Build a disagreement ledger.
7. Launch targeted debate only for material conflicts.

The conductor must not silently decide which reviewer is correct.

## Disagreement Ledger Format

The conductor should produce a machine-readable disagreement ledger.

```json
{
  "feature": "<feature-name>",
  "winner_disputed": true,
  "disagreements": [
    {
      "id": "D-001",
      "type": "winner-selection",
      "topic": "Route A vs Route B foundation choice",
      "reviewer_a_position": "Route A is safer operationally",
      "reviewer_b_position": "Route B is cleaner and easier to extend",
      "materiality": "high",
      "debate_required": true
    }
  ]
}
```

## Phase 6: Bounded Debate

Debate should happen only on material disagreements.

Do not run open-ended reviewer conversations across the entire report set.

Debate rules:

1. Debate one disagreement at a time.
2. Each reviewer may restate its claim with evidence.
3. Each reviewer must directly answer the other reviewer’s strongest point.
4. Each reviewer may revise, narrow, or withdraw a claim.
5. Debate ends after one rebuttal round unless escalation is clearly justified.

Debate output for each disagreement:

1. unchanged
2. narrowed
3. resolved
4. escalated

## Phase 7: Adjudication

The adjudicator operates only on disagreements that match predefined safe-resolution policy.

Examples of disagreements that may be adjudicated automatically:

1. A claim is contradicted by direct repository evidence.
2. A route clearly fails a mandatory spec requirement.
3. A route clearly lacks required tests or broken validation.
4. A reviewer claim is shown to rely on a false premise.

Examples that must escalate to a human:

1. Architectural tradeoffs with plausible long-term consequences.
2. Performance versus maintainability tradeoffs without decisive evidence.
3. Security or compliance implications that are not mechanically provable.
4. Cases where the winner depends on business priority rather than technical correctness.

Adjudication result states:

1. auto-resolved
2. escalate-to-human
3. insufficient-evidence

## Phase 8: Conditional Winner Re-Evaluation

Add a reviewer re-evaluation step only if all of the following are true:

1. The initial winner was disputed.
2. Debate changed one or more material claims.
3. Those changed claims affect foundation selection or major cherry-pick decisions.

This reevaluation must be delta-only.

The reviewers should not rerun the full comparison from scratch. They should reassess only:

1. winner recommendation
2. top blocking risks
3. cherry-pick list
4. integration strategy

If both reviewers converge after delta reevaluation, proceed.
If they still disagree materially, escalate.

## Phase 9: Final Integration

The integration branch is built from:

1. the selected foundation route
2. approved cherry-picks from non-winning routes
3. any adjudication-mandated fixes

The integration step should explicitly record:

1. winning route
2. accepted cherry-picks
3. rejected cherry-picks and why
4. unresolved risks
5. tests executed

The integration branch should not become an unstructured manual merge zone.

## Winner Selection Policy

The winning route should be selected using ordered criteria.

Recommended order:

1. Mandatory spec compliance
2. Correctness and failure handling
3. Test completeness and validation quality
4. Operational safety
5. Simplicity of integration
6. Maintainability and extensibility
7. Performance, when supported by evidence
8. Style or elegance, only as a final tiebreaker

Do not select a route because it looks more sophisticated if the simpler route is more correct and safer to ship.

## Cherry-Pick Policy

Cherry-picks should be issue-based, not broad route blending.

A cherry-pick is acceptable only if:

1. it is independently understandable,
2. it improves the winning foundation,
3. it does not import unresolved architectural assumptions,
4. it does not conflict with the winning route’s core structure,
5. it can be validated with targeted tests.

Cherry-pick categories:

1. safe
2. needs-adaptation
3. reject

## Artifact Outputs Per Feature

For each feature, persist these outputs so the workflow is auditable:

1. canonical spec artifact set
2. reviewer A report
3. reviewer B report
4. disagreement ledger
5. debate transcript or structured debate result
6. adjudication result
7. reevaluation note when triggered
8. integration decision record

Suggested location pattern:

```text
specs/<feature>/
  spec.md
  plan.md
  tasks.md
  reviews/
    reviewer-a.md
    reviewer-b.md
    disagreement-ledger.json
    debate.md
    adjudication.md
    reevaluation.md
    integration-decision.md
```

## Prompt and Agent Changes Recommended Before Adoption

This process can be piloted immediately, but these changes should be made early.

### 1. Remove Stack Bias From Comparer Agents

Current comparer agents are written as `.NET/C#` principal reviewers. That is a risk if the target implementation is Go-heavy or mixed-stack.

Update comparer agents so they are stack-aware or stack-neutral.

### 2. Shift Reconcile Prompts Toward Structured Output

Current reconciliation prompts are closer to narrative expert reports than machine-operable decision artifacts.

Add explicit output schemas for:

1. findings
2. winner recommendation
3. cherry-pick records
4. disagreement ledger
5. escalation list

### 3. Stop Relying On Implicit Feature Folder Inference

Route branch suffixes will make branch-name based spec folder inference brittle. Use an explicit feature identifier.

### 4. Add Policy Files For Adjudication

Document what may be auto-resolved and what must escalate.

## Recommended Human Checkpoints

The process is intentionally automated, but these human checkpoints should remain:

1. approve canonical spec before implementation starts
2. approve canonical tasks before route implementation begins
3. approve final winner and cherry-pick plan if any high-severity disagreement remains
4. approve integration branch before merge to main

## Minimal Viable Rollout

Start with the smallest version that proves the workflow.

### Pilot Scope

1. Use two implementation routes, not three.
2. Use two independent reviewers.
3. Use a conductor.
4. Keep adjudication narrow.
5. Require human approval for disputed winners.

### First Iteration Deliverables

1. canonical feature artifacts
2. reviewer output schema
3. disagreement ledger schema
4. integration decision template
5. updated comparer prompts or agents with stack-neutral language

### What To Delay Until Later

1. fully automated multi-round debate
2. complex scoring models
3. automatic merge execution
4. auto-approval of architectural tradeoffs

## Recommended Default Operating Rules

Use these as the starting policy.

1. One canonical spec root per feature.
2. Tasks are generated independently, then reconciled once.
3. Routes implement against the same canonical artifacts.
4. Reviews are blind and independent.
5. The conductor may organize but not decide.
6. Debate is issue-scoped and one round by default.
7. Adjudication is allowed only for narrow evidence-based conflicts.
8. Winner reevaluation is conditional and delta-only.
9. The integration branch must record every cherry-pick decision.
10. High-severity unresolved disagreements always go to a human.

## Final Recommendation

Adopt a four-stage comparison model:

1. canonical spec and plan
2. independent task generation followed by task reconciliation
3. parallel implementation routes
4. dual review, conductor-led disagreement handling, narrow adjudication, and conditional reevaluation before final integration

This gives you meaningful route diversity without letting the process fragment into multiple competing truths. It also reduces the biggest failure mode in multi-agent delivery: a confident but weak reviewer or reconciler steering the whole system without structured challenge.

If this proposal is adopted, the next practical step is to codify the review output schema and disagreement ledger, then update the comparer and reconcile prompts to emit those structures directly.