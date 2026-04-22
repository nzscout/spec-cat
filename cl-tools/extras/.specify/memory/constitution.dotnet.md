<!--
Sync Impact Report
- Version change: 1.1.0 -> 1.1.1
- Modified principles:
  - V. Code Quality, Performance, and Simplicity (Cross-Stack) -> V. Code Quality, Performance, and Simplicity (Cross-Stack) with explicit naming conventions
- Added sections:
  - None
- Restored constraints:
  - Explicit .NET and Go naming conventions under Principle V
- Removed sections:
  - None
- Templates requiring updates:
  - ✅ no additional updates required in .specify/templates/plan-template.md
  - ✅ no additional updates required in .specify/templates/spec-template.md
  - ✅ no additional updates required in .specify/templates/tasks-template.md
  - ✅ no files present: .specify/templates/commands/
- Follow-up TODOs:
  - None
-->

# VLS.Cloud Constitution

## Core Principles

### I. Test-Driven Development (NON-NEGOTIABLE)

TDD MUST be followed using Red-Green-Refactor for all production changes.

- Tests MUST be authored before implementation code for the same behavior.
- Tests MUST fail first in Red phase to prove coverage is meaningful.
- Red-phase commits that contain only tests MAY fail and are allowed.
- .NET tests MUST be implemented with xUnit in test projects under `tests/dotnet/`.
- Go tests MUST be implemented as `*_test.go` files in the target package.
- Each feature MUST include unit and integration coverage for impacted behavior.

**Rationale:** Test-first delivery reduces regressions and keeps requirements
executable.

### II. Domain-Driven Design

DDD MUST be used to model business capabilities and boundaries.

- Bounded Contexts MUST separate distinct business domains.
- Ubiquitous Language MUST be consistent across code, tests, and documentation.
- Aggregates MUST enforce business invariants and transactional boundaries.
- Domain models MUST represent business rules, not framework mechanics.
- Domain semantics MUST be encoded in types:
  - .NET: value objects/records/domain types where appropriate.
  - Go: custom types with methods instead of primitive-only models.

**Rationale:** DDD keeps design aligned with business intent and limits accidental
complexity.

### III. Testing Strategy & Quality Gates (Multi-Stack)

Testing standards:

- .NET unit tests MUST use xUnit; Shouldly SHOULD be used for expressive
  assertions.
- Go unit tests MUST use `testing`; table-driven tests MUST be the default for
  parameterized behavior; `testify` SHOULD be used for expressive assertions.
- Integration tests MUST validate real interactions with external dependencies.
- Containerized dependencies are preferred:
  - .NET: prefer Testcontainers.
  - Go: prefer `testcontainers-go`.
- Go integration tests MUST be isolated with build tags
  (`//go:build integration`).
- Tests MUST cover success paths, error paths, and edge cases.

Quality gates (enforced at commit, merge request, and pipeline):

- .NET changes MUST pass `dotnet build` with zero warnings and pass all relevant
  tests.
- Go changes MUST pass `go test ./...`, `go vet ./...`, `staticcheck ./...`,
  `golangci-lint run`, and formatting checks (`gofmt`/`goimports` clean).
- Cross-stack changes MUST pass all applicable .NET and Go gates.
- Each commit MUST independently build; tests MUST pass except intentional
  Red-phase test-only commits.
- Required GitLab pipeline jobs MUST pass before merge or deployment.

### IV. Observability & Diagnostics (Cross-Stack)

All significant operations MUST be production-observable without exposing
sensitive data.

- Structured logging MUST be used:
  - .NET: Serilog with structured message templates.
  - Go: `slog` or `zerolog`; JSON log output in production.
- Correlation IDs MUST be propagated through request boundaries and internal
  layers.
- Distributed tracing MUST use OpenTelemetry exclusively.
- Services MUST expose `/health` and `/ready` endpoints.
- Metrics MUST be captured for request rate, latency, error rate, and critical
  domain operations.
- Secrets and PII MUST NOT be logged.
- Configuration MUST follow stack conventions:
  - .NET: `appsettings.*`, environment variables, and user secrets for local dev.
  - Go: environment variables as primary source; optional config files allowed.

### V. Code Quality, Performance, and Simplicity (Cross-Stack)

Engineering discipline is enforced via conventions, analyzers, and measurable
targets.

- Code MUST follow SOLID, KISS, DRY, and YAGNI.
- Naming conventions MUST be explicit and enforced:
  - .NET: PascalCase for public members/types, camelCase for private fields,
    UPPER_CASE for constants, and `I*` prefix for interfaces.
  - Go: Effective Go naming (`MixedCaps`/`mixedCaps`, no underscores),
    exported identifiers start uppercase, unexported start lowercase,
    package names are short lowercase single words, getters avoid `Get*`.
- Interface-first abstraction without a concrete need is prohibited:
  interfaces MAY be added for testing boundaries or multiple implementations.
- Single Responsibility Principle MUST be enforced at class/type/package level.
- Cross-cutting concerns MUST be implemented through middleware or dedicated
  infrastructure layers.
- Query performance MUST be profiled; N+1 query patterns are prohibited.
- Complexity limits MUST be respected:
  - .NET: cyclomatic complexity <= 10 per method.
  - Go: cyclomatic complexity <= 15 per function.
  - Both stacks: method/function length <= 50 lines unless justified in review.
- Concurrency MUST be non-blocking and cancellable for I/O operations:
  - .NET: `async`/`await`; no `.Result`/`.Wait()` in request paths.
  - Go: context-aware goroutines with explicit termination paths.

**Rationale:** Simplicity and observability are mandatory for reliable operation
at scale.

## Additional Constraints & Standards

### User Experience Consistency (MCP Tools)

MCP tools MUST provide predictable, machine-readable contracts.

- Inputs MUST validate against JSON Schema; validation failures MUST use RFC
  7807 Problem Details.
- Error responses MUST include `code`, `message`, and `details`, and MUST NOT
  expose stack traces.
- List operations MUST support `limit` and `offset` (default `limit=10`,
  maximum `100`).
- Sorting behavior MUST be deterministic and documented.
- Responses MUST be consistent across .NET and Go implementations when a tool
  is ported.
- User-facing output and diagnostic logs MUST remain separated.

### Modern Technology Stack

- .NET services MUST target .NET 10 or later.
- Go services MUST target Go 1.23 or later.
- .NET multi-project solutions MUST use Central Package Management
  (`Directory.Packages.props`).
- Go multi-module repositories MUST use `go.work` with separate `go.mod` per
  deployable unit/shared module.
- New HTTP APIs MUST use stack defaults:
  - .NET: Minimal APIs preferred unless a different approach is justified.
  - Go: Echo framework (`github.com/labstack/echo/v4`) is required.
- Container images MUST be built from official base images.
- CI/CD MUST run through GitLab CI/CD for build, test, lint, security scan,
  image publication, and deployment.
- Deployments to shared environments MUST be triggered only from successful
  GitLab pipeline jobs.
- Infrastructure MUST be managed as code (Terraform or Terragrunt) targeting
  Google Cloud Platform.

### Security & Compliance

- All input MUST be validated and sanitized at system boundaries.
- Secrets MUST be stored in GitLab CI/CD variables or Google Cloud Secret
  Manager; secrets in source control are prohibited.
- Authentication MUST use standards protocols and libraries.
- Authorization MUST enforce least privilege (RBAC or policy-based controls).
- Injection risks MUST be mitigated by parameterized queries or safe query
  builders.

## Development Workflow

### Branch Strategy

- Trunk-based development is required.
- Branch names may follow Git Flow mode naming `feature/{short-name}` or `{short-name}` or `{nnn}-{short-name}`

### Commit Strategy

- One commit per completed phase (from `tasks.md`) is required.
- Commits MUST be small, atomic, and independently buildable.
- Commit messages MUST NOT use conventional-commit prefixes and MUST NOT
  include AI branding.
- If a task ID applies, the commit subject MUST begin with `T###: `.
- Green/Refactor commits MUST have passing tests.
- Red-phase test-only commits MAY fail tests and MUST be clearly identified in
  the commit message body.

### Merge Request & Pipeline Strategy

- Every merge request MUST include a constitution compliance check.
- Every merge request MUST reference a successful GitLab pipeline run for
  required jobs.
- A merge request with failing required pipeline jobs MUST NOT be merged.
- Shared-environment deployments MUST be executed by GitLab pipeline jobs;
  ad-hoc manual deployments are prohibited except incident response, which
  requires a post-incident record.

### Definition of Done

A feature is complete only when:

- Unit and integration tests pass for every impacted stack.
- Applicable quality gates pass (.NET and/or Go).
- GitLab required pipeline jobs pass for the merge request.
- Observability requirements are implemented (logs, traces, metrics) without
  leaking secrets.
- Performance targets are met where applicable.
- Documentation is updated when contracts or behavior change.

## Governance

This constitution supersedes all other development practices in this repository.

Amendment process:

1. Propose a change with rationale and impact assessment.
2. Classify the change as MAJOR, MINOR, or PATCH.
3. Update this document and prepend a new Sync Impact Report.
4. Update dependent templates and runtime guidance to remain consistent.
5. Obtain reviewer approval that explicitly confirms constitution compliance.

Versioning policy:

- MAJOR: Backward-incompatible governance change or principle
  removal/redefinition.
- MINOR: New principle/section, or materially expanded constraints.
- PATCH: Clarifications, wording fixes, and non-semantic refinements.

Compliance review expectations:

- Every merge request review MUST verify constitution compliance.
- Violations MUST be explicitly documented with rationale and reviewer approval.
- Repository maintainers MUST perform a governance consistency review at least
  once per release milestone.

**Version**: 1.1.1 | **Ratified**: 2025-12-16 | **Last Amended**: 2026-02-11
