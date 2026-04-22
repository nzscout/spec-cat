# Code Comparison Report — API Rate Limiting

> **Rendered from:** `speckat.compare-code.example-2.yaml`  
> **Reviewed by LLM:** gemini-2.5-pro  
> **Generated:** 2026-04-08T11:42:00Z

---

## Executive Summary

**Recommended foundation: Hybrid — Team-CL base with cherry-picks from Team-CP**

Team-CL is the recommended base. Its Redis-backed sliding window implementation is the only one that satisfies the horizontal scaling requirement in the PRD and the security requirement for consistent enforcement across instances. Team-CP's in-memory approach cannot enforce limits when the application runs on multiple nodes. Three items from Team-CP should be cherry-picked before merge: the structured 429 error response body, rate limit headers on all responses, and the cleaner middleware composition pattern.

---

## Scope And Inputs

| Item | Value |
|---|---|
| Team-CL Feature Path | `specs/2026-01/api-rate-limiting` |
| Team-CP Feature Path | `specs/2026-01/api-rate-limiting` |
| Canonical Base Branch | `main` |
| Product Documents | `docs/product/api-platform-prd.md`, `docs/product/security-requirements.md` |

---

## Comparison Matrix

| Criterion | Team-CL | Team-CP |
|---|---|---|
| PRD Alignment | **High** — Redis sliding window satisfies the multi-node enforcement requirement. | **Low** — In-memory counter fails the PRD's multi-instance consistency requirement. |
| Speckit Alignment | **High** — All spec scenarios implemented; tasks.md accurate. | **Medium** — Admin override feature missing entirely; tasks.md overstates completion. |
| Correctness | **High** — Sliding window correctly handles burst and sustained load scenarios. | **Medium** — Counter resets on process restart — silent correctness failure under multi-node load (F-1). |
| Completeness | **High** — All acceptance criteria covered; admin override API endpoint present. | **Medium** — Admin override feature entirely missing (F-2). |
| Code Quality | **Medium** — `RateLimiter` class has too many responsibilities at 280 lines (F-3). | **High** — Clean middleware composition; each concern isolated in its own class. |
| Tests | **High** — Redis integration tests with mock time; 91% coverage on changed files. | **High** — Thorough unit tests; well-structured with good edge case coverage; 89% coverage. |
| Simplicity | **Medium** — Redis dependency adds operational overhead. | **High** — Simpler code but built on the wrong backing store for the deployment model. |
| Robustness | **High** — Redis failure falls back to allow-all mode with alerting; no silent data loss. | **Low** — No failure mode defined; counter inconsistency across nodes is undetected. |
| Operational Readiness | **High** — Rate limit headers, Prometheus metrics, and on-call runbook all included. | **Medium** — Headers present but no metrics or runbook. |
| Merge Risk | **Medium** — Redis dependency requires infrastructure provisioning before first deploy. | **High** — Incorrect multi-node behavior is an invisible production correctness risk. |
| Overall Quality | **High** | **Medium** |

---

## Alignment Findings

| ID | Requirement | Expected | Team-CL Observation | Team-CP Observation | Impact |
|---|---|---|---|---|---|
| AF-1 | Rate limits enforced consistently across all application instances | Shared backing store ensures per-user counters are instance-independent | Redis-backed; counters shared across all nodes — matches requirement | In-process counter; each node maintains independent state — violates requirement | **Critical** — Team-CP allows up to N×limit requests on an N-node deployment |
| AF-2 | Admins can override rate limits per API key without a deployment | Admin UI with per-key limit override stored in DB, read at request time | Override API endpoint implemented; admin UI not yet present but API is complete | Neither UI nor API implemented; `tasks.md` marks the entire feature done | **Medium** — Team-CL is missing UI only; Team-CP is missing the feature entirely |
| AF-3 | Rate limit headers returned on every API response | `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` on every response | Headers injected on 429 responses only — missing on non-limited responses (F-4) | Headers present on all responses with correct remaining and reset values | **Medium** — clients cannot pre-emptively throttle without per-request headers |

---

## Team-CL Review

> `tasks.md` status: **Current** — `tasks.md` accurately reflects implementation state including the known admin UI gap, which is explicitly marked as out-of-scope for this iteration.

**Pros**
- Redis sliding window is the only correct solution for multi-node deployment
- Graceful Redis failure with allow-all fallback and alerting prevents silent outages
- Prometheus metrics for limit hit rate and Redis latency
- On-call runbook included covering Redis failure and limit tuning procedures
- High test coverage (91%) with mock time for deterministic sliding window scenarios

**Cons**
- `RateLimiter` class is 280 lines handling too many distinct concerns (F-3)
- Rate limit headers absent on non-limited responses (AF-3, F-4)
- Admin UI not implemented — override API endpoint only

---

## Team-CP Review

> `tasks.md` status: **STALE** — Admin override feature marked complete at `tasks.md:41` but neither the API endpoint nor the UI was implemented. Do not rely on this `tasks.md` for implementation state regarding the admin override work.

**Pros**
- Clean middleware composition with each concern in its own class — cherry-pick candidate
- Rate limit headers on every response with correct values — cherry-pick candidate
- Structured 429 error response body with `retry_after` and `policy_url` — cherry-pick candidate
- Thorough unit tests with well-organized edge case coverage

**Cons**
- In-memory counter fails multi-node consistency requirement — disqualifying for production
- No failure mode defined for counter inconsistency; no fallback behavior
- No Prometheus metrics or structured logging for rate limit events
- Admin override feature entirely missing despite `tasks.md` claiming completion

---

## Implementation Findings

| ID | Team | Severity | Category | Description | Impact | Evidence |
|---|---|---|---|---|---|---|
| F-1 | Team-CP | **Critical** | gap | In-memory rate limit counter resets on process restart and is not shared across nodes | Rate limits silently unenforced in multi-node production environment; up to N×limit per user on N nodes | `lib/middleware/rate_limiter.rb:12` — `@counters = {}` initialized per-process in constructor with no persistence |
| F-2 | Team-CP | **High** | gap | Admin limit override feature entirely absent; `tasks.md` incorrectly marks it complete | Operators cannot adjust limits per API key without a code deployment | `specs/2026-01/api-rate-limiting/tasks.md:41` vs absence of override routes in `config/routes.rb` and admin controllers |
| F-3 | Team-CL | **Medium** | anti-pattern | `RateLimiter` class handles counter logic, header injection, Redis fallback, Prometheus metrics, and key generation in a single 280-line class | Testing and extending any single concern requires modifying a high-risk central class | `lib/rate_limiter.rb:1-280` — six distinct concerns identified with no internal separation |
| F-4 | Team-CL | **Medium** | gap | Rate limit headers only injected on 429 responses; absent on all successful responses | Well-behaved clients cannot read remaining quota to self-throttle proactively | `lib/rate_limiter.rb:198` — header injection inside `if rate_limited?` guard block only |
| F-5 | Team-CP | **Medium** | gap | No Prometheus metrics or structured logging for rate limit events | No alerting baseline; blind to limit hit rate in production from day one | `lib/middleware/rate_limiter.rb` — no metrics calls; no structured log statements throughout |

---

## Cherry-Pick Recommendations

| ID | From | Description | Rationale | Target Files |
|---|---|---|---|---|
| C-1 | Team-CP | Replace Team-CL plain-string 429 response body with Team-CP's structured body including `retry_after` and `policy_url` fields | Better client developer experience; aligns with the API error response conventions used across the rest of the codebase | `lib/rate_limiter.rb` (error response construction block) |
| C-2 | Team-CP | Apply Team-CP rate limit header injection to all responses, not just 429s | Directly fixes AF-3 and F-4; Team-CP already has the correct Rack middleware placement for unconditional header injection | `lib/rate_limiter.rb` (header injection logic) |
| C-3 | Team-CP | Adopt Team-CP's middleware composition pattern to decompose `RateLimiter` into focused single-responsibility classes | Addresses F-3; Team-CP's separation makes each concern independently testable and extensible | `lib/middleware/rate_limit_counter.rb`, `lib/middleware/rate_limit_headers.rb`, `lib/middleware/rate_limit_enforcer.rb` |

---

## Remediation Plan

| Step | Description | Priority | Owner |
|---|---|---|---|
| 1 | Cherry-pick Team-CP structured 429 error body (C-1) | **Before merge** | Team-CL |
| 2 | Cherry-pick Team-CP rate limit headers on all responses to fix AF-3 and F-4 (C-2) | **Before merge** | Team-CL |
| 3 | Provision Redis instance in staging and production environments | **Before merge** | Platform |
| 4 | Update `tasks.md` to accurately reflect admin UI as out-of-scope for this iteration | **Before merge** | Team-CL |
| 5 | Refactor `RateLimiter` using Team-CP middleware composition pattern (C-3) to address F-3 | **After merge** | Team-CL |
| 6 | Implement admin override UI — the API endpoint already exists in Team-CL | **After merge** | Team-CL |

---

## Final Verdict

Team-CL is the only viable base because its Redis-backed sliding window is the only implementation that satisfies the non-negotiable multi-instance consistency requirement. Team-CP's cleaner code structure is the right architectural direction but is built on the wrong backing store. Cherry-pick the three items before merge to get the best of both implementations. Redis provisioning is the one hard infrastructure dependency that must be tracked on the platform side before the first production deployment.
