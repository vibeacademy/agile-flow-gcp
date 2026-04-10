"""Runtime configuration.

All env vars are read at runtime — FastAPI has no build-time env var baking
like Next.js, so this just works with `gcloud run deploy --set-env-vars`
or Cloud Run Secret Manager mounts.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """App settings loaded from environment variables."""

    database_url: str = "sqlite:///./dev.db"
    app_url: str = "http://localhost:8080"
    environment: str = "development"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    """Cached settings accessor.

    Uses lru_cache so settings are loaded exactly once per process.
    Tests can override this via dependency injection.
    """
    return Settings()
