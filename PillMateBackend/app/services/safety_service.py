import json

from openai import AsyncOpenAI

from ..config import settings


class SafetyService:
    def __init__(self, client: AsyncOpenAI | None = None):
        self.client = client or AsyncOpenAI(api_key=settings.openai_api_key)

    async def is_flagged(self, text: str) -> bool:
        result = await self.client.moderations.create(
            model=settings.openai_moderation_model,
            input=text,
        )
        return bool(result.results and result.results[0].flagged)

    @staticmethod
    def request_text(payload: dict) -> str:
        # Keep moderation input deterministic and avoid logging this string.
        return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
