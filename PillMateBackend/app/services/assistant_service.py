import json

from openai import AsyncOpenAI

from ..config import settings
from ..policy import DISCLAIMER, SAFETY_INSTRUCTIONS, contains_medical_advice, refusal_response
from ..schemas import AssistantRequest, AssistantResponse
from .safety_service import SafetyService


class AssistantService:
    def __init__(self, client: AsyncOpenAI | None = None):
        self.client = client or AsyncOpenAI(api_key=settings.openai_api_key)
        self.safety = SafetyService(self.client)

    async def generate(self, request: AssistantRequest) -> AssistantResponse:
        payload = request.model_dump(mode="json")
        moderation_text = self.safety.request_text(payload)

        if await self.safety.is_flagged(moderation_text):
            return refusal_response("I can't process this request, but I can summarize non-sensitive record patterns.")

        response = await self.client.responses.parse(
            model=settings.openai_model,
            instructions=SAFETY_INSTRUCTIONS,
            input=json.dumps(payload, ensure_ascii=False),
            text_format=AssistantResponse,
            store=False,
        )

        parsed = response.output_parsed
        if parsed is None:
            return refusal_response()

        output_text = json.dumps(parsed.model_dump(mode="json"), ensure_ascii=False)
        if await self.safety.is_flagged(output_text) or contains_medical_advice(output_text):
            return refusal_response()

        allowed_evidence_ids = {
            event.id for event in request.medication_events
        } | {
            entry.id for entry in request.journal_entries
        }
        if any(
            evidence_id not in allowed_evidence_ids
            for observation in parsed.observations
            for evidence_id in observation.evidence_ids
        ):
            return refusal_response("I couldn't verify the evidence for that summary, so I did not show it.")

        # The disclaimer is enforced server-side even if a model omits or changes it.
        return parsed.model_copy(update={"disclaimer": DISCLAIMER})
