"""Health check endpoint.

Cloud Run uses this for container readiness checks. The preview-deploy
workflow also hits this as the smoke test.
"""

from fastapi import APIRouter
from fastapi.responses import JSONResponse

router = APIRouter()


@router.get("/api/health")
async def health() -> JSONResponse:
    """Return 200 with a small JSON body.

    Deliberately does NOT touch the database — health checks must be
    fast and not wake up the Neon compute endpoint on every probe.
    """
    return JSONResponse({"status": "ok"})
