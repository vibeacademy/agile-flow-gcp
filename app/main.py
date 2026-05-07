"""FastAPI application entrypoint.

Run locally:
    uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8080

Production (Cloud Run) runs the same command — see Dockerfile.
"""

from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.api import health, todos
from app.config import Settings, get_settings


def create_app(settings: Settings | None = None) -> FastAPI:
    """Build the FastAPI app, mounting preview-only routes when applicable.

    The evidence page (`/`) and `/healthz/evidence` are only mounted when
    `ENVIRONMENT=preview`. The decision is made once at startup, not per
    request, so accidental leakage to production is a deploy-time
    misconfiguration (catchable by smoke tests) rather than a runtime
    code-path bug. See docs/EVIDENCE-PAGES.md.

    `settings` is injectable so tests can build apps in a specific
    environment without round-tripping through env vars + lru_cache.
    """
    if settings is None:
        settings = get_settings()
    fastapi_app = FastAPI(title="Agile Flow GCP")

    # Pico.css is loaded via CDN in base.html so this directory is light.
    static_dir = Path(__file__).parent.parent / "static"
    fastapi_app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")

    if settings.environment == "preview":
        from app.api import evidence

        # Registered first so its `/` claims the home route ahead of `todos.router`.
        fastapi_app.include_router(evidence.router)

    fastapi_app.include_router(health.router)
    fastapi_app.include_router(todos.router)
    return fastapi_app


app = create_app()
