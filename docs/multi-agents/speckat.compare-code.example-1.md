# Code Comparison Report — User Notification Preferences

> **Rendered from:** `speckat.compare-code.example-1.yaml`  
> **Reviewed by LLM:** claude-opus-4  
> **Generated:** 2026-04-08T09:15:00Z

---

## Executive Summary

**Recommended foundation: Team-CP**

Team-CP is the preferred foundation. Its per-channel JSONB preference model correctly implements the spec, covers all acceptance criteria including digest mode, and its migration safely backfills existing users. Team-CL's per-category boolean schema deviates from the spec and cannot be corrected without a breaking data migration. Team-CL's test factories are the only cherry-pick.

---

## Scope And Inputs

| Item | Value |
|---|---|
| Team-CL Feature Path | `specs/2025-11/notification-preferences` |
| Team-CP Feature Path | `specs/2025-11/notification-preferences` |
| Canonical Base Branch | `main` |
| Product Documents | `docs/product/notifications-prd.md` |

---

## Comparison Matrix

| Criterion | Team-CL | Team-CP |
|---|---|---|
| PRD Alignment | **Medium** — Category boolean model conflicts with PRD per-channel model; digest mode missing. | **High** — All PRD requirements implemented including digest mode and unsubscribe flow. |
| Speckit Alignment | **Low** — Data model deviates from spec; tasks.md marks digest mode done but it is not implemented. | **High** — Spec faithfully implemented; tasks.md is accurate. |
| Correctness | **Medium** — Opt-out logic inverted for in-app notifications (F-1). | **High** — All acceptance criteria verified passing. |
| Completeness | **Medium** — Digest mode not implemented; unsubscribe confirmation email missing. | **High** — All acceptance criteria implemented. |
| Code Quality | **Medium** — `notification_settings.rb` is 320 lines mixing service and controller concerns. | **High** — Clean service layer; thin controller; well-separated concerns. |
| Tests | **High** — Strong factory helpers; 94% line coverage on changed files. | **Medium** — 82% coverage; missing edge cases for malformed channel values in JSONB. |
| Simplicity | **Medium** — Per-category booleans are simpler but implement the wrong model. | **High** — JSONB preferences column is idiomatic and naturally extensible. |
| Robustness | **Medium** — Silent nil when a user has no preference row. | **High** — Nil-safe accessor returns spec-defined defaults when row is absent. |
| Operational Readiness | **Medium** — Migration does not backfill existing users; silent failure for existing accounts. | **High** — Migration backfills all existing users with safe opt-in defaults. |
| Merge Risk | **High** — Boolean schema requires breaking migration to align with spec; high rollback complexity. | **Low** — Self-contained; no breaking changes to existing behavior. |
| Overall Quality | **Medium** | **High** |

---

## Alignment Findings

| ID | Requirement | Expected | Team-CL Observation | Team-CP Observation | Impact |
|---|---|---|---|---|---|
| AF-1 | Preferences stored per notification channel (email, in-app, push) | One preference record per user per channel with `enabled` and `frequency` fields | Stores per-category boolean flags (`marketing_email`, `system_email`) — does not match channel model | JSONB column on `users` table with channel keys — matches spec data model exactly | **High** — Team-CL schema requires full data migration and re-implementation to conform |
| AF-2 | Digest mode: users choose `immediate` or `daily_digest` delivery per channel | `frequency` field on preference record with values: `immediate`, `daily_digest` | Not implemented; `tasks.md` erroneously marks this task complete | Implemented as `frequency` field; UI toggle present and functional | **High** — Team-CL `tasks.md` is misleading about implementation state |
| AF-3 | Unsubscribe link redirects to preferences page with confirmation | One-click unsubscribe updates preference and displays confirmation banner | Link present; redirects correctly; confirmation UI absent | Fully implemented including confirmation banner and flash message | **Medium** — Team-CL is missing the confirmation step only |

---

## Team-CL Review

> `tasks.md` status: **STALE** — Digest mode marked complete at `tasks.md:34` but no digest logic exists in the codebase. Unsubscribe confirmation marked complete at `tasks.md:41` but the confirmation UI is absent. Do not rely on this `tasks.md` for implementation state.

**Pros**
- `UserNotificationFactory` and associated shared examples significantly reduce test setup boilerplate — cherry-pick candidate
- High test line coverage (94%) on changed files
- Clean migration rollback with explicit `down` block

**Cons**
- Per-category boolean schema deviates from spec-mandated per-channel model
- Opt-out logic inverted for in-app channel (F-1)
- Digest mode not implemented despite `tasks.md` claiming it done
- `notification_settings.rb` mixes service and controller responsibilities
- No fallback for users with no preference rows; silent `nil` propagates

---

## Team-CP Review

> `tasks.md` status: **Current** — `tasks.md` accurately reflects implementation state. No discrepancies found.

**Pros**
- Per-channel JSONB model is the correct implementation of the spec data model
- Nil-safe defaults accessor prevents silent failures for accounts without a preference row
- Full digest mode implementation present in both back-end and UI
- Migration backfills all existing users with safe opt-in defaults
- Clean service layer with no controller logic leakage

**Cons**
- Test coverage 82% — missing edge cases for malformed channel values in JSONB (F-2)
- No explicit `down` block in migration (F-3)

---

## Implementation Findings

| ID | Team | Severity | Category | Description | Impact | Evidence |
|---|---|---|---|---|---|---|
| F-1 | Team-CL | **High** | gap | Opt-out logic inverted for in-app notifications | Users who opt out of in-app notifications continue receiving them | `app/services/notification_settings.rb:87` — condition is `unless user.in_app_enabled`; should be `if user.in_app_enabled` |
| F-2 | Team-CP | **Medium** | missing-test | No test coverage for malformed or unknown channel keys in JSONB preferences column | Silent failure if an external system writes an unexpected channel key | `spec/services/notification_preference_service_spec.rb` — no invalid-channel test cases present |
| F-3 | Team-CP | **Low** | debt | Migration `20251118_add_notification_preferences.rb` has no `down` block | Cannot roll back migration cleanly during a production incident | `db/migrate/20251118_add_notification_preferences.rb:14` — `down` method absent |
| F-4 | Team-CL | **High** | spec-drift | Per-category boolean schema deviates from spec-mandated per-channel model | Full breaking data migration required to align with spec; high rollback risk | `db/migrate/20251115_add_notification_booleans.rb` vs `specs/2025-11/notification-preferences/data-model.md:22` |
| F-5 | Team-CL | **High** | gap | `tasks.md` marks digest mode complete; the feature is not implemented | Misleading implementation state means reviewer cannot rely on `tasks.md` | `specs/2025-11/notification-preferences/tasks.md:34` vs absence of digest logic anywhere in the branch |

---

## Cherry-Pick Recommendations

| ID | From | Description | Rationale | Target Files |
|---|---|---|---|---|
| C-1 | Team-CL | Copy `UserNotificationFactory` and the `:notifiable` shared examples into Team-CP | Significantly reduces test setup boilerplate; Team-CP tests are noticeably more verbose without these helpers | `spec/factories/user_notification_factory.rb`, `spec/support/shared_examples/notifiable.rb` |

---

## Remediation Plan

| Step | Description | Priority | Owner |
|---|---|---|---|
| 1 | Add test cases for malformed and unknown JSONB channel keys in `notification_preference_service_spec.rb` (F-2) | **Before merge** | Team-CP |
| 2 | Add explicit `down` block to migration `20251118_add_notification_preferences.rb` (F-3) | **Before merge** | Team-CP |
| 3 | Cherry-pick `UserNotificationFactory` and `:notifiable` shared examples from Team-CL (C-1) | **Before merge** | Team-CP |
| 4 | Verify `tasks.md` is current and accurate before opening the merge request | **Before merge** | Team-CP |

---

## Final Verdict

Team-CP is the correct foundation. The per-channel JSONB model faithfully implements the spec, the migration is safe for production, digest mode is complete, and `tasks.md` is accurate. The two required fixes before merge (missing tests, no rollback block) are low-effort. Team-CL has stronger test infrastructure but an irreconcilably wrong data model — cherry-pick the factories only and discard the rest.
