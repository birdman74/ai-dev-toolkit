# ai-dev-toolkit

A reusable toolkit for multi-persona Claude Code agentic development workflows - Dockerfiles, compose templates, launcher scripts, and GitHub Actions orchestration for AI-augmented software teams.

## What This Is

This toolkit implements a **spec-driven, TDD-first, multi-persona agentic development workflow** where distinct Claude Code instances act as a Product Owner, Senior Developer, and Senior QA Engineer on a software project. Each persona operates in its own Docker container with a scoped Git identity, scoped filesystem access, and a role-specific system prompt.

The result is a fully auditable, AI-augmented development process where:
- Requirements are defined by a PO agent before any code is written
- **Test goes first** - API contracts and failing tests are defined before Dev implements anything
- Test and Dev iterate on the design before implementation begins, and settle defective tests directly
- Test or Dev can ask PO about any acceptance criterion; PO answers on the story branch
- Dev implements against the agreed design until all tests pass
- Test performs final verification including regression analysis
- A human architect reviews and approves all work before it merges to main, and is otherwise pulled in only when a loop passes its limit
- GitHub Actions orchestrates the entire chain automatically - no manual persona launching required

## Repository Structure

```
ai-dev-toolkit/
|- dockerfiles/
|    |- claude-base/            # Base image - Claude Code + git only
|    |- claude-po/              # PO image - base + gh CLI (no build tools)
|    |- claude-code-dev/        # Dev/Test image - adds Java 25, Maven, gh CLI
|- personas/
|    |- templates/
|         |- po/CLAUDE.md       # PO persona system prompt template
|         |- dev/CLAUDE.md      # Dev persona system prompt template
|         |- test/CLAUDE.md     # Test persona system prompt template
|- templates/
|    |- CONTRIBUTING.md         # Project conventions template (copied to repo root)
|    |- adr/ADR-NNN-title.md    # Architecture Decision Record skeleton
|    |- pipeline-config.env     # Every pipeline knob (copied to .github/pipeline-config.env)
|- compose/
|    |- claude-persona.yml      # Docker Compose template for any persona
|- scripts/
|    |- launch-persona.sh          # Interactive launcher script template
|    |- launch-persona-auto.sh     # Non-interactive launcher for GitHub Actions
|    |- next-story-template.sh     # Queue manager: next eligible story from GitHub Issues
|    |- transition.sh              # Hand-off registry: routing, state checks, prompts, outcomes
|    |- pipeline-config.sh         # Reads and validates pipeline-config.env
|    |- persona-outcome-check.sh   # GitHub checks used to verify persona results
|    |- escalate-to-brian.sh       # Opens, updates and auto-closes needs-brian issues
|    |- check-prerequisites.sh     # Single rule for "is this story unblocked?"
|    |- sync-blocked-labels.sh     # Keeps 'blocked' labels in step with prerequisites
|    |- sync-project-board.sh      # Moves story issues to the right board column
|- workflows/                      # Copy to .github/workflows/
|    |- persona-run.yml                 # Reusable: launch, verify, escalate, clean up one persona
|    |- pipeline-*.yml                  # Six thin event adapters
|    |- sync-blocked-labels.yml         # Label reconciliation on issue events
|    |- sync-project-board.yml          # Board sync on issue events
|    |- ci.yml                          # Structure validation + backend/frontend build
|- docs/
|    |- how-it-works.md                 # Architecture and workflow explanation
|    |- new-project-setup.md            # Step-by-step checklist for new projects
|    |- agentic-workflow-diagram.md     # Visual Mermaid flowchart of the full automation chain
|- DEVLOG.md                    # Project history, decisions, and lessons learned
|- README.md
```

## Quick Start

See [docs/new-project-setup.md](docs/new-project-setup.md) for the full setup checklist.

## The Workflow

```
PO (spec) -> Test (contracts + failing tests) -> Dev (design review)
-> iteration -> Dev (implements) -> Test (final review + regression)
-> Brian (approves + merges)

Direct loops, no human: design feedback, defective tests (Dev <-> Test),
acceptance-criteria questions (Test or Dev -> PO). Each has a limit; past it, a needs-brian issue.
```

See [docs/agentic-workflow-diagram.md](docs/agentic-workflow-diagram.md) for the full diagram, the hand-off table, escalation paths, and the human's PR review guide.

## GitHub Actions Orchestration

Every hand-off rule lives in `scripts/transition.sh` and every knob in `.github/pipeline-config.env`. Six thin adapter workflows turn GitHub events into a gate job on a GitHub-hosted runner; when a persona is needed, they call the reusable `persona-run.yml` (from `main`) on the self-hosted runner, which launches the persona, verifies its result on GitHub, and escalates if it is missing (ADR-003, ADR-005 in the reference project).

| Adapter | Event | Hand-offs |
|---|---|---|
| `pipeline-main-and-merge.yml` | story spec pushed to main, PR closed | queue, Test Phase 1 |
| `pipeline-feature-push.yml` | push to `feature/story-*` | design loop, implementation, defective-test loop, PO loop, re-verification |
| `pipeline-pr-opened.yml` | bot opens a story PR | Test final review |
| `pipeline-test-verdict.yml` | Test's CHANGES_REQUESTED verdict comment | Dev fix |
| `pipeline-review-submitted.yml` | human requests changes | Test Phase 4 (story PR), PO revision (specs PR) |
| `pipeline-manual.yml` | manual dispatch | any hand-off, for recovery |

### Story queue

Stories are tracked as GitHub Issues labeled `story`. `scripts/next-story-template.sh` (deployed as `scripts/next-story.sh`) returns the lowest-numbered open story whose prerequisites were all closed as completed, enforces a single `in-progress` story at a time, and fails closed on API errors. On PR merge the completed issue is closed and the next eligible story starts automatically.

## Docker Images

| Image | Dockerfile | Purpose |
|---|---|---|
| `claude-base-img` | `dockerfiles/claude-base/Dockerfile` | Base image - Claude Code + git only |
| `claude-po-img` | `dockerfiles/claude-po/Dockerfile` | PO persona - base + gh CLI (no build tools) |
| `claude-dev-img` | `dockerfiles/claude-code-dev/Dockerfile` | Dev/Test personas - adds Java 25, Maven, gh CLI |

Build the images:
```bash
# Base image
docker build -t claude-base-img ./dockerfiles/claude-base

# PO image
docker build -t claude-po-img ./dockerfiles/claude-po

# Dev/Test image
docker build -t claude-dev-img ./dockerfiles/claude-code-dev
```

## In Use

This toolkit currently powers the [StreamVault](https://github.com/birdman74/streamvault) project - a personal streaming library tracker built as a portfolio demonstration of agentic development practices.

## License

MIT - use freely, adapt for your own projects.