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
Built from `ai-dev-toolkit/dockerfiles/claude-code/Dockerfile`:
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

## Parking Lot — Future Experiments

### GitHub Actions as Persona Orchestrator (Option B)
**Goal**: When PO commits a new spec to `docs/specs/`, automatically trigger Dev. When Dev opens a PR, automatically trigger Test. Eliminates manual persona launching for routine workflow steps.
**Approach**: Self-hosted GitHub Actions runner on local machine or EC2. Workflow triggers on `push` to `docs/specs/**` path or `pull_request` opened event.
**Status**: Parked. Implement after STORY-001 is fully merged.

### TDD/DDD Workflow Change
**Goal**: Flip current Dev-then-Test order to Test-then-Dev (true TDD). Test writes failing tests against the spec before Dev implements. DDD would have PO define ubiquitous domain language in epics that Dev uses for entity/aggregate naming.
**Approach**: Update Dev and Test persona CLAUDE.md files. No infrastructure changes needed.
**Status**: Parked. Implement as a story in the Autonomous Agentic Workflow epic.

### Tailscale Private Network
**Goal**: Connect local machine to EC2 via private network so cloud-deployed app can reach local Ollama (when unblocked) without public internet exposure.
**Status**: Parked. Revisit when Ollama is unblocked.

### Ollama Local Inference
**Goal**: Free unlimited local inference during development.
**Blocker**: AMD RX 7600 XT + WSL2 Docker + DirectML not supported by Ollama image. CPU-only too slow.
**Trigger to revisit**: Claude Pro API costs become a concern.

---

*This log is maintained in `ai-dev-toolkit` because it documents the workflow and framework, not the StreamVault product itself.*