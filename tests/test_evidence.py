"""Tests for the per-PR evidence page.

Two layers under test:

1. Router wiring — evidence routes mount only when ENVIRONMENT=preview.
   The test DB is SQLite, so the framework "preview matches production"
   probe is *expected* to report failure (different dialect) — that
   failure is itself evidence that the probe does real work, not a bug.

2. Runner contract — `evaluate_sections` returns a list of dicts with
   the documented shape, including `passed`, `observation`, `explanation`.
   This is what the worker agent consumes via /healthz/evidence.

End-to-end validation that probes work against PostgreSQL happens on the
preview deploy itself — see docs/EVIDENCE-PAGES.md.
"""

from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session

from app.config import Settings, get_settings
from app.db import get_session
from app.evidence import (
    SECTIONS,
    EvidenceSection,
    ProbeContext,
    ProbeResult,
    evaluate_sections,
)
from app.main import create_app


def _preview_settings() -> Settings:
    """Build a Settings instance flagged as preview, bypassing validators.

    Validators would refuse the SQLite default URL outside dev. Tests
    don't actually connect to Postgres — they exercise the routing and
    runner shape, so model_construct is appropriate here.
    """
    return Settings.model_construct(
        environment="preview",
        database_url="sqlite://",
        app_url="http://testserver",
    )


@pytest.fixture(name="preview_client")
def preview_client_fixture(session: Session) -> Generator[TestClient, None, None]:
    """TestClient running an app built in preview mode."""
    settings = _preview_settings()
    app = create_app(settings=settings)

    def session_override() -> Generator[Session, None, None]:
        yield session

    app.dependency_overrides[get_session] = session_override
    app.dependency_overrides[get_settings] = lambda: settings

    with TestClient(app) as client:
        yield client


# --- Router wiring --------------------------------------------------------


def test_evidence_not_mounted_in_development(client: TestClient) -> None:
    """Default-env app does not expose `/healthz/evidence`."""
    response = client.get("/healthz/evidence")
    assert response.status_code == 404


def test_root_serves_todos_in_development(client: TestClient) -> None:
    """`/` is the todos home page in non-preview environments."""
    response = client.get("/")
    assert response.status_code == 200
    # Todos home page should not contain the evidence-page banner copy.
    assert "Preview verification" not in response.text


def test_evidence_mounted_in_preview(preview_client: TestClient) -> None:
    """Preview app mounts both routes."""
    json_response = preview_client.get("/healthz/evidence")
    assert json_response.status_code == 200

    html_response = preview_client.get("/")
    assert html_response.status_code == 200
    assert "Preview verification" in html_response.text


# --- Runner contract ------------------------------------------------------


def test_evidence_json_shape(preview_client: TestClient) -> None:
    """JSON contract is what the worker agent depends on."""
    body = preview_client.get("/healthz/evidence").json()
    assert set(body.keys()) == {"passed", "sections"}
    assert isinstance(body["passed"], bool)
    assert isinstance(body["sections"], list)
    assert len(body["sections"]) == len(SECTIONS)
    for section in body["sections"]:
        assert set(section.keys()) == {"name", "passed", "observation", "explanation"}
        assert isinstance(section["passed"], bool)


def test_aggregate_passed_reflects_section_results(preview_client: TestClient) -> None:
    """Top-level `passed` is the AND of every section's `passed`."""
    body = preview_client.get("/healthz/evidence").json()
    expected = all(section["passed"] for section in body["sections"])
    assert body["passed"] is expected


def test_todos_starter_probe_passes_against_test_db(session: Session) -> None:
    """The per-feature starter probe (todos read path) succeeds when the
    schema is present — which it is in the in-memory test DB."""
    settings = _preview_settings()
    results = evaluate_sections(ProbeContext(session=session, settings=settings))

    todos_section = next(
        (r for r in results if r["name"] == "The todo list is reachable through the database"),
        None,
    )
    assert todos_section is not None
    assert todos_section["passed"] is True
    assert "queryable" in todos_section["observation"]


def test_infra_probe_reports_dialect_mismatch_against_sqlite(session: Session) -> None:
    """The infra-sanity probe is supposed to fail when the database is not
    PostgreSQL — proving it actually inspects the live connection rather
    than always returning green. This test pins that contract."""
    settings = _preview_settings()
    results = evaluate_sections(ProbeContext(session=session, settings=settings))

    infra_section = next(
        (r for r in results if r["name"] == "Preview is wired the same way production is"),
        None,
    )
    assert infra_section is not None
    assert infra_section["passed"] is False
    assert "sqlite" in infra_section["observation"]


# --- Defensive runner behavior --------------------------------------------


def test_runner_treats_probe_crash_as_failure(
    session: Session, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A probe that raises is reported as failed — never propagates."""

    def boom(_ctx: ProbeContext) -> ProbeResult:
        raise RuntimeError("probe is broken")

    crashing = EvidenceSection(
        name="Intentionally broken probe",
        explanation="Tests the runner's exception handling.",
        probe=boom,
    )
    monkeypatch.setattr("app.evidence.SECTIONS", [crashing])

    settings = _preview_settings()
    results = evaluate_sections(ProbeContext(session=session, settings=settings))

    assert len(results) == 1
    assert results[0]["passed"] is False
    assert "RuntimeError" in results[0]["observation"]
    assert "probe is broken" in results[0]["observation"]
