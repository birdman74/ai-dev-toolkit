# ai-dev-toolkit

A reusable toolkit for multi-persona Claude Code agentic development workflows — Dockerfiles, compose templates, launcher scripts, and GitHub Actions orchestration for AI-augmented software teams.

## What This Is

This toolkit implements a **spec-driven, TDD-first, multi-persona agentic development workflow** where distinct Claude Code instances act as a Product Owner, Senior Developer, and Senior QA Engineer on a software project. Each persona operates in its own Docker container with a scoped Git identity, scoped filesystem access, and a role-specific system prompt.

The result is a fully auditable, AI-augmented development process where:
- Requirements are defined by a PO agent before any code is written
- **Test goes first** — API contracts and failing tests are defined before Dev implements anything
- Test and Dev iterate on the design before implementation begins
- Dev implements against the agreed design until all tests pass
- Test performs final verification including regression analysis
- A human architect reviews and approves all work before it merges to main
- GitHub Actions orchestrates the entire chain automatically — no manual persona launching required

## Repository Structure

```
ai-dev-toolkit/
|- dockerfiles/
|    |- claude-base/            # Base image — Claude Code + git only
|    |- claude-po/              # PO image — base + gh CLI (no build tools)
|    |- claude-code-dev/        # Dev/Test image — adds Java 25, Maven, gh CLI
|- personas/
|    |- templates/
|         |- po/CLAUDE.md       # PO persona system prompt template
|         |- dev/CLAUDE.md      # Dev persona system prompt template
|         |- test/CLAUDE.md     # Test persona system prompt template
|- compose/
|    |- claude-persona.yml      # Docker Compose template for any persona
|- scripts/
|    |- launch-persona.sh          # Interactive launcher script template
|    |- launch-persona-auto.sh     # Non-interactive launcher for GitHub Actions
|    |- next-story-template.sh     # Queue manager — next eligible story from GitHub Issues
|- workflows/
|    |- ci.yml                          # Structure validation + backend/frontend build
|    |- trigger-*.yml                   # Persona orchestration triggers (copy to .github/workflows/)
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
PO (spec) → Test (contracts + failing tests) → Dev (design review) 
→ iteration → Dev (implements) → Test (final review + regression) 
→ Brian (approves + merges)
```

See [docs/agentic-workflow-diagram.md](docs/agentic-workflow-diagram.md) for the full visual automation diagram including all GitHub Actions triggers, iteration loops, escalation paths, and the Changes Requested feedback loop.

## GitHub Actions Orchestration

The workflow is automated via nine trigger workflows plus `ci.yml`, running on a self-hosted runner. Templates live in `workflows/` — copy them to `.github/workflows/` and fill the placeholders.

| Trigger | Event | Wakes |
|---|---|---|
| `trigger-test-next-story.yml` | story spec pushed to main, or any PR merged | Test — Phase 1 (via queue manager) |
| `trigger-dev-review.yml` | Test pushes test plan or revision | Dev — design review |
| `trigger-test-revision.yml` | Dev pushes `dev-feedback-rN.md` | Test — revision |
| `trigger-dev-implement.yml` | Dev pushes `story-NNN-agreed.md` | Dev — implementation |
| `trigger-test-final-review.yml` | bot opens a PR targeting main | Test — final review |
| `trigger-on-changes-requested.yml` | human submits a Changes Requested review | Test — write failing tests |
| `trigger-dev-on-test-commit.yml` | Test pushes to `src/test/**` while PR is `changes_requested` | Dev — fix |
| `trigger-test-on-dev-fix.yml` | Dev pushes to an open PR branch | Test — re-verification |
| `trigger-po-on-changes-requested.yml` | human requests changes on a `specs/` PR | PO — revise specs |

Every trigger supports `workflow_dispatch` for manual override from the GitHub Actions tab.

### Story queue

Stories are tracked as GitHub Issues labeled `story`. `scripts/next-story-template.sh` (deployed as `scripts/next-story.sh`) returns the lowest-numbered open story whose prerequisites are all closed, enforces a single `in-progress` story at a time, and is run by `trigger-test-next-story.yml`. On PR merge the completed issue is closed and the next eligible story starts automatically.

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

This toolkit currently powers the [StreamVault](https://github.com/birdman74/streamvault) project — a personal streaming library tracker built as a portfolio demonstration of agentic development practices.

## License

MIT — use freely, adapt for your own projects.