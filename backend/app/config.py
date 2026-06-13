import os
from typing import List

from pydantic import AnyHttpUrl, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    DATABASE_URL: str
    R2_ENDPOINT: AnyHttpUrl
    # For Flutter or any client; you can override with comma-separated list in .env
    ALLOWED_ORIGINS: List[str] = ["*"]

    # JWT
    JWT_SECRET: str = "change-me"
    JWT_EXPIRE_MINUTES: int = 60 * 24 * 14  # 14 days

    # Upload validation
    MAX_UPLOAD_MB: int = 10
    ALLOWED_CONTENT_TYPES: List[str] = [
        "image/jpeg",
        "image/jpg",
        "image/png",
        "image/webp",
        "image/heic",
        "image/heif",
    ]

    # Load .env from the same directory as this file: app/.env
    model_config = SettingsConfigDict(
        env_file=os.path.join(os.path.dirname(__file__), ".env"),
        env_file_encoding="utf-8",
    )

    @field_validator("ALLOWED_ORIGINS", mode="before")
    @classmethod
    def _parse_allowed_origins(cls, v):
        if isinstance(v, str):
            if v.strip() == "*":
                return ["*"]
            return [s.strip() for s in v.split(",") if s.strip()]
        return v


settings = Settings()
