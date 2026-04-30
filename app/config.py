"""Runtime configuration.

All env vars are read at runtime — FastAPI has no build-time env var baking
like Next.js, so this just works with `gcloud run deploy --set-env-vars`
or Cloud Run Secret Manager mounts.
"""

from functools import lru_cache
from typing import Self

from pydantic import field_validator, model_validator
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

    @field_validator("database_url")
    @classmethod
    def _force_psycopg3_driver(cls, v: str) -> str:
        # Neon emits postgresql:// URLs, which SQLAlchemy resolves to the
        # psycopg2 driver. We ship psycopg3 only, so rewrite the scheme.
        if v.startswith("postgresql://"):
            return v.replace("postgresql://", "postgresql+psycopg://", 1)
        return v

    @model_validator(mode="after")
    def _refuse_sqlite_in_production(self) -> Self:
        # Defense-in-depth: the dev-default sqlite URL must never reach
        # a production runtime. If the secret-mounted DATABASE_URL is
        # missing or the mount didn't override the default, fail at
        # startup with a clear message rather than 500ing on the first
        # DB query with `no such table: todo`. See #63 / #71.
        if self.environment != "production":
            return self
        if not self.database_url:
            raise ValueError(
                "DATABASE_URL is empty in production. "
                "Check that the Secret Manager secret 'database-url' is "
                "mounted in deploy.yml and the Cloud Run service has "
                "secretAccessor on it."
            )
        if self.database_url.startswith("sqlite"):
            raise ValueError(
                f"DATABASE_URL is SQLite in production: {self.database_url!r}. "
                "Production must use Postgres. Likely cause: the secret-mounted "
                "DATABASE_URL env var didn't override the dev default."
            )
        return self


@lru_cache
def get_settings() -> Settings:
    """Cached settings accessor.

    Uses lru_cache so settings are loaded exactly once per process.
    Tests can override this via dependency injection.
    """
    return Settings()
