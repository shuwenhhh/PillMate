import json

from openai import AsyncOpenAI

from ..config import settings
from ..policy import (
    DISCLAIMER,
    SAFETY_INSTRUCTIONS,
    classify_request_text,
    contains_medical_advice,
    refusal_response,
    safety_escalation_response,
)
from ..schemas import (
    AssistantNarrative,
    AssistantRequest,
    AssistantResponse,
    OpenAIAssistantOutput,
)
from .record_summary import summarize_records
from .safety_service import SafetyService


class AssistantService:
    def __init__(self, client: AsyncOpenAI | None = None):
        self.client = client or AsyncOpenAI(api_key=settings.openai_api_key)
        self.safety = SafetyService(self.client)

    async def generate(self, request: AssistantRequest) -> AssistantResponse:
        request_payload = request.model_dump(mode="json")
        moderation_text = SafetyService.request_text(request_payload)

        input_flagged = await self.safety.is_flagged(moderation_text)
        request_disposition = classify_request_text(moderation_text)
        if request_disposition == "safety_escalation":
            return safety_escalation_response(request.language)
        if request_disposition == "refusal":
            return refusal_response()
        if input_flagged:
            return refusal_response("I can't process this request, but I can summarize non-sensitive record patterns.")

        deterministic_summary = summarize_records(request)
        model_payload = {
            "requestId": request.request_id,
            "questionType": request.question_type.value,
            "userQuestion": request.user_question,
            "language": request.language,
            "deterministicSummary": deterministic_summary.model_dump(mode="json", by_alias=True),
            "calculationRule": "Use only the supplied deterministic evidence. Do not calculate or infer statistics.",
        }
        response = await self.client.responses.parse(
            model=settings.openai_model,
            instructions=SAFETY_INSTRUCTIONS,
            input=json.dumps(model_payload, ensure_ascii=False),
            text_format=OpenAIAssistantOutput,
            store=False,
        )

        parsed = response.output_parsed
        if parsed is None:
            return refusal_response()

        narrative = AssistantNarrative.model_validate(parsed.model_dump(mode="python"))

        output_payload = narrative.model_dump(mode="json")
        output_text = SafetyService.output_text(output_payload)
        output_flagged = await self.safety.is_flagged(output_text)
        output_disposition = classify_request_text(output_text)
        if output_disposition == "safety_escalation":
            return safety_escalation_response(request.language)
        if output_flagged or contains_medical_advice(output_text):
            return refusal_response()

        # The model cannot author refusal or emergency copy. Those sensitive responses
        # are replaced by short, deterministic server messages.
        if narrative.status == "refusal":
            return refusal_response()
        if narrative.status == "safety_escalation":
            return safety_escalation_response(request.language)

        allowed_evidence_ids = {item.id for item in deterministic_summary.evidence}
        if any(
            evidence_id not in allowed_evidence_ids
            for observation in narrative.observations
            for evidence_id in observation.evidence_ids
        ):
            return refusal_response("I couldn't verify the evidence for that summary, so I did not show it.")

        # The disclaimer is enforced server-side even if a model omits or changes it.
        return AssistantResponse.model_validate(
            {
                **narrative.model_dump(mode="python"),
                "disclaimer": DISCLAIMER,
                "evidence": deterministic_summary.evidence,
            }
        )
