# Facilitator Runbook

Operational reference for Agile Flow workshop facilitators. Covers the commands and workflows used before, during, and after a workshop session.

---

## Workshop Lifecycle

### Before the Workshop

| Step | Command / Script | Notes |
|------|-----------------|-------|
| Provision participant repos | `scripts/workshop-setup.sh` | Creates forks, Codespaces, Neon projects |
| Provision databases | `scripts/create-workshop-neon-projects.sh` | Per-participant Neon projects |
| Set up labels | `scripts/setup-labels.sh` | GitHub label configuration |
| Verify environment | `/doctor` | Run in each participant Codespace |
| Confirm bot permissions | `scripts/verify-bot-permissions.sh` | Solo mode: skipped |

### During the Workshop

| Step | Command | Notes |
|------|---------|-------|
| Check board health | `/sprint-status` | Board overview and next actions |
| Pick up a ticket | `/work-ticket` | Picks next ticket from Ready column |
| Review a PR | `/review-pr` | Reviews PRs in In Review |
| Log session learnings | `/log-session` | Saves journal to `reports/session-journals/` |
| Report upstream issue | `/report-upstream` | Files issue in vibeacademy/agile-flow — see below |

### After the Workshop

| Step | Command / Script | Notes |
|------|-----------------|-------|
| Tear down participant environments | `scripts/workshop-teardown.sh` | Cleans up Codespaces + Neon branches |
| Triage upstream reports | `/triage-downstream-feedback` | Run in the upstream `agile-flow` repo |

---

## Reporting Issues and Patterns Upstream: `/report-upstream`

When a workshop session surfaces a framework bug, missing pattern, or friction point worth fixing in the upstream repo, participants use `/report-upstream` to file a structured issue directly in [vibeacademy/agile-flow](https://github.com/vibeacademy/agile-flow).

### When to use it

- A framework script fails or produces unexpected output
- A command is misleading or missing a key step
- A pattern was discovered during the workshop that would help all downstream forks
- Something in the docs led the participant astray
- A feature would significantly improve the workshop experience

**Not for:** participant-specific configuration issues, app bugs (file those in the fork's own issues), or questions.

### How to run it

From inside the participant's Codespace:

```
/report-upstream
```

The command will:
1. Auto-detect the fork name, upstream commit, and Agile Flow version
2. Prompt for report type, title, description, and scope
3. File a labeled GitHub issue in `vibeacademy/agile-flow`
4. Return a link to the created issue

### Report types

| Type | Use when |
|------|----------|
| `bug` | Framework code or a script behaves incorrectly |
| `doc-gap` | A doc file is missing, wrong, or misleading |
| `dx-friction` | Something works but caused confusion or slowdown |
| `pattern` | A reusable pattern was discovered — propose for pattern library |
| `feature-request` | A new capability would improve the framework |

### What happens next

Issues are labeled `downstream-feedback` and `needs-triage`. The upstream triage agent processes them via `/triage-downstream-feedback` on a weekly cadence (or sooner). Reports are either:

- Closed with explanation (duplicate, not a framework issue, already fixed)
- Converted to a framework ticket and scheduled for a sprint

Participants are notified via GitHub notifications on the filed issue.

### Prerequisites

The participant's `gh` CLI must be authenticated:

```bash
gh auth status
```

Any GitHub account with public repo access can file issues against `vibeacademy/agile-flow`.

---

## Session Journals: `/log-session`

After each session, run `/log-session` to capture:
- Tickets delivered and in review
- Challenges and mitigations
- Insights and learnings
- Metrics (PRs created/merged, tickets completed)

Journals are saved to `reports/session-journals/YYYY-MM-DD.md`. They serve as both continuity artifacts between sessions and as the source of truth for `/report-upstream` reports — encourage participants to reference their journal when filing upstream reports.

---

## Environment Health: `/doctor`

Run `/doctor` at the start of each session to verify:
- GitHub CLI authentication
- Cloud Run deployment status
- Neon database connectivity
- Required secrets and env vars
- Pre-push hook installation

If `/doctor` reports failures, use `scripts/diagnose-cloudrun.sh` for deeper Cloud Run diagnostics.

---

## Common Issues

### `gh auth status` fails

The participant's GitHub CLI session has expired. Run:

```bash
gh auth login
```

Then retry `/report-upstream`.

### Upstream labels not found

The `downstream-feedback` and `needs-triage` labels must exist in `vibeacademy/agile-flow`. Run `scripts/setup-labels.sh` in the upstream repo if they are missing.

### Codespace running out of disk

Pre-built Codespaces expire after the workshop. Rebuild from scratch:

```bash
gh cs rebuild
```

---

## Related Docs

- [Getting Started](GETTING-STARTED.md) — first-time setup
- [Platform Guide](PLATFORM-GUIDE.md) — GCP Cloud Run + Neon setup
- [CI/CD Guide](CI-CD-GUIDE.md) — workflow reference
- [Pattern Library](PATTERN-LIBRARY.md) — canonical patterns for the stack
- [Distribution](DISTRIBUTION.md) — framework vs user-content boundary
