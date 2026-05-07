"""Preview-only evidence routes.

This module is included in the FastAPI app **only when ENVIRONMENT=preview**
(see app/main.py). Production never imports it — keeping the import there
guarded means a code-path mistake in this module cannot affect production.

Two endpoints:

`/` — HTML page the human reviewer reads. Each section answers
"did the worker do this acceptance criterion correctly?" with prose and
a pass/fail signal.

`/healthz/evidence` — JSON view of the same data, used by the worker
agent to auto-verify after PR creation. Stable shape:

    {
      "passed": bool,
      "sections": [
        {"name": str, "passed": bool, "observation": str, "explanation": str},
        ...
      ]
    }
"""

from typing import Annotated

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse, JSONResponse
from sqlmodel import Session

from app.config import Settings, get_settings
from app.db import get_session
from app.evidence import ProbeContext, evaluate_sections
from app.templates import templates

router = APIRouter()

SessionDep = Annotated[Session, Depends(get_session)]
SettingsDep = Annotated[Settings, Depends(get_settings)]


@router.get("/", response_class=HTMLResponse)
async def evidence_page(
    request: Request,
    session: SessionDep,
    settings: SettingsDep,
) -> HTMLResponse:
    """Render the reviewer-facing evidence page."""
    sections = evaluate_sections(ProbeContext(session=session, settings=settings))
    all_passed = all(section["passed"] for section in sections)
    return templates.TemplateResponse(
        request,
        "evidence.html",
        {"sections": sections, "all_passed": all_passed},
    )


@router.get("/healthz/evidence")
def evidence_json(
    session: SessionDep,
    settings: SettingsDep,
) -> JSONResponse:
    """Machine-readable evidence results — consumed by the worker agent."""
    sections = evaluate_sections(ProbeContext(session=session, settings=settings))
    return JSONResponse(
        {
            "passed": all(section["passed"] for section in sections),
            "sections": sections,
        }
    )
