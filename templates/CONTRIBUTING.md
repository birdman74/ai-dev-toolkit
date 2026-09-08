# Contributing to <REPLACE:project-name>

This document defines the standards and conventions for all work on
<REPLACE:project-name> -- whether authored by a human or an AI persona. All
contributors (the human reviewer, PO, Dev, Test) are expected to follow these
standards. When in doubt, check `docs/adr/` for architectural decisions before
inventing your own pattern.

> Copied from `ai-dev-toolkit/templates/CONTRIBUTING.md`. Replace the
> `<REPLACE:...>` placeholders and delete stack sections that do not apply.

---

## Workflow

### Branch Naming
- Feature branches: `feature/story-NNN-short-kebab-case-description`
- Spec branches: `specs/epic-NNN-short-description`
- No direct commits to `main` -- ever

### Commit Messages
Follow [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | Use |
|---|---|
| `feat(story-NNN):` | New feature implementation |
| `fix(story-NNN):` | Bug fix |
| `test(story-NNN):` | Test additions or changes |
| `docs:` | Documentation only |
| `chore:` | Tooling, config, dependencies |
| `refactor:` | Code change with no behavior change |

### Pull Requests
- The bot account (`<REPLACE:bot-github-username>`) opens all feature PRs
- The human reviewer (`<REPLACE:your-github-username>`) is CODEOWNER -- their
  approval is required before any merge
- CI must pass before merge
- The Test persona must post a test run summary as a PR comment before the
  human reviews

### STATUS.md
Every meaningful commit must include a STATUS.md update in the same commit:
- Update `Last Updated` date to today (YYYY-MM-DD)
- Update story status in the Epics & Stories section
- Note any blockers in Blocked Items

---

## <REPLACE:language/framework> Standards

> The reference stack for this toolkit is Java + Spring Boot. Replace this
> section wholesale if your project uses a different stack.

### Language and Framework
- Java <REPLACE:java-version> (Temurin)
- Spring Boot <REPLACE:spring-boot-version>
- Spring AI for all AI-related integration

### Dependency Injection
- Constructor injection only -- never field injection (`@Autowired` on fields)
- All dependencies declared `final` in constructor-injected classes

### Exception Handling
- No swallowed exceptions -- every `catch` block must log or rethrow
- Domain exceptions extend a common base or are purpose-built
- A `GlobalExceptionHandler` handles all API error responses -- do not return
  error responses directly from controllers

### Database
- All relational schema changes via Flyway migrations
- Migration files named: `V{N}__{description}.sql`
- Never modify an existing migration -- always add a new one
- Use the document store only for flexible/unstructured data -- never for
  relational data

### API Design
- All endpoints require authentication unless explicitly listed in
  `SecurityConfig.permitAll()`
- User identity always resolved from the auth token via
  `@AuthenticationPrincipal` -- never from the request body
- Input validation on all request DTOs using Bean Validation
- HTTP status codes: 200 OK, 201 Created, 400 Bad Request (validation),
  401 Unauthorized, 403 Forbidden, 404 Not Found

### Iteration Variables
Use in this order: `i`, `j`, `k`, `l`

### Credentials
- Never hardcode credentials in committed files
- All secrets via `.env` (gitignored) -- see `.env.example` for required variables

---

## Testing Standards

### Test Naming
```
should_[expected behavior]_when_[condition]
```

### General Test Rules
- All tests must be deterministic -- no random data, no time-dependent
  assertions without mocking
- Tests must clean up after themselves -- no state pollution between tests
- Every acceptance criterion (AC-N) must have at least one test
- Regression tests required for any change to shared infrastructure (security
  config, schema, shared services)

### Acceptance Criteria Coverage
The Test persona maps every test to its AC-N label in the test run summary. Dev
adds unit tests for lower-level concerns not covered by Test's integration tests.

---

## Architecture Decision Records

Before making any non-obvious architectural or testing decision, consult:

```
docs/adr/
```

If your decision is not covered by an existing ADR, flag it to the human
reviewer. New ADRs are created when a decision has significant long-term
consequences and alternatives were considered. Use
`ai-dev-toolkit/templates/adr/ADR-NNN-title.md` as the skeleton.

---

## Line Endings

All files use LF line endings, enforced by `.gitattributes`.

---

## What Belongs Where

| Content type | Location |
|---|---|
| Architectural decisions with alternatives | `docs/adr/` |
| Coding and testing conventions | `CONTRIBUTING.md` (this file) |
| Story requirements and acceptance criteria | `docs/specs/story-NNN-*.md` |
| Design artifacts (test plans, contracts) | `docs/specs/design/` |
| Deferred work and open questions | `docs/specs/backlog.md` |
| Project health and story status | `STATUS.md` |
| Project history and lessons learned | `ai-dev-toolkit/DEVLOG.md` |
