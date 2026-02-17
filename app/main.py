import os

import sentry_sdk
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

sentry_dsn = os.getenv("SENTRY_DSN")
if sentry_dsn:
    sentry_sdk.init(dsn=sentry_dsn, traces_sample_rate=1.0)

app = FastAPI(title="Agile Flow Starter")
templates = Jinja2Templates(directory=os.path.join(os.path.dirname(__file__), "templates"))


@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    return templates.TemplateResponse(request, "index.html")


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/error")
async def error():
    raise RuntimeError(
        "Deliberate error for Day 1 workshop exercise — this should appear in Sentry and auto-create a GitHub issue."
    )
