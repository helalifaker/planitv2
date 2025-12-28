"""Application settings using Pydantic Settings."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application configuration loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Application
    app_name: str = "Plan-It"
    app_version: str = "0.1.0"
    debug: bool = False
    environment: str = "development"

    # API
    api_v1_prefix: str = "/api/v1"

    # Database
    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/planit"

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # Security
    secret_key: str = "change-me-in-production"
    access_token_expire_minutes: int = 30
    algorithm: str = "HS256"

    # CORS
    allowed_origins: list[str] = ["http://localhost:3000"]


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
