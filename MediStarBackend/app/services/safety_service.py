import json

from openai import AsyncOpenAI

from ..config import settings


class SafetyService:
    def __init__(self, client: AsyncOpenAI | None = None):
        self.client = client or AsyncOpenAI(
            api_key=settings.openai_api_key,
            timeout=settings.openai_request_timeout_seconds,
            max_retries=settings.openai_max_retries,
        )

    async def is_flagged(self, text: str) -> bool:
        result = await self.client.moderations.create(
            model=settings.openai_moderation_model,
            input=text,
        )
        if not result.results:
            raise RuntimeError("moderation response did not include a result")
        return bool(result.results[0].flagged)

    @staticmethod
    def request_text(payload: dict) -> str:
        # Keep moderation input deterministic and avoid logging this string.
        return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))

    @staticmethod
    def output_text(payload: dict) -> str:
        # The model's disclaimer is ignored and replaced server-side, so it is not part
        # of the generated content safety decision.
        moderated_payload = {key: value for key, value in payload.items() if key != "disclaimer"}
        return json.dumps(moderated_payload, ensure_ascii=False, separators=(",", ":"))
