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
|    |- claude-code/            # Base image (PO persona — lightweight)
|    |- claude-code-dev/        # Dev/Test image (adds Java 25, Maven, gh CLI)
|    |- claude-po/              # PO image (adds gh CLI)
|- personas/
|    |- templates/
|         |- po/CLAUDE.md       # PO persona system prompt template
|         |- dev/CLAUDE.md      # Dev persona system prompt template
|         |- test/CLAUDE.md     # Test persona system prompt template
|- compose/
|    |- claude-persona.yml      # Docker Compose template for any persona
|- scripts/
|    |- launch-persona.sh       # Interactive launcher script template
|    |- launch-persona-auto.sh  # Non-interactive launcher for GitHub Actions
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

The workflow is automated via six trigger workflows running on a self-hosted runner:

| Trigger | Event | Wakes |
|---|---|---|
| `trigger-test-on-spec.yml` | PO commits story spec to main | Test (Phase 1) |
| `trigger-dev-review.yml` | Test commits test plan or revision | Dev (design review) |
| `trigger-test-revision.yml` | Dev commits feedback | Test (revision) |
| `trigger-dev-implement.yml` | Dev commits agreed.md | Dev (implementation) |
| `trigger-test-final-review.yml` | Bot opens PR | Test (final review) |
| `trigger-on-changes-requested.yml` | Changes Requested review submitted | Test or Dev (feedback loop) |

Every trigger supports `workflow_dispatch` for manual override from the GitHub Actions tab.

## Docker Images

| Image | Dockerfile | Purpose |
|---|---|---|
| `claude-base-img` | `dockerfiles/claude-base/Dockerfile` | Base image - Claude Code + git only |
| `claude-po-img` | `dockerfiles/claude-po/Dockerfile` | PO persona - Claude Code + git + gh CLI |
| `claude-dev-img` | `dockerfiles/claude-code-dev/Dockerfile` | Dev/Test personas - adds Java 25, Maven, gh CLI |

Build the images:
```bash
# PO image
docker build -t claude-po-img ./dockerfiles/claude-code

# Dev/Test image
docker build -t claude-dev-img ./dockerfiles/claude-code-dev
```

## In Use

This toolkit currently powers the [StreamVault](https://github.com/birdman74/streamvault) project — a personal streaming library tracker built as a portfolio demonstration of agentic development practices.

## License

MIT — use freely, adapt for your own projects.