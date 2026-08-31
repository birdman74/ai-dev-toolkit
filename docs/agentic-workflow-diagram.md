# StreamVault Agentic Workflow — Automation Reference

This document shows the complete automated workflow, which GitHub Actions trigger fires at each step, and which persona is woken. All triggers run on the self-hosted runner. Manual `workflow_dispatch` overrides are available for every trigger.

---

## Workflow Diagram

```mermaid
flowchart TD
    BRIAN(["👤 Brian\nbirdman74\nCODEOWNER"])

    PO_COMMIT["PO commits\ndocs/specs/story-NNN-*.md\nto main"]

    T1["🔔 trigger-test-on-spec.yml\npush to main\npath: docs/specs/story-*.md"]
    TEST_P1["🧪 TEST — Phase 1\nCreate feature branch\nWrite test plan + API contracts\nWrite failing tests\nCommit + push"]

    T2["🔔 trigger-dev-review.yml\npush to feature/story-*\npath: story-*-test-plan.md\nor story-*-test-revision-r*.md"]
    DEV_REVIEW["⚙️ DEV — Design Review\nRead test plan\nAgree or push back"]

    ESCALATION["⚠️ GitHub Issue opened\nBrian notified by email\nWorkflow paused"]

    T3["🔔 trigger-test-revision.yml\npush to feature/story-*\npath: story-*-dev-feedback-r*.md"]
    TEST_P2["🧪 TEST — Phase 2 Revision\nRevise test plan + contracts\nCommit story-NNN-test-revision-rN.md\npush"]

    T4["🔔 trigger-dev-implement.yml\npush to feature/story-*\npath: story-*-agreed.md"]
    DEV_IMPL["⚙️ DEV — Phase 2 Implementation\nWrite unit tests first\nImplement until all tests pass\nmvn clean verify\nCommit + push\nOpen PR as bot"]

    T5["🔔 trigger-test-final-review.yml\nPR opened targeting main\nactor: bot only"]
    TEST_P3["🧪 TEST — Phase 3 Final Review\nRun full suite\nDiff analysis + regression tests\nPost PR comment\ngh pr review --approve\nor --request-changes"]

    T6["🔔 trigger-on-changes-requested.yml\nPR review: changes_requested\nreviewer: birdman74 only"]
    TEST_P4["🧪 TEST — Phase 4\nRead Brian's comments\nWrite failing tests\nCommit + push\n⚠️ Push is the trigger — no gh pr review"]

    T7["🔔 trigger-dev-on-test-commit.yml\npush to feature/story-*\npath: src/test/**\nauthor: claude-streamvault-test\nPR must have changes_requested"]
    DEV_P3["⚙️ DEV — Phase 3 Fix\nRead new failing tests\nFix until all tests pass\nmvn clean verify\nCommit + push\nNo new PR"]

    T8["🔔 trigger-test-on-dev-fix.yml\npush to feature/story-*\nauthor: claude-streamvault-dev\nOpen PR must exist"]
    TEST_REVERIFY["🧪 TEST — Re-verification\nPull branch\nRun full suite\nPost updated PR comment\ngh pr review --approve\nor --request-changes"]

    MERGE["✅ Brian reviews\nBrian approves as CODEOWNER\nBrian merges to main"]

    BRIAN --> PO_COMMIT
    PO_COMMIT --> T1
    T1 --> TEST_P1
    TEST_P1 --> T2
    T2 -->|"round ≤ 3"| DEV_REVIEW
    T2 -->|"round > 3"| ESCALATION
    DEV_REVIEW -->|"pushes back"| T3
    T3 --> TEST_P2
    TEST_P2 --> T2
    DEV_REVIEW -->|"agrees\ncommits story-NNN-agreed.md"| T4
    T4 --> DEV_IMPL
    DEV_IMPL --> T5
    T5 --> TEST_P3
    TEST_P3 -->|"approves"| MERGE
    TEST_P3 -->|"requests changes"| T6
    BRIAN -->|"requests changes"| T6
    T6 --> TEST_P4
    TEST_P4 -->|"pushes failing tests\nauthor: claude-streamvault-test\nPR in changes_requested"| T7
    T7 --> DEV_P3
    DEV_P3 -->|"author: claude-streamvault-dev\nopen PR exists"| T8
    T8 --> TEST_REVERIFY
    TEST_REVERIFY -->|"approves"| MERGE
    TEST_REVERIFY -->|"requests changes"| T6

    style BRIAN fill:#4A90D9,color:#fff
    style ESCALATION fill:#E84545,color:#fff
    style MERGE fill:#27AE60,color:#fff
    style T1 fill:#F39C12,color:#fff
    style T2 fill:#F39C12,color:#fff
    style T3 fill:#F39C12,color:#fff
    style T4 fill:#F39C12,color:#fff
    style T5 fill:#F39C12,color:#fff
    style T6 fill:#F39C12,color:#fff
    style T7 fill:#F39C12,color:#fff
    style T8 fill:#F39C12,color:#fff
    style TEST_P1 fill:#8E44AD,color:#fff
    style TEST_P2 fill:#8E44AD,color:#fff
    style TEST_P3 fill:#8E44AD,color:#fff
    style TEST_P4 fill:#8E44AD,color:#fff
    style TEST_REVERIFY fill:#8E44AD,color:#fff
    style DEV_REVIEW fill:#2ECC71,color:#fff
    style DEV_IMPL fill:#2ECC71,color:#fff
    style DEV_P3 fill:#2ECC71,color:#fff
    style PO_COMMIT fill:#95A5A6,color:#fff
```

---

## Trigger Summary Table

| Trigger File | Event | Path / Condition Filter | Author / Actor Filter | Wakes |
|---|---|---|---|---|
| `trigger-test-on-spec.yml` | push to `main` | `docs/specs/story-*.md` | `birdman74` or bot | Test Phase 1 |
| `trigger-dev-review.yml` | push to `feature/story-*` | `story-*-test-plan.md` or `story-*-test-revision-r*.md` | `birdman74` or bot | Dev design review |
| `trigger-test-revision.yml` | push to `feature/story-*` | `story-*-dev-feedback-r*.md` | `birdman74` or bot | Test Phase 2 revision |
| `trigger-dev-implement.yml` | push to `feature/story-*` | `story-*-agreed.md` | `birdman74` or bot | Dev Phase 2 implementation |
| `trigger-test-final-review.yml` | PR opened/reopened targeting `main` | — | bot only | Test Phase 3 final review |
| `trigger-on-changes-requested.yml` | PR review `changes_requested` | — | `birdman74` only | Test Phase 4 |
| `trigger-dev-on-test-commit.yml` | push to `feature/story-*` | `src/test/**` + PR in `changes_requested` | author: `claude-streamvault-test` | Dev Phase 3 fix |
| `trigger-test-on-dev-fix.yml` | push to `feature/story-*` | open PR must exist | author: `claude-streamvault-dev` | Test re-verification |

---

## Why Not Use gh pr review to Trigger Dev?

GitHub prevents the PR author from reviewing their own PR. Since both Dev and Test use the same bot account (`briankcampbell-streamvault-bot`) and Dev opens the PR, Test cannot submit a formal review on that PR. The solution is to use commit pushes as triggers instead — Test pushing failing tests triggers Dev, Dev pushing fixes triggers Test.

---

## Escalation

If Test and Dev complete 3 rounds of design iteration without agreement, `trigger-dev-review.yml` opens a GitHub Issue:

```
⚠️ story-NNN: Design iteration limit reached — Brian review required
```

Brian receives an email notification. The workflow pauses until Brian manually commits `story-NNN-agreed.md`.

---

## Manual Override

Every trigger supports `workflow_dispatch` from the GitHub Actions tab. Use when a container exited before completing its work, a push happened before the workflow existed, or you need to re-run a phase without re-triggering the preceding step.

---

*This document lives in `ai-dev-toolkit` because it documents the reusable workflow framework.*