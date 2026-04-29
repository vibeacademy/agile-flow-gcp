"""Tests for app.config.Settings.

Pins the contract that database_url is normalized to use the psycopg3
driver scheme. SQLAlchemy resolves the bare `postgresql://` scheme to
psycopg2 (not installed in this project), so without normalization
every Neon-backed deploy would ImportError on first DB use.
"""

import pytest


def _make_settings(database_url: str | None = None):
    # Import inside the helper so each call sees the patched env. The
    # @lru_cache on get_settings is process-level; we instantiate
    # Settings() directly to bypass it.
    from app.config import Settings

    if database_url is None:
        return Settings()
    return Settings(database_url=database_url)


@pytest.mark.parametrize(
    "input_url,expected",
    [
        # The live-bug case: Neon emits postgresql://, must become postgresql+psycopg://
        (
            "postgresql://u:p@h/db",
            "postgresql+psycopg://u:p@h/db",
        ),
        # Already-normalized URLs pass through unchanged
        (
            "postgresql+psycopg://u:p@h/db",
            "postgresql+psycopg://u:p@h/db",
        ),
        # Non-postgres schemes are untouched
        ("sqlite:///./dev.db", "sqlite:///./dev.db"),
        ("sqlite://", "sqlite://"),
        # Only the scheme is rewritten; query string + path preserved
        (
            "postgresql://user:pa%40ss@host:5432/db?sslmode=require",
            "postgresql+psycopg://user:pa%40ss@host:5432/db?sslmode=require",
        ),
    ],
)
def test_database_url_scheme_normalization(input_url: str, expected: str) -> None:
    assert _make_settings(input_url).database_url == expected
