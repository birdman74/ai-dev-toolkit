# How It Works

This toolkit implements a **spec-driven, TDD-first, multi-persona agentic development workflow** using Claude Code Docker containers. Each persona is a separate container with a scoped identity, a scoped filesystem view, and a persona-specific `CLAUDE.md` system prompt that defines its role and responsibilities. GitHub Actions orchestrates the hand-offs between personas — no manual persona launching is required once a story enters the queue.

## The Three Personas

| Persona | Role | Image | Commits As |
|---|---|---|---|
| PO | Product Owner — defines epics and user stories | `claude-po-img` | `claude-<project>-po` |
| Dev | Senior Developer — reviews Test's design, then implements | `claude-dev-img` | `claude-<project>-dev` |
| Test | Senior QA Engineer — goes first, defines contracts and failing tests | `claude-dev-img` | `claude-<project>-test` |

## The Workflow

The defining property is that **Test goes first**. The API contract and a full set of failing tests exist before Dev writes a line of implementation. Dev's first job is to review that design, not to code.

```
Human (Architect / Reviewer)
        |
        v
  PO Persona  (works on a specs/ branch)
  - Interviews the human for requirements
  - Writes epics and user stories to docs/specs/
  - Opens a PR and creates a GitHub Issue per story (labeled `story`)
  - If the human requests changes, revises on the same branch
        |
        v
  Human reviews and merges the specs PR
        |
        v
  Queue manager  (scripts/next-story.sh, run by GitHub Actions)
  - Picks the lowest-numbered open `story` issue whose prerequisites are all closed
  - Marks it `in-progress` and wakes Test
        |
        v
  Test Persona — Phase 1  (creates the feature branch)
  - Writes a test plan mapped to every AC-N acceptance criterion
  - Defines API contracts and cross-story invariant tests
  - Commits failing automated tests
        |
        v
  Dev Persona — Design Review
  - Reads the story, test plan, and contracts
  - Either commits story-NNN-agreed.md, or commits dev-feedback-rN.md
  - Up to 3 iteration rounds; Test revises in between
  - After round 3 without agreement, a GitHub Issue escalates to the human
        |
        v
  Dev Persona — Implementation  (after story-NNN-agreed.md exists)
  - Writes lower-level unit tests first
  - Implements until the full suite passes (mvn clean verify)
  - Opens a PR as the bot account
        |
        v
  Test Persona — Final Verification
  - Runs the full suite, analyzes the diff for regressions
  - Adds regression tests for any shared-infrastructure changes
  - Posts a structured test-run summary as a PR comment
  - Submits gh pr review --approve or --request-changes
        |
        v
  Human reviews the PR and merges to main
        |
        v
  Queue manager closes the completed issue and starts the next eligible story
```

### Changes Requested feedback loop

If the human (or Test) requests changes on the PR:

- **Human requests changes** → Test writes new failing tests covering the gap and pushes them. The push is the trigger.
- Because Dev and Test share one bot account and Dev opened the PR, **GitHub will not let Test submit a formal review on that PR**. So the feedback loop is push-based: Test pushes failing tests to `src/test/**`, a workflow detects the commit author plus the PR's `changes_requested` state, and wakes Dev.
- Dev fixes the implementation on the same branch (no new PR), pushes, and Test re-verifies.

## GitHub Actions Orchestration

Every hand-off above is fired by a trigger workflow on a self-hosted runner. Each also supports `workflow_dispatch` for manual recovery. See [agentic-workflow-diagram.md](agentic-workflow-diagram.md) for the full visual chain and the per-trigger condition filters.

| Trigger | Fires on | Wakes |
|---|---|---|
| `trigger-test-next-story.yml` | story spec pushed to `main`, or any PR merged | Test — Phase 1 (via the queue manager) |
| `trigger-dev-review.yml` | Test pushes a test plan or revision | Dev — design review |
| `trigger-test-revision.yml` | Dev pushes `dev-feedback-rN.md` | Test — revision |
| `trigger-dev-implement.yml` | Dev pushes `story-NNN-agreed.md` | Dev — implementation |
| `trigger-test-final-review.yml` | bot opens a PR targeting `main` | Test — final verification |
| `trigger-on-changes-requested.yml` | human submits a Changes Requested review | Test — write failing tests |
| `trigger-dev-on-test-commit.yml` | Test pushes to `src/test/**` while PR is `changes_requested` | Dev — fix |
| `trigger-test-on-dev-fix.yml` | Dev pushes to an open PR branch | Test — re-verification |
| `trigger-po-on-changes-requested.yml` | human submits a Changes Requested review on a `specs/` PR | PO — revise specs |
| `ci.yml` | push / PR to `main` | — (structure + build checks) |

## Story Queue (GitHub Issues)

Story state lives entirely in GitHub Issues — there are no state files to race on.

- Each story has an issue titled `story-NNN: <Title>`, labeled `story`.
- Labels track state: `in-progress` (current work), `blocked` (unmet prerequisites).
- `scripts/next-story.sh` queries the Issues API at runtime: it errors if any story is already `in-progress`, otherwise returns the lowest-numbered open story whose `## Prerequisites` (parsed from the spec file) are all closed.
- On PR merge, `trigger-test-next-story.yml` closes the completed issue and immediately starts the next eligible story.

## Security Model

- Each persona container runs as a non-root user (`node`, uid 1000).
- Each project gets one scoped SSH deploy key shared across personas — personas can push branches but branch protection on `main` blocks merges.
- Two fine-grained PATs, both least-privilege:
  - **Bot persona token** (`<PROJECT>_BOT_GH_TOKEN`) — used by the personas' `gh` sessions for PR and review operations. Generated by the bot collaborator account.
  - **Queue manager token** (`QUEUE_MANAGER_GH_TOKEN`) — used only by `trigger-test-next-story.yml` for issue label writes and closing issues. Generated by the repo owner, because a collaborator's fine-grained PAT cannot write issues on a repo it does not own.
- Neither token can merge to `main`; merges are human-only.
- Each persona only mounts the directories it needs — no access to unrelated projects.
- Credentials live in `.env` files (gitignored) — never hardcoded in committed files.

## CLAUDE.md Hierarchy

Claude Code reads two CLAUDE.md files on startup and merges them:

1. `~/.claude/CLAUDE.md` (global) — persona-specific behavior, mounted per container from `.claude/personas/<persona>/CLAUDE.md`
2. `<workspace>/CLAUDE.md` (project root) — shared project context, versioned in the repo

The project is mounted at a project-named root (e.g. `/streamvault`), set by `<REPLACE:workspace-name>` in the Dockerfile `WORKDIR` and the compose bind mount. This keeps persona instructions and project context cleanly separated and independently versioned.

## Images

| Image | Dockerfile | Use |
|---|---|---|
| `claude-base-img` | `dockerfiles/claude-base/Dockerfile` | Base — Claude Code + git only |
| `claude-po-img` | `dockerfiles/claude-po/Dockerfile` | PO persona — base + `gh` CLI (no build tools) |
| `claude-dev-img` | `dockerfiles/claude-code-dev/Dockerfile` | Dev and Test personas — adds Java 25, Maven, `gh` CLI |
