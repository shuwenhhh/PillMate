from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    openai_api_key: str | None = None
    openai_model: str = "gpt-5.6-terra"
    # Record summaries already receive deterministic facts, so extra reasoning
    # adds latency and consumes the structured-output budget without improving
    # the calculation.
    openai_reasoning_effort: Literal["none", "low", "medium", "high", "xhigh", "max"] = "none"
    openai_moderation_model: str = "omni-moderation-latest"
    openai_request_timeout_seconds: float = Field(default=20, ge=1, le=120)
    openai_max_retries: int = Field(default=1, ge=0, le=3)
    # The model emits only a short, schema-validated summary. Keeping this
    # budget small reduces both latency and timeout risk.
    openai_max_output_tokens: int = Field(default=320, ge=64, le=4096)
    apple_client_id: str | None = None
    apple_issuer: str = "https://appleid.apple.com"
    apple_jwks_url: str = "https://appleid.apple.com/auth/keys"
    apple_jwks_cache_seconds: int = Field(default=3600, ge=60, le=86400)
    per_user_requests_per_minute: int = Field(default=5, ge=1, le=1000)
    per_user_daily_request_limit: int = Field(default=50, ge=1, le=100000)
    allowed_origins: str = "http://localhost:3000"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def origins(self) -> list[str]:
        return [origin.strip() for origin in self.allowed_origins.split(",") if origin.strip()]


settings = Settings()
