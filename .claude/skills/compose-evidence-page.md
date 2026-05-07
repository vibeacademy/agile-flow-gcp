---
name: compose-evidence-page
description: Turn a ticket's acceptance criteria into proposed EvidenceSection probes for app/evidence.py. Use during ticket implementation, before opening the PR, so the worker can edit app/evidence.py with sections that match the AC.
---

# Compose Evidence Page Skill

Take a ticket's acceptance criteria and propose one `EvidenceSection`
per AC, suitable for appending to `SECTIONS` in `app/evidence.py`.

The output of this skill is a Python snippet the worker pastes into
`app/evidence.py`, plus a brief reviewer-facing rationale block. The
worker then refines the probes against the actual implementation.

See [`docs/EVIDENCE-PAGES.md`](../../docs/EVIDENCE-PAGES.md) for the
model and probe rules.

---

## Inputs

You need three things to compose a section:

1. **The ticket's acceptance criteria** — the bulleted list under
   "Definition of Done" or "Acceptance Criteria" in the ticket body.
2. **The implementation diff so far** — what files the worker is
   touching, especially migrations, models, and route handlers.
3. **The reviewer's perspective** — assume they cannot read code.
   They can click links, submit forms, and read prose.

If any of these is missing, ask the user before proposing sections.
A section composed without seeing the diff will probe the wrong thing.

---

## Process

### 1. Map AC to probe shape

For each acceptance criterion, classify it into one of these probe
shapes — they cover ~95% of tickets on this stack.

| AC type | Probe shape | Example |
|---------|-------------|---------|
| Schema change | Compare DB columns to expected list via `inspect(engine)` | "users table has `email_verified_at` column with type timestamp" |
| Read path | `session.exec(select(Model))` returns without error | "wishlist items are queryable" |
| Write path (with rollback) | `SAVEPOINT` → INSERT → SELECT → ROLLBACK TO SAVEPOINT | "a wishlist item with a due_date round-trips" |
| Endpoint exists | The probe is the live request — but the worker tests this in a smoke test, not the page | (skip — handled by tests) |
| Config / env var present | Read `ctx.settings.X` and assert non-empty | "STRIPE_PUBLISHABLE_KEY is configured on this revision" |
| Migration head matches | Already covered by the framework starter probe | (skip — already in SECTIONS) |

If an AC doesn't fit any of these shapes, default to "describe what the
reviewer should look for on the page" with `passed=True` and an
observation pointing to the manual step. Don't fake green probes.

### 2. Write reviewer-targeted explanations

Each section's `explanation` field gets shown to a non-technical
reviewer. Compare:

- Avoid (engineer-targeted): "the `email_verified_at` column was added
  per migration `7a8b9c`."
- Do this (reviewer-targeted): "If you can sign up, click the link in
  your verification email, and see your account flip to verified, the
  email-verification feature works in this preview the same way it
  will in production."

Test: would a workshop attendee's product owner — who does not read
Python — understand what "green" tells them? If not, rewrite.

### 3. Avoid common probe mistakes

- **Probes must be read-only by default.** The throwaway `due_date`
  round-trip in productowner#3 is a deliberate exception (SAVEPOINT +
  ROLLBACK). Production probes should not copy that pattern unless the
  ticket genuinely requires write-path evidence.
- **Probes run on every page load.** Sub-second only. No N+1 scans.
- **Probes use the live ORM/session.** Don't shell out, don't HTTP-call
  the same app, don't read filesystem state — those don't prove
  anything about the database the deploy is actually using.
- **Probes report failure as evidence, not as a crash.** Catch
  expected exceptions and produce a useful observation; let the
  runner catch unexpected ones.

### 4. Output format

Produce a code block ready to paste into `app/evidence.py`:

```python
def _probe_<short_name>(ctx: ProbeContext) -> ProbeResult:
    """One-line summary."""
    # implementation
    return ProbeResult(passed=..., observation=...)


SECTIONS.append(
    EvidenceSection(
        name="<short reviewer-facing title>",
        explanation=(
            "Reviewer-targeted prose. If green, X is real in the "
            "production-shaped database. If red, the probe will tell "
            "you which step failed."
        ),
        probe=_probe_<short_name>,
    )
)
```

If the worker has multiple ACs, emit one block per AC and a final
checklist mapping each AC to the section that proves it.

---

## Worked example

**Ticket AC (paraphrased from a hypothetical #200):**

- [ ] `users` table has `email_verified_at: datetime | None` column
- [ ] Sign-up sends a verification email containing a link
- [ ] Clicking the link sets `email_verified_at` for that user
- [ ] Unverified users see a banner on the home page

**Composed sections (worker pastes these into `app/evidence.py`):**

```python
def _probe_users_has_email_verified_at(ctx: ProbeContext) -> ProbeResult:
    """The new column exists with the expected type."""
    from sqlalchemy import inspect

    inspector = inspect(ctx.session.get_bind())
    cols = {c["name"]: c for c in inspector.get_columns("users")}
    col = cols.get("email_verified_at")
    if col is None:
        return ProbeResult(False, "users.email_verified_at column is missing.")
    type_name = col["type"].__class__.__name__.lower()
    if "datetime" not in type_name and "timestamp" not in type_name:
        return ProbeResult(
            False,
            f"users.email_verified_at exists but type is {type_name!r}; expected datetime/timestamp.",
        )
    return ProbeResult(
        True,
        "users.email_verified_at column exists with a timestamp type.",
    )


SECTIONS.append(
    EvidenceSection(
        name="The verified-at column exists in the database",
        explanation=(
            "If green, the production-shaped database has a column where "
            "the verification timestamp can be stored. The next sections "
            "prove that column actually gets written and read by the app."
        ),
        probe=_probe_users_has_email_verified_at,
    )
)
```

(...repeat for each AC. Email-send and link-click probes are described
as manual-verification sections with reviewer-facing explanations,
since the page can't simulate clicking a link in an email.)

**Reviewer-facing checklist appended to the PR description:**

- [ ] AC1 (column exists) → "The verified-at column exists in the database"
- [ ] AC2 (email sent) → manual verification: sign up on preview, check inbox
- [ ] AC3 (link sets timestamp) → manual verification: click link, refresh page
- [ ] AC4 (banner) → manual verification: reload preview as unverified user

---

## Hand-off back to the worker agent

After you propose sections, the worker:

1. Pastes them into `app/evidence.py` (refining as the implementation
   lands).
2. Runs `uv run pytest tests/test_evidence.py` — the runner-shape
   tests stay green automatically; the new probes only run live.
3. Pushes the branch, waits for preview deploy.
4. Hits `/healthz/evidence` on the preview URL. Per
   `.claude/agents/github-ticket-worker.md`, the worker gets
   exactly one repair attempt before posting a handoff comment.
