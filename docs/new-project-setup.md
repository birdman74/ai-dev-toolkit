# New Project Setup Checklist

Use this checklist when wiring a new project to the ai-dev-toolkit persona workflow.
This reflects lessons learned from the StreamVault project — follow it exactly to avoid
the pitfalls documented in DEVLOG.md.

---

## 1. GitHub Repository

- [ ] Create repo on GitHub (public for portfolio projects)
- [ ] Set default branch to `main` — do this in GitHub account Settings → Repositories BEFORE creating the repo
- [ ] Add All Rights Reserved `LICENSE` file (or MIT if open source)
- [ ] Add `.gitignore` covering secrets, build artifacts, OS files, IDE files
- [ ] Add `.env.example` documenting all required environment variables (no real values)
- [ ] Add `.gitattributes` normalizing line endings to LF:
```
* text=auto eol=lf
*.bat text eol=crlf
*.cmd text eol=crlf
```
- [ ] Set remote URL to SSH format — never HTTPS:
```bash
git remote set-url origin git@github.com:birdman74/<repo>.git
```

**Why SSH remote matters**: persona containers authenticate via `GIT_SSH_COMMAND` using a deploy key. If the remote is HTTPS, pushes from persona containers will fail silently or require credential workarounds.

---

## 2. SSH Deploy Key (one per project, shared across all personas)

```bash
mkdir -p /home/brian/.claude/git-identities/<project>
ssh-keygen -t ed25519 -C "claude-<project>" \
  -f /home/brian/.claude/git-identities/<project>/id_ed25519
# Leave passphrase EMPTY — containers run non-interactively
ssh-keyscan github.com > /home/brian/.claude/git-identities/<project>/known_hosts
```

Register the public key in GitHub:
- Repo → **Settings → Deploy keys → Add deploy key**
- Title: `claude-<project>-personas`
- Key: paste contents of `id_ed25519.pub`
- Allow write access: ✅

Verify:
```bash
ssh -i /home/brian/.claude/git-identities/<project>/id_ed25519 \
    -o IdentitiesOnly=yes \
    -o UserKnownHostsFile=/home/brian/.claude/git-identities/<project>/known_hosts \
    git@github.com
```
Expected: `Hi birdman74/<repo>! You've successfully authenticated...`

---

## 3. GitHub Bot Account (for PR automation)

The bot account (`briankcampbell-streamvault-bot`) can be reused across projects.

- [ ] Add bot account as collaborator on the new repo: Repo → **Settings → Collaborators → Add people** → `briankcampbell-streamvault-bot` → Write role
- [ ] Bot must accept the collaborator invitation (check `brian.k.campbell+streamvault-bot@outlook.com`)

### Fine-Grained PAT for gh CLI

Generate from the bot account (log in as bot in incognito):
- **Settings → Developer settings → Fine-grained personal access tokens → Generate new token**
- Token name: `<project>-personas`
- Expiration: 90 days (set a calendar reminder to rotate)
- Resource owner: bot account
- Repository access: All repositories (bot is only a collaborator on repos you explicitly added it to, so scope is limited by collaborator permissions)
- Permissions:
  - Contents: Read and write
  - Pull requests: Read and write
  - Metadata: Read (auto-selected)

Store as `<PROJECT>_BOT_GH_TOKEN` in `.env` — **never use `GITHUB_TOKEN`** as the variable name, it is reserved by GitHub Actions and causes conflicts.

Add placeholder to `.env.example`:
```
<PROJECT>_BOT_GH_TOKEN=
```

### Persist gh CLI Auth Inside Containers

```bash
mkdir -p /home/brian/.config/gh-<project>
```

After first `gh auth login` inside a persona container (requires browser device code flow logged in as bot account), copy the config out before the container exits:

```bash
docker cp <container-id>:/home/brian/.config/gh/hosts.yml \
  /home/brian/.config/gh-<project>/hosts.yml
```

Add the `workflow` OAuth scope (required to push `.github/workflows/` files):
```
!gh auth refresh -h github.com -s workflow
```
Complete browser authorization as the bot account. This is persisted in the mounted config.

Mount in compose files:
```yaml
- /home/brian/.config/gh-<project>:/home/brian/.config/gh
```

---

## 4. CLAUDE.md Files

```bash
mkdir -p .claude/personas/po
mkdir -p .claude/personas/dev
mkdir -p .claude/personas/test
```

- Copy `personas/templates/po/CLAUDE.md` → `.claude/personas/po/CLAUDE.md`
- Copy `personas/templates/dev/CLAUDE.md` → `.claude/personas/dev/CLAUDE.md`
- Copy `personas/templates/test/CLAUDE.md` → `.claude/personas/test/CLAUDE.md`
- Replace all `<REPLACE:project-name>` placeholders
- Create `CLAUDE.md` at repo root with project-wide context (stack, conventions, git workflow, STATUS.md update protocol)

---

## 5. Docker Compose Files

For each persona (po, dev, test), copy `compose/claude-persona.yml` to:
```
/mnt/e/docker/claude-<project>-<persona>/docker-compose.yml
```

Replace all `<REPLACE:...>` placeholders. Key fields:
- `image`: use `claude-po-img` for PO, `claude-dev-img` for Dev and Test
- `GIT_SSH_COMMAND`: point to `/home/brian/.claude/git-identities/<project>/id_ed25519`
- `<PROJECT>_BOT_GH_TOKEN`: pass the PAT env var through
- volumes: mount `.claude`, `.claude.json`, persona CLAUDE.md, project workspace, and gh config

---

## 6. Launcher Scripts

For each persona (po, dev, test), copy `scripts/launch-persona.sh` to:
```
~/bin/<project>-<persona>.sh
```

Replace all `<REPLACE:...>` placeholders. Make executable:
```bash
chmod +x ~/bin/<project>-po.sh
chmod +x ~/bin/<project>-dev.sh
chmod +x ~/bin/<project>-test.sh
```

The `--dangerously-skip-permissions` flag is included in the template. This allows personas to run autonomously without interactive approval on every shell command. The blast radius is contained by:
- Scoped filesystem mounts (workspace only)
- Scoped GitHub permissions (bot account, no merge capability)
- Branch protection on main requiring PRs

---

## 7. Branch Protection

In GitHub repo → **Settings → Rules → Rulesets → Add ruleset**:
- Target: `main`
- Bypass list: add `birdman74` (for direct STATUS.md commits)
- Rules to enable:
  - Restrict deletions ✅
  - Require a pull request before merging ✅
  - Require status checks to pass ✅ (add your CI job names)
  - Block force pushes ✅

---

## 8. STATUS.md

Create `STATUS.md` at repo root with:
- Last Updated date (YYYY-MM-DD format)
- Health Indicator rules (Green/Yellow/Red computed from Last Updated + Blocked Items)
- Infrastructure Tasks checklist
- Application Milestones
- Epics & Stories
- Blocked Items
- Stack Reference
- Key References
- Architecture Decisions

Commit: `docs: add STATUS.md`

---

## 9. Verify Everything Works

```bash
# Test PO persona
<project>-po.sh
# Inside: verify CLAUDE.md loaded, workspace correct, git identity set
/status
exit

# Test Dev persona
<project>-dev.sh
# Inside: verify tools
!java -version      # should show Java 25
!mvn -version       # should show Maven 3.9.16
!gh auth status     # should show bot account authenticated
!ssh -T git@github.com  # should authenticate via deploy key
exit
```

---

## Known Gotchas (learned from StreamVault)

| Gotcha | Fix |
|---|---|
| `GITHUB_TOKEN` reserved by Actions | Use `<PROJECT>_BOT_GH_TOKEN` instead |
| Maven 3.9.9 does not exist | Use 3.9.16 (latest stable) |
| `gh` auth lost on container restart | Mount `/home/brian/.config/gh-<project>` as volume |
| `workflow` scope missing | Run `gh auth refresh -s workflow` inside container as bot |
| Remote set to HTTPS | Always use SSH remote: `git@github.com:birdman74/<repo>.git` |
| `container_name` ignored by `docker compose run` | Use container ID for `docker cp` operations |
| Branch is `master` not `main` | Set account default in GitHub Settings before creating repo |
| STATUS.md committed to feature branch | Always `git checkout main && git pull origin main` before editing STATUS.md |