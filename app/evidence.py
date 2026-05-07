"""Per-PR evidence sections shown on preview deploys at `/`.

The point of this file: when a reviewer opens the preview URL for a PR,
they see a page that says — for each acceptance criterion of the ticket —
whether the worker actually did the work correctly, against the
production-shaped infrastructure. Reviewer reads prose, sees pass/fail,
optionally re-verifies by clicking around. Reviewer does not need to read
code to decide whether to merge.

The worker is expected to **edit this file on every PR**:

  - Add one `EvidenceSection` per acceptance criterion.
  - Probe must run live against the deploy's database and config —
    that is the only way the page proves anything about production.
  - Explanation prose is for the reviewer, not the engineer:
    "If green, the new email_verified_at column round-trips."
    NOT "the column was added per the migration."

Probes must:
  - Be read-only — every reviewer page-load runs them.
  - Be fast — sub-second; this page is not for expensive checks.
  - Use the ORM or SQLAlchemy `text(...)` so they work on PostgreSQL
    (production and preview both run Postgres via Neon).
  - Treat their own failures as evidence — a probe that crashes is
    automatically reported as failed by `evaluate_sections`.

See `docs/EVIDENCE-PAGES.md` for the model and the `compose-evidence-page`
skill for how to turn a ticket's acceptance criteria into sections.

This module is imported only when `ENVIRONMENT=preview`, so importing it
in production code is a bug.
"""

from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from sqlmodel import Session, select

from app.config import Settings


@dataclass(frozen=True)
class ProbeContext:
    """Inputs every probe receives.

    Adding a field here is fine; renaming or removing one is a breaking
    change for every probe in this file.
    """

    session: Session
    settings: Settings


@dataclass(frozen=True)
class ProbeResult:
    """What a probe tells the runner."""

    passed: bool
    observation: str


@dataclass(frozen=True)
class EvidenceSection:
    """One unit of evidence the reviewer reads.

    name: short title shown at the top of the section.
    explanation: reviewer-targeted prose. "If green, X is real. If red, Y."
    probe: callable that runs live against the deploy and returns a result.
    """

    name: str
    explanation: str
    probe: Callable[[ProbeContext], ProbeResult]


# --- Probes for the framework's starter sections ---------------------------


def _probe_preview_matches_production_shape(ctx: ProbeContext) -> ProbeResult:
    """Combined check that the preview is wired the way production is.

    All three sub-checks must pass. Any one failure means the page below
    cannot be trusted to tell you anything about production behavior.
    """
    failures: list[str] = []

    if ctx.settings.environment != "preview":
        failures.append(
            f"ENVIRONMENT={ctx.settings.environment!r}, expected 'preview' "
            "(this page should not have rendered at all if that flag isn't set)"
        )

    bind = ctx.session.get_bind()
    dialect = bind.dialect.name
    if dialect != "postgresql":
        failures.append(
            f"database is {dialect!r}, expected 'postgresql' "
            "(production runs on Neon-hosted PostgreSQL — this preview is on a different engine)"
        )

    # Compare current DB head to the latest migration in code.
    from alembic.config import Config
    from alembic.runtime.migration import MigrationContext
    from alembic.script import ScriptDirectory

    alembic_ini = Path(__file__).parent.parent / "alembic.ini"
    cfg = Config(str(alembic_ini))
    code_head = ScriptDirectory.from_config(cfg).get_current_head()
    db_head = MigrationContext.configure(ctx.session.connection()).get_current_revision()
    if db_head != code_head:
        failures.append(
            f"database is at migration {db_head!r}; code expects {code_head!r} "
            "(migrations did not run before this revision started serving)"
        )

    if failures:
        return ProbeResult(False, "Mismatch: " + "; ".join(failures) + ".")
    return ProbeResult(
        True,
        f"ENVIRONMENT=preview, database is PostgreSQL, schema is at migration {code_head}.",
    )


def _probe_todos_read_path_works(ctx: ProbeContext) -> ProbeResult:
    """Read the todos table to confirm the read path is alive on this deploy.

    This is a read-only probe — no inserts, no deletes, runs on every page load.
    Imported lazily so the framework infra section can fail informatively
    even if the model module breaks.
    """
    from app.models.todo import Todo

    rows = ctx.session.exec(select(Todo)).all()
    return ProbeResult(
        True,
        f"Todos table is queryable on this deploy (currently has {len(rows)} row(s)).",
    )


# --- The list of sections shown on the page --------------------------------
#
# Workers append to this list per PR. Order is the order the reviewer reads
# them; put prerequisite/sanity sections first, feature evidence after.

SECTIONS: list[EvidenceSection] = [
    EvidenceSection(
        name="Preview is wired the same way production is",
        explanation=(
            "Production runs on Cloud Run with a Neon-hosted PostgreSQL "
            "database and an Alembic-managed schema. This section checks "
            "all three on this preview revision. If it is red, the preview "
            "is misconfigured and nothing else on this page tells you "
            "anything reliable about whether the change will work in production."
        ),
        probe=_probe_preview_matches_production_shape,
    ),
    EvidenceSection(
        name="The todo list is reachable through the database",
        explanation=(
            "Reads the todos table from the database. If green, the read "
            "path is live: connection works, schema has the table the code "
            "expects, ORM is wired correctly. This is the framework's "
            "starter section, demonstrating the shape attendees copy when "
            "they add one section per acceptance criterion in their PRs."
        ),
        probe=_probe_todos_read_path_works,
    ),
]


# --- Runner ----------------------------------------------------------------


def evaluate_sections(ctx: ProbeContext) -> list[dict]:
    """Run every probe and return a serializable result list.

    A probe that raises is reported as failed with the exception class and
    message in the observation — probes should generally not raise (they
    should catch their own errors and produce a reviewer-targeted message),
    but a crash here is treated as evidence-of-failure rather than swallowed.
    """
    results: list[dict] = []
    for section in SECTIONS:
        try:
            outcome = section.probe(ctx)
            results.append(
                {
                    "name": section.name,
                    "passed": outcome.passed,
                    "observation": outcome.observation,
                    "explanation": section.explanation,
                }
            )
        except Exception as exc:
            results.append(
                {
                    "name": section.name,
                    "passed": False,
                    "observation": f"Probe crashed: {type(exc).__name__}: {exc}",
                    "explanation": section.explanation,
                }
            )
    return results
