# StreamVault — Development Log

This log captures the evolution of the StreamVault project and its agentic development workflow. It is maintained in `ai-dev-toolkit` because it documents *how* the project is built, not *what* it builds. Each entry captures decisions made, problems encountered, fixes applied, and lessons learned — written so that future Brian (or anyone reading the repo) can understand why things are the way they are.

---

## Phase 0: Conception and Stack Decisions
**~2026-06**

### Context
Brian received direct feedback from a former manager that his LinkedIn profile lacked AI-forward keywords. A colleague reinforced this, specifically calling out: agentic development, spec-driven development, LiteLLM, AWS Bedrock, Ollama, OpenSpec, OpenCode, Tailscale, and Hermes Agent. The response was to build a real, deployed portfolio project that demonstrates these skills authentically rather than just listing them.

### Project Chosen: StreamVault
A personal streaming library tracker — functional enough to demo to interviewers, architected to showcase modern AI engineering practices.

### Stack Decisions Made
- **Backend**: Java 21 (later upgraded to Java 25 — see Phase 3), Spring Boot 3.x, Spring AI
- **Frontend**: Next.js 14+, TypeScript
- **Databases**: PostgreSQL (structured data) + MongoDB Atlas M0 free tier (flexible media metadata) — dual-store intentional to demonstrate both relational and document DB skills and to answer the NoSQL emphasis in job postings
- **AI Gateway**: LiteLLM as a provider-agnostic gateway routing between local inference (Ollama) and cloud (AWS Bedrock)
- **Agentic Workflow**: Multi-persona Claude Code containers (PO, Dev, Test)
- **Infrastructure**: AWS EC2 t3.micro, Docker, Docker Compose, Caddy reverse proxy

### Key Decision: Why Dual-Store
PostgreSQL handles users, watch history, and ratings — structured relational data. MongoDB handles media metadata — home movies have completely different fields than TMDB entries, and the flexible schema is the right tool. The intentional choice is documented so interviewers can be told *why*, not just *what*.

### Key Decision: LiteLLM as Gateway
Allows the application code to never change when switching AI providers. Dev uses Ollama (free, local), production demos use Bedrock. One config change, zero code changes.

### Colleague Tool Recommendations — Disposition
| Tool | Decision |
|---|---|
| OpenSpec / OpenCode | Adopted as spec-driven development framework |
| LiteLLM | Adopted as AI gateway |
| Ollama | Deferred — see Phase 2 |
| Tailscale | Planned for local-to-EC2 private networking |
| AWS Bedrock | Planned for production demo AI path |
| Azure AI Foundry / Snowflake Cortex | Mentioned in roadmap for keyword coverage only |
| Hermes Agent / OpenClaw | Optional weekend experiments, not core to StreamVault |

---

## Phase 1: Repository and Local Environment Setup
**~2026-06 to 2026-07**

### GitHub Repository
- Created `streamvault` repo under GitHub username `birdman74`
- All remote URLs must use `git@github.com:birdman74/streamvault.git`.
- Repo initialized with Java `.gitignore` template, then replaced with a comprehensive custom `.gitignore` covering secrets, Spring Boot local configs, Next.js, Docker overrides, IntelliJ, VS Code, and Windows/macOS OS files
- License: All Rights Reserved (not MIT) — repo must be publicly visible for recruiters but protected from copying
- `.env.example` committed as the shape of required environment variables; real `.env` gitignored
- `.gitattributes` added to normalize line endings to LF — critical on Windows/WSL2 where `^M` characters appear in diffs without this

### Windows / WSL2 Environment
- OS: Windows with WSL2 (Ubuntu 24.04.4 LTS)
- Shell: zsh via Homebrew (`/home/linuxbrew/.linuxbrew/bin/zsh`) — not bash, not vanilla zsh
- Terminal: MobaXTerm (preferred over Git Bash)
- Docker: Docker Desktop 29.4.3 integrated with WSL2
- Git: 2.43.0

### Git Configuration Lessons
- `core.autocrlf=true` set globally to handle Windows line endings
- GitHub CLI (`gh`) installed and authenticated via device code flow — browser launch from WSL2 failed; workaround is manual device code at `https://github.com/login/device`
- Personal SSH key generated at `~/.ssh/id_ed25519` and registered in GitHub account settings for WSL2 git operations
- `pull.rebase=true` set globally after encountering divergent branch errors

### Remote URL Issue
The repo's `origin` remote was initially set to HTTPS. Persona containers authenticate via SSH deploy key and `GIT_SSH_COMMAND`, so HTTPS remotes caused push failures. Fixed by switching all remotes to SSH format:
```
git remote set-url origin git@github.com:birdman74/streamvault.git
```
This must be done on both local WSL2 and EC2 after any fresh clone.

---

## Phase 2: AWS Infrastructure
**~2026-07**

### EC2 Instance
- Instance: `streamvault-server`, t3.micro, Ubuntu 24.04 LTS, 20GB gp3
- Elastic IP: `54.166.127.211` (permanent — instance was initially assigned `54.152.175.108` which changed on restart before Elastic IP was assigned)
- Security group `streamvault-sg`: SSH restricted to home IP only, HTTP/HTTPS public
- SSH key: `streamvault-key.pem` stored at `C:\Users\brian\.ssh\`
- **Lesson**: SSH security group rule uses "My IP" — if home IP changes (common with ISPs), SSH access breaks silently. Fix by updating the rule when this happens.

### Docker on EC2
- Docker 29.6.2 and Docker Compose v5.3.1 installed via official Docker apt repository
- Ubuntu `unattended-upgrades` configured for automatic security patches
- **Critical fix**: 2GB swap file added after OOM crash
  - LiteLLM container consumed ~500MB RAM on a 1GB instance, leaving nothing for the OS
  - Swap file created at `/swapfile`, made persistent via `/etc/fstab`
  - After swap: 487MB available with postgres + Caddy running

### LiteLLM Deferred from EC2
LiteLLM was initially included in the EC2 Docker Compose. On first startup it crashed the instance (OOM). Even with swap, it consumed ~860MB leaving only 49MB for everything else — insufficient headroom for Spring Boot. Decision: remove LiteLLM from EC2, keep it in local dev compose only. Will revisit when upgrading to a larger instance for production demo.

### Compose File Split
Originally one `docker-compose.yml` used everywhere. Split into:
- `docker-compose.yml` — local dev (postgres + litellm)
- `docker-compose.prod.yml` — EC2 (postgres + caddy only)

### Caddy Reverse Proxy
Added to EC2 prod compose for HTTPS termination. Responds on port 80 with a placeholder message until a domain is configured.

### Ollama Deferred (Local)
Ollama was planned as the free local inference provider. Investigation revealed:
- AMD RX 7600 XT GPU uses DirectML on Windows/WSL2
- Ollama's Docker image does not support DirectML
- CPU-only inference is too slow to be practical
- Decision: defer Ollama entirely; use Claude API via persona containers during development; revisit if Claude Pro costs become a concern

### MongoDB Atlas
- M0 free tier cluster created, named `streamvault`
- Network access configured for home IP and EC2 Elastic IP (`54.166.127.211/32`)
- Connection string stored in `.env` as `MONGO_ATLAS_URI`
- **Lesson**: Atlas connection strings from the setup flow may contain placeholder hostnames (`xxxxx`). Verify the actual cluster hostname before use.

### AWS Cost Management
- AWS Budget alarm configured before any spending began
- t3.micro on-demand: ~$8/month
- Elastic IP: free while attached to running instance; charges ~$3.60/month if instance is stopped
- **Habit established**: stop EC2 instance when not actively working

---

## Phase 3: Agentic Workflow Infrastructure
**~2026-07**

### Multi-Persona Claude Code Architecture
Three Claude Code Docker containers, each with:
- Scoped Git identity via environment variables (`GIT_AUTHOR_NAME`, `GIT_COMMITTER_NAME`, etc.)
- Shared SSH deploy key for GitHub push/pull
- Project-specific `CLAUDE.md` system prompt mounted as global config
- Access only to the directories needed for its role

### Base Docker Image (`claude-experience-img`)
Built from `ai-dev-toolkit/dockerfiles/claude-code/Dockerfile` (later renamed
`dockerfiles/claude-base/`, image `claude-base-img` — see Phase 6):
- `node:22-slim` base
- git, curl installed
- Claude Code installed globally via npm
- Runs as `node` user (uid 1000, non-root)
- `DISABLE_AUTOUPDATER=1` to prevent update attempts in read-only container

### Dev/Test Docker Image (`claude-dev-img`)
Built from `ai-dev-toolkit/dockerfiles/claude-code-dev/Dockerfile`, extends base with:
- Java 25 (Temurin 25.0.4) via Adoptium apt repository
- Maven 3.9.16 (note: 3.9.9 does not exist — build failed on first attempt with 404)
- GitHub CLI (`gh`) v2.97.0
- `openssh-client` (added after Dev container had to work around missing `ssh` binary when pushing via gh)

### CLAUDE.md Hierarchy
Claude Code reads two files on startup and merges them:
1. `~/.claude/CLAUDE.md` (global) — persona-specific behavior, mounted per container
2. `/workspace/CLAUDE.md` (project root) — shared project context, version controlled
   (the mount point is now a project-named root, e.g. `/streamvault`, set by
   `<REPLACE:workspace-name>` — see Phase 6)

Persona files live in the repo at `.claude/personas/<persona>/CLAUDE.md` and are mounted into the container as the global file. This keeps all files version controlled while maintaining per-persona behavior.

### Shared SSH Deploy Key
One key serves all three personas. Separate keys per persona were considered but the commit-level identity (via `GIT_AUTHOR_NAME`) provides sufficient traceability for a personal project. Revocation granularity was the only benefit of separate keys and is not needed here.
- Key stored at `/home/brian/.claude/git-identities/streamvault/id_ed25519`
- `known_hosts` pre-populated via `ssh-keyscan github.com`
- Registered as a deploy key on the StreamVault repo with write access

### GitHub Bot Account
A separate GitHub account (`briankcampbell-streamvault-bot`) was created to open PRs and post comments, separate from `birdman74` (Brian's personal account). This enables genuine human review of bot-opened PRs — you cannot meaningfully review your own PRs.
- Bot added as collaborator with Write access to StreamVault repo
- Fine-grained PAT generated from bot account, stored as `STREAMVAULT_BOT_GH_TOKEN` in `.env`
- **Important**: `GITHUB_TOKEN` was deliberately avoided as the variable name — it is reserved by GitHub Actions and causes conflicts
- `gh` CLI authenticated inside Dev/Test containers as the bot account
- `gh` config persisted at `/home/brian/.config/gh-streamvault/hosts.yml` mounted into containers — without this mount, auth is lost on every container restart
- `workflow` OAuth scope added to bot token after Dev failed to push `.github/workflows/ci.yml` changes — this scope is required for any push touching workflow files

### Container Name Behavior
`container_name` in docker-compose is ignored by `docker compose run` — it only applies to `docker compose up`. When using `run --rm` (as all persona launchers do), Docker generates a name from the service name + run ID. Use the container ID for `docker cp` operations when the container is running.

### Branch Protection
Branch ruleset applied to `main`:
- Require pull request before merging
- Require CI status checks to pass (validate, backend, frontend jobs)
- Bypass list: `birdman74` added so direct STATUS.md updates don't require a PR
- Bot account has no bypass — all bot work goes through PRs

### `--dangerously-skip-permissions` Flag
Persona containers currently require interactive approval for every shell command Claude Code wants to run (grep, mvn, gh, etc.). This is correct behavior by default but makes the workflow require constant babysitting. Plan to add this flag to all launcher scripts to allow autonomous operation within the already-scoped container environment.

---

## Phase 4: First Application Feature — STORY-001 Bootstrap
**~2026-08**

### Java Version Correction
Dev scaffolded the Spring Boot skeleton targeting Java 21. This was caught in PR review — the dev image runs Java 25 (Temurin) and the CI workflow also needed updating. Dev corrected both `pom.xml` and `.github/workflows/ci.yml` in the same commit and force-pushed the squashed branch.

### Maven Version
Initial Dockerfile targeted Maven 3.9.9 which does not exist on Apache mirrors (404 error during build). Correct version is 3.9.16 (latest stable as of August 2026).

### SSH vs HTTPS Remote in Dev Container
Dev container has `GIT_SSH_COMMAND` configured for SSH push via deploy key, but the `origin` remote was set to HTTPS. This caused push failures resolved by switching the remote to SSH format. Additionally, when `openssh-client` was not installed in the image, Dev had to fall back to pushing via `gh`'s HTTPS credential helper — worked but not ideal. Fixed by adding `openssh-client` to the Dockerfile.

### First Full Workflow Cycle
PR #2 completed the first full agentic workflow cycle:
1. Dev implemented on `feature/STORY-001-email-password-auth` and opened PR as `briankcampbell-streamvault-bot`
2. Test reviewed the PR and added MockMvc coverage for `/api/health`
3. Brian (`birdman74`) reviewed, approved, and merged

### CI Workflow
GitHub Actions workflow (`ci.yml`) validates repo structure, checks `.env` is not committed, and conditionally builds backend (Maven) and frontend (npm) when `pom.xml` and `package.json` exist. Backend and frontend jobs are skipped gracefully with a warning when the project files don't exist yet.

---

**2026-08-15**

### `--dangerously-skip-permissions` Flag
**Goal**: Allow personas to run autonomously without interactive approval on every shell command.
**Approach**: Add flag to all three launcher scripts in `~/bin/` and update `ai-dev-toolkit` template.
**Status**: Completed

---

## Phase 5: TDD-First Workflow and GitHub Actions Orchestration
**~2026-08**

### TDD-First Workflow Design
The original workflow had Dev implementing first and Test verifying afterward. This was redesigned to true TDD:

**New order:**
1. Test goes first — reads the PO story and writes the test plan, API contracts, and failing tests before any implementation exists
2. Test and Dev iterate on the design (up to 3 rounds) before Dev writes a single line of code
3. Dev implements against the agreed design until all of Test's failing tests pass
4. Test performs final verification including regression analysis
5. Brian reviews and merges

**Key insight**: Test writing contracts before implementation forces explicit API design decisions upfront, surfaces ambiguities before they become bugs, and makes the acceptance criteria machine-verifiable from day one.

### Test Persona: Cross-Story Invariant Testing
Test's CLAUDE.md was updated to explicitly instruct it to identify cross-story invariants during Phase 1 — not just acceptance criteria for the current story. When a story touches shared infrastructure (schema, security config, shared services), Test must write invariant tests that protect existing behavior across story boundaries.

**What triggered this**: PR #4 (STORY-002) introduced a nullable `password_hash` column in the schema migration. No test asserted that non-OAuth accounts must have a non-null password hash. The invariant was caught in Brian's PR review rather than by Test — a gap in Test's scope that the updated CLAUDE.md now explicitly covers.

### Test Persona: Regression Analysis During PR Review
Test's Phase 3 (final PR review) was updated to include explicit diff analysis. Test must:
1. Run the full existing test suite
2. Read the diff and identify shared infrastructure changes
3. Write targeted regression tests for any shared infrastructure changes before posting the summary

This gives two layers of regression protection: mechanical (full suite) and reasoned (diff analysis).

### PR Feedback Loop: Changes Requested Routing
A new `trigger-on-changes-requested.yml` workflow handles the feedback loop after PR review. It fires on `pull_request_review` submitted with `changes_requested` state and routes based on the reviewer's identity:

- `birdman74` submits Changes Requested → wakes Test (Phase 4: write failing tests, push, submit Changes Requested to trigger Dev)
- `briankcampbell-streamvault-bot` submits Changes Requested → wakes Dev (Phase 3 fix: pull branch, fix until all tests pass, push)

This means Brian never needs to manually launch a persona after posting review feedback — the chain continues automatically.

**Key design decision**: Test submits a formal `gh pr review --request-changes` (not just a comment) after writing failing tests. This is what triggers Dev. Informal comments are not sufficient to fire the workflow.

### CODEOWNERS File
`.github/CODEOWNERS` added with `* @birdman74`. Combined with the branch ruleset requiring CODEOWNER approval, this ensures that even if Test approves the PR as the bot account, the PR cannot merge without Brian's explicit approval. Test approval and Brian approval are independent requirements.

### GitHub Actions as Persona Orchestrator
A self-hosted GitHub Actions runner installed on the local WSL2 machine replaces manual persona launching for the routine workflow steps. The runner listens for events from GitHub and executes the appropriate launcher script.

**Six trigger workflows** (later grew to nine plus `ci.yml`, and
`trigger-test-on-spec.yml` was replaced by `trigger-test-next-story.yml` when
the story queue moved to GitHub Issues — see Phase 6):
- `trigger-test-on-spec.yml` — PO spec committed to main → wakes Test
- `trigger-dev-review.yml` — Test commits test plan or revision → wakes Dev for design review; escalates to GitHub Issue after 3 rounds
- `trigger-test-revision.yml` — Dev commits feedback → wakes Test to revise
- `trigger-dev-implement.yml` — Dev commits agreed.md → wakes Dev to implement
- `trigger-test-final-review.yml` — Bot opens PR → wakes Test for final verification
- `trigger-on-changes-requested.yml` — Changes Requested review submitted → routes to Test or Dev based on reviewer identity

Every trigger also supports `workflow_dispatch` for manual override from the GitHub Actions tab with explicit input parameters.

### `jq` for JSON Parsing in Workflows
Initial workflow implementation used `git diff-tree` to identify changed files. This failed repeatedly:
- Shallow clones (Actions default) — parent commit not available
- Merge commits — two parents, ambiguous diff
- The `fetch-depth: 2` fix helped shallow clones but not merge commits

Replaced with `jq` parsing of `github.event.commits` payload — the JSON GitHub already computes and provides. This approach has no git history dependency and handles all commit types correctly. `jq` was not pre-installed on the self-hosted runner; installed via `sudo apt install -y jq`.

**Lesson**: Always test CI commands locally against synthetic payloads before deploying. The `jq` command was verified locally with a sample JSON payload before any workflow files were updated.

### workflow_dispatch Added to All Triggers
All trigger workflows (six at the time, nine today) support manual dispatch from
the GitHub Actions tab. This was added after repeated situations where:
- A push fired a trigger before the workflow files were fixed
- A container exited before completing its work
- A merge commit prevented automatic re-triggering

Without `workflow_dispatch`, the only recovery option was running the auto launcher scripts manually from the terminal. With it, recovery is a few clicks in the GitHub UI with the correct context pre-filled.

### Agentic Workflow Diagram
A Mermaid flowchart (`docs/agentic-workflow-diagram.md`) documents the complete automation chain including all triggers, loops, escalation paths, and the Changes Requested routing. GitHub renders Mermaid natively — anyone viewing the repo sees a proper visual diagram, not ASCII art.

### File and Branch Naming Convention (Lessons Learned)
**Case sensitivity caused multiple trigger failures.** GitHub Actions path filters on Linux are case-sensitive. Early workflow files used uppercase `STORY-*` in path filters while actual filenames used lowercase `story-*`. Fixed by standardizing everything to lowercase:
- Branch names: `feature/story-NNN-short-kebab-case-description`
- Spec files: `docs/specs/story-NNN-*.md`
- Design artifacts: `docs/specs/design/story-NNN-*.md`
- Commit message prefixes: `test(story-NNN):`, `feat(story-NNN):`, `docs(story-NNN):`

**Lesson**: Establish and document naming conventions before writing any trigger path filters. Changing conventions after triggers are in place requires updating multiple files simultaneously.

### Feature Branch Hygiene
Merging `main` into a feature branch after workflow file fixes is a required step before re-triggering any automated workflow. Without this, the persona container runs with the old broken CLAUDE.md or workflow definitions even though main has the fixes. Established pattern: always `git merge main` on the feature branch after any main-branch updates that affect persona behavior.

### PR Self-Review Limitation and Fix
**~2026-08-29**

**Problem discovered**: GitHub prevents the PR author from submitting a formal review on their own PR. Since both Dev and Test personas use the same bot account (`briankcampbell-streamvault-bot`) and Dev opens the PR, Test cannot submit `gh pr review --request-changes` to trigger Dev in the feedback loop.

**Original design flaw**: `trigger-on-changes-requested.yml` routed to Dev when the bot submitted a Changes Requested review. This was architecturally correct but technically impossible given the single bot account constraint.

**Fix**: Replace the review-based trigger for Dev with a push-based trigger (`trigger-dev-on-test-commit.yml`). When Test pushes new failing tests to `src/test/**`:

1. The workflow checks that the commit author is `claude-streamvault-test` (distinguishes Test commits from Dev commits)
2. The workflow checks via the GitHub API that the PR is currently in `changes_requested` state (distinguishes Phase 4 feedback loop from Phase 1 initial tests and Phase 3 regression tests — both of which also push to `src/test/**`)
3. If both conditions are true, Dev is woken to fix the implementation

**Why this works**: Phase 1 test commits happen before any PR exists. Phase 3 regression test commits happen while the PR is in a neutral state (no pending changes_requested reviews). Only Phase 4 feedback loop commits happen while the PR has an active changes_requested review. The state check cleanly differentiates all three cases without any commit message parsing.

**Updated files**:
- `trigger-on-changes-requested.yml` — removed bot-to-Dev routing; now only handles Brian-to-Test routing; updated Test's prompt to explicitly NOT use `gh pr review`
- `trigger-dev-on-test-commit.yml` — new workflow handling the push-based Dev trigger
- Test's CLAUDE.md Phase 4 — removed `gh pr review --request-changes` instruction; pushing failing tests is now the trigger mechanism
- `agentic-workflow-diagram.md` — updated to show the new trigger and explain the self-review limitation

### Missing Trigger: Dev Fix Pushes to Open PR
**~2026-08-30**

**Problem discovered**: After Dev fixes implementation in response to Test's or Brian's feedback, Test was not automatically re-triggered for re-verification. `trigger-test-final-review.yml` only fires on PR opened/reopened — it does not fire on subsequent pushes to an existing open PR.

**Fix**: Added `trigger-test-on-dev-fix.yml` — fires on any push to `feature/story-*` by the bot account, checks that:
1. The commit author is `claude-streamvault-dev` (distinguishes Dev commits from Test commits)
2. An open PR exists for the branch (prevents firing during Phase 2 initial implementation push, which happens before the PR is opened)

If both conditions are true, Test is woken for Phase 3 re-verification.

**Why the open PR check correctly handles Phase 2**: Dev pushes the implementation commit first, then opens the PR in the same session. At the time the push fires the workflow, no PR exists yet — the check returns false and the trigger skips. Only fix commits on an already-open PR pass the check.

### Story Queue: GitHub Issues Replace File-Based State
**~2026-08-30**

**Problem with queue-state branch approach**: Git branches are not designed as databases. Concurrent pushes (e.g. PO adding stories while a PR merges) cause race conditions and push rejections. The queue-state branch was abandoned before implementation.

**Solution: GitHub Issues as the state store**

Story state is now managed entirely through GitHub Issues:
- Each story has a corresponding GitHub Issue titled `story-NNN: [Title]`
- Labels track state: `story` (all stories), `in-progress` (current work), `blocked` (unmet prerequisites)
- The queue manager queries GitHub Issues API at runtime — no state files, no race conditions
- Closing an issue = story completed; the queue manager closes issues automatically on PR merge

**PO image upgraded**: PO persona switched from `claude-experience-img` to new `claude-po-img` which adds `gh` CLI to the base image. This is needed for `gh issue create` after writing each story spec. Java and Maven are intentionally excluded — PO has no need for build tooling.

**Three properly scoped images now exist:**
- `claude-experience-img` — base Claude Code + git (legacy, retained for other projects)
- `claude-po-img` — base + gh CLI (PO persona)
- `claude-dev-img` — base + Java 25 + Maven + gh CLI (Dev and Test personas)

**`next-story.sh` rewritten**: Now queries GitHub Issues API instead of reading state from files. Logic:
1. Checks for any open issue labeled `in-progress` — errors out if found (single-threaded constraint)
2. Lists all open issues labeled `story`, sorted by issue number
3. For each candidate, reads `## Prerequisites` from the spec file and checks if all prerequisite issues are closed
4. Returns the first eligible story ID

**`update-story-state.sh` deleted**: No longer needed — state lives in GitHub Issues, not files.

**`## State` field dropped from story files**: Story files now contain only spec content (requirements, acceptance criteria, prerequisites). State is operational metadata and belongs in the issue tracker, not the spec.

**Story format change — `## Prerequisites` field retained**: This static dependency information still lives in the spec file since it is part of the requirements definition, not operational state.

**GitHub Project Board created**: Visual kanban board with four columns — Backlog, Ready, In Progress, Done — gives PO and Brian a human-readable view of the queue at all times.

**One-time setup**: GitHub Issues created and closed for stories 001-004 to initialize the state history that `next-story.sh` depends on for prerequisite checking.

---

## Phase 6: Queue Manager Live, PO Spec PRs, ADRs, and Workflow Hardening
**~2026-09**

### Story Queue Went Live — `trigger-test-on-spec.yml` Replaced
The GitHub Issues queue designed in Phase 5 was wired into Actions.
`trigger-test-on-spec.yml` was removed and replaced by
`trigger-test-next-story.yml`, which runs `scripts/next-story.sh` on two events:
a story spec pushed to `main`, and any PR merged to `main`. On merge it closes
the completed story's issue, removes the `in-progress` label, and immediately
starts the next eligible story. The toolkit ships the queue script as
`scripts/next-story-template.sh` (deployed as `scripts/next-story.sh` with the
`REPO="owner/repo"` line filled in).

### PO Works on a `specs/` Branch and Opens a PR
PO no longer commits specs straight to `main`. It works on a
`specs/epic-NNN-*` branch, opens a PR for human review, and creates the GitHub
Issues when the PR opens so the queue is ready the moment the human merges. A
new `trigger-po-on-changes-requested.yml` wakes PO to revise on the same branch
when the reviewer requests changes. Trigger count is now nine `trigger-*.yml`
workflows plus `ci.yml`.

### Two Separate PATs
The single bot PAT was split:
- `STREAMVAULT_BOT_GH_TOKEN` (`<PROJECT>_BOT_GH_TOKEN` in the templates) — the
  bot collaborator account's token, used by persona `gh` sessions for PR and
  review operations.
- `QUEUE_MANAGER_GH_TOKEN` (no project prefix — the workflow templates
  reference it verbatim) — used only by `trigger-test-next-story.yml` for issue
  label writes and closing issues. It must be generated by the repo owner: a
  collaborator's fine-grained PAT cannot write issues on a repo it does not own.

### Workflow Security Hardening
- Every `trigger-*.yml` and `ci.yml` job now declares an explicit least-privilege
  `permissions:` block instead of relying on the runner default.
- Trigger jobs gained an env-injection guard — untrusted event fields (branch
  names, commit messages) are passed through `env:` and referenced as shell
  variables rather than interpolated directly into `run:` scripts.
- Label management moved off `gh issue edit --add-label` onto
  `gh api --method POST/DELETE /repos/<repo>/issues/<n>/labels` for consistent
  behavior; the toolkit templates use `${{ github.repository }}` so no repo path
  is hardcoded.

### Changed-File Detection Rewritten Again
The Phase 5 `jq`-on-`github.event.commits` approach still broke on merge commits
and `workflow_dispatch` runs (no `commits` array). All trigger workflows now
derive the story ID from the branch name and use `git log` for file lists —
no dependency on the event payload shape.

### `ci.yml` Promoted to a Template
`ci.yml` (structure validation + conditional backend/frontend build) is now a
first-class toolkit template alongside the triggers, with
`<REPLACE:java-version>` / `<REPLACE:node-version>` placeholders. Its jobs are
the required status checks: `Validate Repository Structure`, `Backend Build`,
`Frontend Build`.

### Architecture Decision Records Introduced
`docs/adr/` was added. **ADR-001: Spring MVC Controller Test Authentication
Pattern** (accepted 2026-09-07) records the decision to use `@WithMockUser` in
`@WebMvcTest` slices and real JWT round-trips in `@SpringBootTest`, after Dev
and Test disagreed on the auth approach during a story review cycle. The Dev
and Test persona prompts now instruct the personas to consult `docs/adr/`
before making cross-cutting testing or security decisions. New ADRs are created
by the human reviewer based on decisions from review cycles. The toolkit ships
`templates/adr/ADR-NNN-title.md` as the skeleton.

### `CONTRIBUTING.md` Added
Conventions that had been spread across CLAUDE.md files and review comments
(branch naming, conventional-commit prefixes, DI rules, exception handling,
Flyway migration rules, API design, test naming, AC-N coverage, line endings)
were consolidated into a repo-root `CONTRIBUTING.md`. The toolkit ships a
genericized `templates/CONTRIBUTING.md`.

### Containers Mount at a Project-Named Root
Persona containers used to mount the project at a fixed `/workspace`. They now
mount at a project-named root (e.g. `/streamvault`), set by a
`<REPLACE:workspace-name>` placeholder that must match in the Dockerfile
`WORKDIR` and the compose bind mount. In-container paths in persona output now
read naturally.

### Container Files Fully Genericized
Removed the last hardcoded operator-specific values from the container files.
`/home/brian` → `<REPLACE:home-dir>` across all three Dockerfiles (`mkdir`,
`chown`, `ENV HOME`) and `compose/claude-persona.yml` (`HOME`, both
`GIT_SSH_COMMAND` paths, and the `.claude` / `.claude.json` / persona-`CLAUDE.md`
bind mounts on both sides). Like `<REPLACE:workspace-name>`, this value is baked
into the image and must match in the compose file. The git-author email domain
`@outlook.com` → `<REPLACE:email-domain>` in the compose `GIT_AUTHOR_EMAIL` /
`GIT_COMMITTER_EMAIL` lines. `docs/new-project-setup.md` §5 now carries a
placeholder table covering both. The Dockerfiles and compose file are now
entirely placeholder-driven — nothing project- or operator-specific remains.

### Image Rename
`dockerfiles/claude-code/` → `dockerfiles/claude-base/`
(`claude-experience-img` → `claude-base-img`). The three images are now
`claude-base-img` (Claude Code + git), `claude-po-img` (base + `gh`), and
`claude-dev-img` (base + Java 25 + Maven + `gh`, used by Dev and Test).

### Personal Library Epic
PO defined the `epic-personal-library` epic — STORY-005 through STORY-019
(account settings, TMDB search/browse, add movie/series, library view/filter,
watch status, episode rollup, watch dates, notes/review, personal rating,
streaming sources, series refresh). This is the first large multi-story epic to
run entirely through the Issues queue.

---

## Updated Parking Lot

### Tailscale Private Network
**Goal**: Connect local machine to EC2 via private network so cloud-deployed app can reach local Ollama without public internet exposure.
**Status**: Parked. Revisit when Ollama is unblocked.

### Ollama Local Inference
**Goal**: Free unlimited local inference during development.
**Blocker**: AMD RX 7600 XT + WSL2 Docker + DirectML not supported by Ollama image. CPU-only too slow.
**Trigger to revisit**: Claude Pro API costs become a concern.

### DDD Workflow
**Goal**: PO defines ubiquitous domain language in epics that Dev uses for entity/aggregate naming.
**Status**: Parked. TDD was implemented first. DDD can be layered on top by updating PO's CLAUDE.md to include a domain language section in epics.

### Testcontainers / Docker-in-Docker for Test Persona
**Goal**: Allow Test to run integration tests against real PostgreSQL and MongoDB instances inside the container.
**Blocker**: Mounting the host Docker socket gives the container significant host access — security tradeoff needs careful evaluation.
**Status**: Parked in backlog.

---

*This log is maintained in `ai-dev-toolkit` because it documents the workflow and framework, not the StreamVault product itself.*