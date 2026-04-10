# Upstream Sync Notes

This repository is a GCP-specific fork of
[vibeacademy/agile-flow](https://github.com/vibeacademy/agile-flow).

## Source Commit

Forked from: **`b9bd5e3`** (2026-04-09)

> `docs(readme): add YouTube video embed to README (#167)`

## Changed Files vs Upstream

These files are GCP-specific and will diverge from upstream. Do NOT
blindly pull upstream changes to them; reconcile manually.

### Infrastructure (GCP-specific)

- `Dockerfile` — **new file**, not present in upstream
- `.dockerignore` — **new file**, not present in upstream
- `render.yaml` — **deleted**, not applicable to GCP
- `next.config.ts` — reversed upstream's "do not use standalone" warning;
  standalone output is required for Cloud Run
- `.github/workflows/deploy.yml` — rewritten for Cloud Run + Artifact
  Registry + Workload Identity Federation
- `.github/workflows/preview-deploy.yml` — rewritten for Cloud Run
  revision tagging + Neon branching via `neondatabase/create-branch-action`
- `.github/workflows/preview-cleanup.yml` — rewritten for Cloud Run tag
  removal + Neon branch deletion

### Agent Prompts (GCP-specific guidance)

- `.claude/agents/github-ticket-worker.md` — Stack Guardrails section
  replaced with Cloud Run + Neon silent-failure patterns
- `.claude/agents/devops-engineer.md` — rewritten for GCP only (removed
  multi-platform enumeration for Render, Cloudflare, Vercel, Railway, Fly)
- `.claude/agents/system-architect.md` — Platform Ecosystems section
  rewritten for GCP; database recommendation changed from Supabase to Neon
- `.claude/commands/doctor.md` — secret checks updated for GCP/Neon

### Documentation (GCP-specific)

- `docs/PLATFORM-GUIDE.md` — rewritten as a GCP-only setup walkthrough
- `docs/PATTERN-LIBRARY.md` — full rewrite; removed Render and Supabase
  patterns, added Cloud Run + Neon + GCP IAM patterns
- `docs/EPHEMERAL-PR-ENVIRONMENTS.md` — rewritten for the Cloud Run
  revision tagging + Neon branching architecture

### Project Config

- `CLAUDE.md` — Database field changed from Supabase to Neon; platform
  field added; Pattern Library description updated
- `README.md` — repositioned as the "GCP Edition" with clear pointer to
  upstream for non-GCP users

## Unchanged Files (Should Track Upstream)

These files are platform-agnostic and should be synced from upstream when
the framework updates:

- `.claude/agents/agile-backlog-prioritizer.md`
- `.claude/agents/agile-product-manager.md`
- `.claude/agents/pr-reviewer.md`
- `.claude/agents/quality-engineer.md`
- `.claude/commands/*` (except `doctor.md`)
- `.claude/hooks/*`
- `.claude/skills/*`
- `.claude/settings.template.json`
- `docs/AGENT-*.md`
- `docs/AGENTIC-CONTROLS.md`
- `docs/ARTIFACT-FLOW.md`
- `docs/BRANCHING-STRATEGY.md`
- `docs/CI-CD-GUIDE.md` (review — may have Render-specific sections)
- `docs/CONTEXT-OPTIMIZATIONS.md`
- `docs/FAQ.md`
- `docs/GETTING-STARTED.md`
- `docs/MAINTENANCE.md`
- `docs/MEMORY-ARCHITECTURE.md`
- `docs/SENTRY-SETUP.md`
- `docs/TICKET-FORMAT.md`
- `scripts/doctor.sh`
- `scripts/hooks/*`
- `scripts/setup-accounts.sh`
- `scripts/template-sync.sh`
- `bootstrap.sh`
- `LICENSE`
- `VERSIONING.md`

## Sync Procedure

When upstream Agile Flow releases a new version:

1. Add the upstream as a remote (one-time):
   ```bash
   git remote add upstream https://github.com/vibeacademy/agile-flow.git
   ```

2. Fetch and review the diff:
   ```bash
   git fetch upstream main
   git log --oneline b9bd5e3..upstream/main
   ```

3. For each commit, decide:
   - **Framework fix** (agent prompt, command, utility) → cherry-pick or merge
   - **Render/Supabase-specific** → skip or adapt

4. Cherry-pick the safe ones:
   ```bash
   git cherry-pick COMMIT_SHA
   ```

5. For commits that touch files in the "Changed Files" list above, do a
   manual merge — the upstream changes may conflict with GCP-specific
   rewrites.

6. Update the "Source Commit" line at the top of this file to the new
   upstream commit you synced to.

7. Smoke test: create a throwaway repo from the updated template and
   verify it still deploys cleanly to a test GCP project.

## License

Inherits the upstream BSL 1.1 license. See `LICENSE` for full terms.
