# ai-dev-toolkit

A reusable toolkit for multi-persona Claude Code agentic development workflows — Dockerfiles, compose templates, and launcher scripts for AI-augmented software teams.

## What This Is

This toolkit implements a **spec-driven, multi-persona agentic development workflow** where distinct Claude Code instances act as a Product Owner, Senior Developer, and Senior QA Engineer on a software project. Each persona operates in its own Docker container with a scoped Git identity, scoped filesystem access, and a role-specific system prompt.

The result is a fully auditable, AI-augmented development process where:
- Requirements are defined by a PO agent before any code is written
- Implementation is done by a Dev agent operating strictly within approved specs
- Tests are written and run by a Test agent against the acceptance criteria
- A human architect reviews and approves all work before it merges to main

## Repository Structure

```
ai-dev-toolkit/
|- dockerfiles/
|    |- claude-code/            # Base image (PO persona — lightweight)
|    |- claude-code-dev/        # Dev/Test image (adds Java 25, Maven, gh CLI)
|- personas/
|    |- templates/
|         |- po/CLAUDE.md       # PO persona system prompt template
|         |- dev/CLAUDE.md      # Dev persona system prompt template
|         |- test/CLAUDE.md     # Test persona system prompt template
|- compose/
|    |- claude-persona.yml      # Docker Compose template for any persona
|- scripts/
|    |- launch-persona.sh       # Launcher script template
|- docs/
|    |- how-it-works.md         # Architecture and workflow explanation
|    |- new-project-setup.md    # Step-by-step checklist for new projects
|- README.md
```

## Quick Start

See [docs/new-project-setup.md](docs/new-project-setup.md) for the full setup checklist.

## Docker Images

| Image | Dockerfile | Purpose |
|---|---|---|
| `claude-experience-img` | `dockerfiles/claude-code/Dockerfile` | PO persona — Claude Code + git only |
| `claude-dev-img` | `dockerfiles/claude-code-dev/Dockerfile` | Dev/Test personas — adds Java 25, Maven, gh CLI |

Build the images:
```bash
# Base image (PO)
docker build -t claude-experience-img ./dockerfiles/claude-code

# Dev/Test image
docker build -t claude-dev-img ./dockerfiles/claude-code-dev
```

## The Workflow

```
Human → PO Agent (specs) → Human approves → Dev Agent (implements) → Test Agent (verifies) → Human merges
```

See [docs/how-it-works.md](docs/how-it-works.md) for the full architecture explanation.

## In Use

This toolkit currently powers the [StreamVault](https://github.com/birdman74/streamvault) project — a personal streaming library tracker built as a portfolio demonstration of agentic development practices.

## License

MIT — use freely, adapt for your own projects.