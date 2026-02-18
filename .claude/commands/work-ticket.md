---
description: Pick up and work on the next ticket from the Ready column
---

Launch the github-ticket-worker agent to implement the next prioritized ticket.

> **Reference**: See `docs/TICKET-FORMAT.md` for the expected ticket format.

## Critical Rules

1. **Branch from main**: `feature/issue-{number}-short-description`
2. **Move ticket to In Progress** on the project board before starting work
3. **All tests must pass before pushing** — never use `--no-verify`
4. **Monitor CI after PR creation**: `gh pr checks <PR_NUMBER> --watch` — fix failures up to 3 times
5. **Move ticket to In Review** only when CI passes
6. **Never merge PRs** — human reviewer does this
7. **Never commit directly to main** — always use feature branches and PRs

## Workflow Steps

1. **Select Ticket** — Find top priority in Ready column, verify Definition of Ready, confirm no blockers
2. **Validate Ticket Format** — Check the ticket body for the 4 Power Sections:
   - **A. Environment Context**, **B. Guardrails**, **C. Happy Path**, **D. Definition of Done**
   - If any section is missing or empty:
     1. Read `docs/TECHNICAL-ARCHITECTURE.md`, `docs/PRODUCT-REQUIREMENTS.md`, and the parent epic
     2. Fill in the missing sections (best-effort)
     3. Update the GitHub issue with the fleshed-out version
     4. Present the completed spec to the user for confirmation before coding
   - If all 4 sections are present → proceed normally (no delay)
3. **Setup** — Create branch, move to In Progress
4. **Implement** — Follow CLAUDE.md standards, write clean code, follow existing patterns
5. **Test Locally** — Run lint and tests. Do NOT push if any fail.
6. **Push** — If pre-push hook fails, fix and retry (see Reference below)
7. **Create PR** — Detailed description, link to issue
8. **Monitor CI** — Watch checks, auto-fix failures, move to In Review when green

## Usage

```
/work-ticket
/work-ticket #123
```

---

## Reference Material

### Pre-Push Hook Failure Protocol

```bash
# 1. Read the error output
# 2. Fix the issue (often auto-fixable):
uv run ruff check . --fix
# 3. Stage and amend:
git add -A && git commit --amend --no-edit
# 4. Push again:
git push origin <branch> --force-with-lease
```

| Error | Fix |
|-------|-----|
| `W293 Blank line contains whitespace` | `uv run ruff check --fix` |
| `F401 imported but unused` | Remove the unused import |
| `I001 Import block is un-sorted` | `uv run ruff check --fix` |
| `pytest` failures | Fix the failing test or the code it tests |

### CI Monitoring Protocol

```bash
gh pr checks <PR_NUMBER> --watch
# If checks fail:
gh run list --branch <BRANCH> --status failure --limit 1 --json databaseId,name
gh run view <RUN_ID> --log-failed
# Fix, commit, push, repeat (max 3 attempts)
```

| Failure Type | Response |
|--------------|----------|
| Lint errors (ruff) | Fix the specific lint violations |
| Test failures | Fix the failing test or the code it tests |
| Import errors | Fix import paths or add missing dependencies |
| Build failures | Fix build configuration or dependencies |

### When to Stop Retrying

Stop after 3 fix attempts OR when encountering:

- Flaky tests that pass/fail randomly (note in PR comment)
- Infrastructure issues (GitHub Actions outage)
- Failures requiring architectural changes beyond ticket scope
- Missing secrets or environment configuration

**Escalation**: Leave a detailed PR comment explaining what was tried,
what's failing, and recommended next steps.

### Workflow Rules

- Only work on tickets from the Ready column
- One ticket at a time (no parallel work)
- Agent is responsible for delivering a clean, CI-passing PR
