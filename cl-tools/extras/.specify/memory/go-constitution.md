<!--
================================================================================
SYNC IMPACT REPORT
================================================================================
Version change: 0.0.0 → 1.0.0 (initial adoption)

Modified principles: N/A (first version)

Added sections:
  - I. Test-Driven Development
  - II. Domain-Driven Design
  - III. Testing Strategy & Quality Gates
  - IV. Observability & Diagnostics
  - V. Code Quality, Performance, and Simplicity
  - Additional Constraints & Standards
  - Development Workflow

Removed sections: N/A

Templates requiring updates:
  ✅ plan-template.md - No changes needed (language-agnostic)
  ✅ spec-template.md - No changes needed (language-agnostic)
  ✅ tasks-template.md - No changes needed (supports phased TDD)

Follow-up TODOs: None
================================================================================
-->

# VLS.Cloud Go Services Constitution

## Core Principles

### I. Test-Driven Development (NON-NEGOTIABLE)

TDD MUST be strictly followed using the Red-Green-Refactor cycle.

- ALWAYS write tests FIRST before any implementation code.
- Tests MUST fail initially (Red phase) to prove they test something real.
- Write the minimum code to make tests pass (Green phase).
- Refactor while keeping tests green (Refactor phase).
- NO implementation code is written until corresponding tests exist and fail.
- When a phase produces only tests (Red phase), committing with failing
  tests is ALLOWED and expected.
- Tests live alongside the code they test in the same package
  (`_test.go` files) following Go convention.

**Rationale:** TDD ensures correctness, prevents regressions, and produces
living documentation.

### II. Domain-Driven Design

DDD MUST be used to model the business domain.

- Identify and model Bounded Contexts to separate distinct business domains.
- Use Ubiquitous Language consistently across code, tests, and
  documentation.
- Implement Aggregates to enforce business invariants and transactional
  boundaries.
- Domain models MUST reflect business rules, not technical concerns.
- Prefer rich domain types over primitive types and anemic data structures;
  use Go's type system (custom types, methods on types) to encode domain
  semantics.

**Rationale:** DDD aligns structure with business reality and keeps business
logic explicit.

### III. Testing Strategy & Quality Gates

Testing is mandatory at unit and integration levels.

- Unit tests MUST use the standard `testing` package.
- Table-driven tests MUST be the default pattern for parameterised cases.
- The `testify` package (`require` and `assert`) SHOULD be used for
  expressive assertions.
- Integration tests MUST validate real interactions and external
  dependencies.
- Prefer `testcontainers-go` for real dependencies (databases, message
  queues, etc.).
- Avoid mocking for integration tests when feasible; use interfaces and
  test doubles ONLY when testing external APIs/services beyond control or
  for unit tests.
- Tests MUST cover success paths, error paths, and edge cases.
- Test files MUST be named `*_test.go` and placed in the same package.
- Integration tests MUST use build tags (`//go:build integration`) to
  separate them from unit tests.

Quality Gates (enforced at commit and review):

- All tests MUST pass (unit + integration) for implementation phases
  (Green/Refactor).
- Red-phase commits (tests only, no implementation yet) MAY have failing
  tests—this is expected TDD behavior.
- Code MUST compile with zero errors and zero `golangci-lint` warnings.
- Code MUST pass `go vet` and `staticcheck` with no findings.
- All code MUST be formatted with `gofmt` (or `goimports`).
- Structured logging MUST be present for key operations.
- Each commit MUST independently build; tests MUST pass except for
  intentional Red-phase commits.

### IV. Observability & Diagnostics

All significant operations MUST be observable in a production-safe way.

- Structured logging MUST be implemented using `slog` (standard library
  `log/slog`) or `zerolog`; log output MUST be JSON in production.
- Use `slog.With()` or equivalent to attach contextual fields (not
  `fmt.Sprintf` string interpolation in log messages).
- Correlation IDs MUST be carried through all layers via `context.Context`.
- Distributed tracing MUST use OpenTelemetry exclusively
  (`go.opentelemetry.io/otel`).
- Services MUST expose health endpoints (`/health`, `/ready`).
- Metrics MUST be collected for key operations (rates, durations, errors)
  via Prometheus-compatible exposition or OpenTelemetry metrics.
- Sensitive data (PII, secrets) MUST NOT be logged.
- Configuration MUST follow the 12-factor approach: environment variables
  as the primary source, with optional config files parsed via `viper` or
  similar.

### V. Code Quality, Performance, and Simplicity

Engineering discipline is enforced via conventions, linters, and measurable
targets.

- Code MUST follow Effective Go conventions and idiomatic Go style.
- All formatting MUST be handled by `gofmt`; no manual formatting rules.
- Naming conventions per Effective Go:
  - `MixedCaps` / `mixedCaps` — no underscores in names.
  - Exported names start with an uppercase letter; unexported with
    lowercase.
  - Getters are named `Owner()`, not `GetOwner()`; setters `SetOwner()`.
  - One-method interfaces use `-er` suffix (`Reader`, `Writer`, `Handler`).
  - Package names are short, lowercase, single-word; avoid stuttering
    (e.g., `http.Server`, not `http.HTTPServer`).
- Errors MUST be returned as values (`error` interface), not panics.
  `panic` is reserved for truly unrecoverable programmer errors.
- Errors MUST be wrapped with `fmt.Errorf("context: %w", err)` to preserve
  the error chain and enable `errors.Is` / `errors.As`.
- Accept interfaces, return structs.
- Do NOT create interfaces when only a single implementation exists unless
  needed for testing.
- Comments MUST follow Go doc conventions: exported symbols MUST have a
  doc comment starting with the symbol name. Internal code comments MUST
  be minimal; prefer clear, self-documenting naming over comments.
- Single Responsibility Principle MUST be applied; separate
  responsibilities into distinct packages.
- Cross-cutting concerns MUST use middleware (Echo middleware for HTTP,
  context-based propagation for internal layers).
- Avoid over-engineering; YAGNI applies.
- Dependency injection preferred via constructor functions (`NewXxx`)
  accepting interfaces; avoid service-locator or global registries.
- Database queries MUST be profiled; N+1 queries are not acceptable.
- Complexity limits: cyclomatic complexity ≤ 15 per function
  (enforced via `gocyclo`); function length ≤ 50 lines (exceptions
  require justification).
- Performance targets MUST be defined and met for features:
  - Simple query (by CVE ID): < 50ms p95
  - Filtered search (indexed fields): < 200ms p95
  - Complex search (regex/text): < 2s p95
  - Aggregation statistics: < 5s p95
  - Query timeout: 30s hard limit with graceful timeout via
    `context.WithTimeout`
- Memory allocations MUST be minimized in hot paths; prefer slices with
  pre-allocated capacity, `sync.Pool` for short-lived objects, and avoid
  unnecessary heap escapes.
- Goroutines MUST be used for concurrent I/O; blocking calls in
  goroutine-safe code MUST use channels or `sync` primitives for
  coordination.
- Goroutine leaks MUST be prevented: every goroutine MUST have a clear
  termination path (cancellable context, done channel, or bounded
  lifetime).

**Rationale:** Maintainability, reliability, and incident-response speed are
features.

## Additional Constraints & Standards

### User Experience Consistency (MCP Tools)

MCP tools MUST provide predictable, well-documented interfaces for AI
consumers.

- Inputs MUST validate against JSON Schema; validation errors MUST use
  RFC 7807 Problem Details.
- Responses MUST be consistent and AI-friendly; flatten nested documents
  when returning MongoDB data.
- Error responses MUST include `code`, `message`, and `details` and MUST
  NOT expose stack traces.
- List operations MUST support `limit` and `offset`
  (default `limit=10`, max `100`).
- Sorting MUST be documented; prefer indexed fields.
- Configuration MUST follow 12-factor patterns (environment variables,
  optional config files).
- Distinguish user-facing messages (console) from diagnostic logs
  (structured logging).

### Modern Technology Stack

- Projects MUST target Go 1.23 or above.
- Multi-module repositories MUST use Go workspaces (`go.work`) for local
  development and separate `go.mod` per deployable service/shared library.
- HTTP APIs MUST use the Echo framework (`github.com/labstack/echo/v4`)
  as the primary HTTP platform.
- Echo middleware MUST be used for cross-cutting concerns: logging,
  recovery, request ID, CORS, and authentication.
- JSON encoding/decoding MUST use `encoding/json` from the standard
  library (or `json/v2` when stable).
- Containerization MUST use official Go images
  (`golang:1.23` for build, `gcr.io/distroless/static-debian12` or
  `alpine` for runtime).
- CI/CD pipelines MUST use GitLab CI/CD.
- Infrastructure MUST be managed as code (Terraform or Terragrunt)
  targeting Google Cloud Platform.

### Security & Compliance

- All user input MUST be validated and sanitized at the Echo handler
  layer using binding and validation
  (`echo.Context.Bind` + `go-playground/validator`).
- Secrets MUST be stored in GitLab CI/CD variables or Google Cloud
  Secret Manager (never in code or config files committed to VCS).
- Authentication MUST use modern protocols
  (OAuth 2.0 / OIDC / JWT).
- Authorization MUST follow least privilege (RBAC or policy-based
  authorization).
- SQL/NoSQL injection MUST be prevented by using parameterised queries
  or the official MongoDB Go driver's BSON builders.

## Development Workflow

### Branch Strategy

- Use trunk-based development.
- Branch naming MUST follow `{nnn}-{short-name}` (3-digit, lowercase,
  hyphens only).

### Commit Strategy

- Every completed phase MUST end with a git commit—no exceptions.
- One commit per completed phase (from `tasks.md`).
- Commits MUST be small and atomic; each commit MUST build.
- For Red-phase commits (tests written, implementation pending), failing
  tests are expected and allowed.
- For Green/Refactor-phase commits, all tests MUST pass.
- Commit messages MUST NOT use conventional-commit prefixes and MUST NOT
  include AI branding.
- If a task ID applies, the subject MUST start with `T###: `.

### Definition of Done

A feature is not complete until:

- Unit + integration tests pass.
- Performance targets are met (per this constitution).
- Observability is implemented (logging, tracing, metrics) without
  leaking secrets.
- `golangci-lint run` reports zero issues.
- Documentation is updated when behavior/contracts change.

## Governance

This constitution supersedes all other development practices for the
VLS.Cloud Go services. All code reviews and merge requests MUST verify
compliance with these principles.

**Version**: 1.0.0 | **Ratified**: 2026-02-10 | **Last Amended**: 2026-02-10
