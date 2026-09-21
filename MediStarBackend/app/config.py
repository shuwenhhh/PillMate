from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    openai_api_key: str | None = None
    openai_model: str = "gpt-5-mini"
    openai_moderation_model: str = "omni-moderation-latest"
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
