# How It Works

This toolkit implements a **multi-persona agentic development workflow** using Claude Code Docker containers. Each persona is a separate container with a scoped identity, a scoped filesystem view, and a persona-specific `CLAUDE.md` system prompt that defines its role and responsibilities.

## The Three Personas

| Persona | Role | Image | Commits As |
|---|---|---|---|
| PO | Product Owner — defines epics and user stories | `claude-po-img` | `claude-<project>-po` |
| Dev | Senior Developer — implements against stories | `claude-dev-img` | `claude-<project>-dev` |
| Test | Senior QA Engineer — writes and runs tests | `claude-dev-img` | `claude-<project>-test` |

## The Workflow

```
Human (Architect / Reviewer)
        |
        v
  PO Persona
  - Interviews human for requirements
  - Writes epics and user stories to docs/specs/
  - Commits specs, updates STATUS.md
        |
        v
  Human reviews and approves specs
        |
        v
  Dev Persona
  - Reads approved story
  - Implements on a feature branch
  - Writes unit tests alongside implementation
  - Opens PR, updates STATUS.md
        |
        v
  Test Persona
  - Reads story and implementation
  - Writes and runs integration/e2e tests
  - Posts test summary as PR comment
  - Updates STATUS.md
        |
        v
  Human reviews PR and merges to main
```

## Security Model

- Each persona container runs as a non-root user
- Each project gets a scoped SSH deploy key — personas can push branches but cannot merge to main
- GitHub fine-grained PAT is scoped to PR read/write and comment write only — no merge capability
- Each persona only mounts the directories it needs — no access to unrelated projects
- Credentials live in `.env` files (gitignored) — never hardcoded in committed files

## CLAUDE.md Hierarchy

Claude Code reads two CLAUDE.md files on startup and merges them:

1. `~/.claude/CLAUDE.md` (global) — persona-specific behavior, mounted per container
2. `/workspace/CLAUDE.md` (project root) — shared project context, versioned in the repo

This means persona instructions and project context are cleanly separated and independently versioned.

## Images

| Image | Dockerfile | Use |
|---|---|---|
| `claude-po-img` | `dockerfiles/claude-code/Dockerfile` | PO persona (lightweight — no build tools needed) |
| `claude-dev-img` | `dockerfiles/claude-code-dev/Dockerfile` | Dev and Test personas (includes Java 25, Maven, gh CLI) |