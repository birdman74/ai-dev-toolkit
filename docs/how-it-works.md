# How It Works

This toolkit implements a **spec-driven, TDD-first, multi-persona agentic development workflow** using Claude Code Docker containers. Each persona is a separate container with a scoped identity, a scoped filesystem view, and a persona-specific `CLAUDE.md` system prompt that defines its role and responsibilities. GitHub Actions orchestrates the hand-offs between personas - no manual persona launching is required once a story enters the queue.

## The Three Personas

| Persona | Role | Image | Commits As |
|---|---|---|---|
| PO | Product Owner - defines epics and user stories | `claude-po-img` | `claude-<project>-po` |
| Dev | Senior Developer - reviews Test's design, then implements | `claude-dev-img` | `claude-<project>-dev` |
| Test | Senior QA Engineer - goes first, defines contracts and failing tests | `claude-dev-img` | `claude-<project>-test` |

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
  Queue  (scripts/next-story.sh, run by the test-kickoff gate)
  - Picks the lowest-numbered open `story` issue whose prerequisites were all closed as completed
  - Marks it `in-progress` and wakes Test
        |
        v
  Test Persona: Phase 1  (creates the feature branch)
  - Writes a test plan mapped to every AC-N acceptance criterion
  - Defines API contracts and cross-story invariant tests
  - Commits failing automated tests
        |
        v
  Dev Persona: Design Review           <-- loop, up to DESIGN_ROUND_LIMIT rounds -->
  - Checks the design AND that every committed test matches the contracts      Test revises
  - Commits story-NNN-agreed.md, or dev-feedback-rN.md                         and reconciles
        |                                                                      its test code
        v
  Dev Persona: Implementation
  - Writes lower-level unit tests first
  - Implements until the full suite passes (mvn clean verify)
  - A defective test? Reports it in impl-feedback-rN.md; Test fixes or explains
    in impl-feedback-response-rN.md; Dev resumes  (IMPL_FEEDBACK_ROUND_LIMIT)
  - Opens a PR as the bot account
        |
        v
  Test Persona: Final Verification
  - Runs the full suite, analyzes the diff for regressions
  - Posts a Test Run Summary as a PR comment with a verdict marker
  - CHANGES_REQUESTED wakes Dev to fix; Dev's fix wakes Test to re-verify  (DEV_FIX_ROUND_LIMIT)
        |
        v  (APPROVED)
  Human reviews the PR and merges to main
        |
        v
  The issue is closed as completed, dependents unblocked, the next story starts
```

At any point, Test or Dev can ask PO about an acceptance criterion by committing `po-question-rN.md`. PO answers in `po-answer-rN.md` on the same branch (and may amend that story's criteria), and the answer wakes whoever asked (`PO_QUESTION_LIMIT` per story).

### Changes Requested feedback loop

- **Test requests changes**: Test's verdict comment (`<!-- test-verdict: CHANGES_REQUESTED -->`) wakes Dev. Dev and Test share the bot account that opened the PR, and GitHub does not let a PR author review its own PR, so the verdict is a comment, never a formal review (ADR-004).
- **The human requests changes**: Test writes a failing test for every point a test can express, lists the rest as Non-testable review points, and posts a CHANGES_REQUESTED verdict, which wakes Dev the same way.
- Dev fixes on the same branch (no new PR) and pushes once; that push wakes Test to re-verify.

### When the human is pulled in

Only through a `needs-brian` issue, assigned to the human by the bot account: a loop passed its limit, a persona stalled, crashed or timed out, PO judged an answer beyond the story's scope, or a story PR was closed without merging. The issue names the Manual Dispatch to run once the cause is fixed, and closes itself when the story moves again.

## GitHub Actions Orchestration

Every hand-off is decided in one place and run by one reusable workflow (ADR-005):

- **`.github/pipeline-config.env`** holds every knob: accounts, persona git authors, launcher paths, round limits, timeouts, retries, board names. `scripts/pipeline-config.sh` validates it.
- **`scripts/transition.sh`** is the registry of hand-offs: for each one it holds the routing rule, the live state check, round counting, the limit, the prompt, and the expected result.
- **`persona-run.yml`** (reusable, self-hosted runner) rechecks that the hand-off is still needed, launches the persona, removes its container, verifies the result on GitHub, and escalates or resolves.
- **Six adapters** (`pipeline-*.yml`) turn GitHub events into a gate job on a GitHub-hosted runner that runs `transition.sh route` from `main`, then call `persona-run.yml@main`.

| Adapter | Fires on | Hand-offs |
|---|---|---|
| `pipeline-main-and-merge.yml` | story spec pushed to `main`, PR closed | queue, Test Phase 1 |
| `pipeline-feature-push.yml` | any push to `feature/story-*` | design loop, implementation, defective-test loop, PO loop, Test re-verification |
| `pipeline-pr-opened.yml` | the bot opens a story PR | Test final verification |
| `pipeline-test-verdict.yml` | Test's CHANGES_REQUESTED verdict comment | Dev fix |
| `pipeline-review-submitted.yml` | the human's Changes Requested review | Test Phase 4 (story PR), PO revision (specs PR) |
| `pipeline-manual.yml` | manual dispatch | any hand-off, for recovery |
| `sync-blocked-labels.yml`, `sync-project-board.yml` | issue events | `blocked` labels, project board columns |
| `ci.yml` | push / PR to `main` | (structure and build checks) |

See [agentic-workflow-diagram.md](agentic-workflow-diagram.md) for the diagram, the full hand-off table, and the human's PR review guide.

## Story Queue (GitHub Issues)

Story state lives entirely in GitHub Issues: there are no state files to race on.

- Each story has an issue titled `story-NNN: <Title>`, labeled `story`.
- Labels track state: `in-progress` (current work), `blocked` (unmet prerequisites).
- `scripts/next-story.sh` queries the Issues API at runtime: it stops if any story is already `in-progress`, otherwise returns the lowest-numbered open story whose `## Prerequisites` (parsed from the spec file by `scripts/check-prerequisites.sh`) were all closed as completed. It fails closed on any API error.
- On PR merge, the gate closes the completed issue as completed and starts the next eligible story. `sync-blocked-labels.yml` and `sync-project-board.yml` keep labels and the board in step.

## Security Model

- Each persona container runs as a non-root user (`node`, uid 1000).
- Each project gets one scoped SSH deploy key shared across personas - personas can push branches but branch protection on `main` blocks merges.
- Three tokens, each least-privilege:
  - **Bot persona token** (`<PROJECT>_BOT_GH_TOKEN`): a classic token from the bot collaborator account (fine-grained tokens cannot write to a repo the account does not own). The workflows use it for PR reads, verdict checks and escalation issues. The personas' own `gh` sessions log in as the bot through a mounted `gh` config directory, not through an environment variable.
  - **Queue manager token** (`QUEUE_MANAGER_GH_TOKEN`): a fine-grained token from the repo owner, used only by the queue and label reconciliation for issue labels and closing issues.
  - **Project board token** (`PROJECT_BOARD_GH_TOKEN`): a classic token from the repo owner with `project` and `repo` scopes, used only by the board sync. `GITHUB_TOKEN` and fine-grained tokens cannot reach a user-owned Projects V2 board.
- Neither token can merge to `main`; merges are human-only.
- Each persona only mounts the directories it needs - no access to unrelated projects.
- Credentials live in GitHub Actions secrets or gitignored files, never in committed files.

## CLAUDE.md Hierarchy

Claude Code reads two CLAUDE.md files on startup and merges them:

1. `~/.claude/CLAUDE.md` (global) - persona-specific behavior, mounted per container from `.claude/personas/<persona>/CLAUDE.md`
2. `<workspace>/CLAUDE.md` (project root) - shared project context, versioned in the repo

The project is mounted at a project-named root (e.g. `/streamvault`), set by `<REPLACE:workspace-name>` in the Dockerfile `WORKDIR` and the compose bind mount. This keeps persona instructions and project context cleanly separated and independently versioned.

## Images

| Image | Dockerfile | Use |
|---|---|---|
| `claude-base-img` | `dockerfiles/claude-base/Dockerfile` | Base - Claude Code + git only |
| `claude-po-img` | `dockerfiles/claude-po/Dockerfile` | PO persona - base + `gh` CLI (no build tools) |
| `claude-dev-img` | `dockerfiles/claude-code-dev/Dockerfile` | Dev and Test personas - adds Java 25, Maven, `gh` CLI |
