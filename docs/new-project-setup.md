# New Project Setup Checklist

Use this checklist when wiring a new project to the ai-dev-toolkit persona workflow.

## 1. GitHub Repository

- [ ] Create repo on GitHub (public for portfolio projects)
- [ ] Set default branch to `main`
- [ ] Add All Rights Reserved `LICENSE` file (or MIT if open source)
- [ ] Add `.gitignore` covering secrets, build artifacts, OS files
- [ ] Add `.env.example` documenting all required environment variables
- [ ] Add `.gitattributes` normalizing line endings to LF

## 2. SSH Deploy Key

```bash
mkdir -p /home/brian/.claude/git-identities/<project>
ssh-keygen -t ed25519 -C "claude-<project>" -f /home/brian/.claude/git-identities/<project>/id_ed25519
# Leave passphrase empty
ssh-keyscan github.com > /home/brian/.claude/git-identities/<project>/known_hosts
```

Register the public key in GitHub:
- Repo → **Settings → Deploy keys → Add deploy key**
- Title: `claude-<project>-personas`
- Allow write access: ✅

Verify:
```bash
ssh -i /home/brian/.claude/git-identities/<project>/id_ed25519 \
    -o IdentitiesOnly=yes \
    -o UserKnownHostsFile=/home/brian/.claude/git-identities/<project>/known_hosts \
    git@github.com
```

## 3. GitHub Fine-Grained PAT (for gh CLI in Dev/Test containers)

- GitHub → **Settings → Developer settings → Fine-grained tokens → Generate new token**
- Repository access: this repo only
- Permissions: Pull requests (read/write), Issues (read — needed for PR comments)
- Add token to project `.env` as `GITHUB_TOKEN`
- Add placeholder to `.env.example`

## 4. CLAUDE.md Files

```bash
mkdir -p .claude/personas/po
mkdir -p .claude/personas/dev
mkdir -p .claude/personas/test
```

- Copy `personas/templates/po/CLAUDE.md` → `.claude/personas/po/CLAUDE.md`
- Copy `personas/templates/dev/CLAUDE.md` → `.claude/personas/dev/CLAUDE.md`
- Copy `personas/templates/test/CLAUDE.md` → `.claude/personas/test/CLAUDE.md`
- Replace all `<REPLACE:project-name>` placeholders with your project name
- Create `CLAUDE.md` at repo root with project-wide context (stack, conventions, workflow)

## 5. Docker Compose Files

For each persona (po, dev, test):
- Copy `compose/claude-persona.yml` → `/mnt/e/docker/claude-<project>-<persona>/docker-compose.yml`
- Replace all `<REPLACE:...>` placeholders

## 6. Launcher Scripts

For each persona (po, dev, test):
- Copy `scripts/launch-persona.sh` → `~/bin/<project>-<persona>.sh`
- Replace all `<REPLACE:...>` placeholders
- Make executable: `chmod +x ~/bin/<project>-<persona>.sh`

## 7. STATUS.md

- Create `STATUS.md` at repo root
- Include: Last Updated date, Health Indicator rules, Infrastructure Tasks, Application Milestones, Epics & Stories, Blocked Items
- Commit with: `docs: add STATUS.md`

## 8. Verify Everything Works

```bash
# Test PO persona
<project>-po.sh
# Inside container:
/status   # verify CLAUDE.md loaded, workspace mounted, git identity set
exit

# Test Dev persona
<project>-dev.sh
# Inside container:
java -version    # should show Java 25
mvn -version     # should show Maven 3.9.x
gh --version     # should show gh CLI version
exit
```