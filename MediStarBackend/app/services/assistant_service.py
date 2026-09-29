import json
import logging
import re
import time

from openai import AsyncOpenAI
from pydantic import ValidationError

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
    AssistantRequest,
    AssistantResponse,
    OpenAIAssistantOutput,
    QuestionType,
)
from .model_context import (
    build_after_dose_vitals_table,
    build_check_in_timing_table,
    build_doctor_summary_table,
    build_model_facts,
)
from .record_summary import summarize_records
from .safety_service import SafetyService


performance_logger = logging.getLogger("medistar.request")


class AssistantService:
    def __init__(self, client: AsyncOpenAI | None = None):
        self.client = client or AsyncOpenAI(
            api_key=settings.openai_api_key,
            timeout=settings.openai_request_timeout_seconds,
            max_retries=settings.openai_max_retries,
        )
        self.safety = SafetyService(self.client)

    @staticmethod
    def _reasoning_effort() -> str:
        """Keep an older model from receiving an unsupported effort value."""

        model = settings.openai_model.casefold()
        if settings.openai_reasoning_effort == "none" and (
            model == "gpt-5-mini" or model.startswith("gpt-5-mini-")
        ):
            return "minimal"
        return settings.openai_reasoning_effort

    @staticmethod
    def _is_simple_greeting(text: str) -> bool:
        normalized = re.sub(r"[^\w\u4e00-\u9fff]+", "", text.casefold())
        return normalized in {
            "hi",
            "hii",
            "hiii",
            "hello",
            "hey",
            "你好",
            "您好",
            "嗨",
        }

    @staticmethod
    def _wants_after_dose_vitals_table(request: AssistantRequest) -> bool:
        if request.question_type is QuestionType.vitals:
            return True
        if request.question_type is not QuestionType.free_text:
            return False
        normalized = " ".join(request.user_question.casefold().replace("-", " ").split())
        return any(term in normalized for term in ("vitals", "heart rate", "blood pressure"))

    @staticmethod
    def _wants_check_in_timing_table(request: AssistantRequest) -> bool:
        if request.question_type is QuestionType.consistency:
            return True
        if request.question_type is not QuestionType.free_text:
            return False
        normalized = " ".join(request.user_question.casefold().replace("-", " ").split())
        return any(
            term in normalized
            for term in ("check in", "on time", "taken late", "taken early", "forgot")
        )

    async def generate(self, request: AssistantRequest) -> AssistantResponse:
        pipeline_started_at = time.perf_counter()
        moderation_ms = 0.0
        # Resolve the common local safety cases before making any network request.
        request_disposition = classify_request_text(request.user_question)
        if request_disposition == "safety_escalation":
            return safety_escalation_response(request.language)
        if request_disposition == "refusal":
            return refusal_response()

        # Preset questions are controlled by the app and contain no arbitrary user
        # prose, so a separate moderation round-trip would only add latency. Free
        # text still receives remote moderation, but only the question is sent—not
        # the user's full health-record payload.
        if (
            request.question_type is QuestionType.free_text
            and not self._is_simple_greeting(request.user_question)
        ):
            moderation_started_at = time.perf_counter()
            input_flagged = await self.safety.is_flagged(request.user_question)
            moderation_ms = (time.perf_counter() - moderation_started_at) * 1000
            if input_flagged:
                return refusal_response(
                    "I can't process this request, but I can summarize non-sensitive record patterns."
                )

        preparation_started_at = time.perf_counter()
        deterministic_summary = summarize_records(request)

        model_payload = {
            "requestId": request.request_id,
            "questionType": request.question_type.value,
            "userQuestion": request.user_question,
            "language": request.language,
            # Counts, dose links, and ranges are calculated once on the server.
            # The model receives one compact source of truth instead of the same
            # records twice in raw and evidence form.
            "recordFacts": build_model_facts(request, deterministic_summary),
            "calculationRule": "Use only recordFacts. Do not calculate or infer new statistics.",
        }
        model_input = json.dumps(model_payload, ensure_ascii=False)
        preparation_ms = (time.perf_counter() - preparation_started_at) * 1000
        generation_started_at = time.perf_counter()
        try:
            try:
                response = await self.client.responses.parse(
                    model=settings.openai_model,
                    instructions=SAFETY_INSTRUCTIONS,
                    input=model_input,
                    text_format=OpenAIAssistantOutput,
                    reasoning={"effort": self._reasoning_effort()},
                    max_output_tokens=settings.openai_max_output_tokens,
                    store=False,
                )
            finally:
                performance_logger.info(
                    json.dumps(
                        {
                            "phase": "ai_pipeline",
                            "request_id": request.request_id,
                            "question_type": request.question_type.value,
                            "model": settings.openai_model,
                            "input_bytes": len(model_input.encode("utf-8")),
                            "moderation_ms": round(moderation_ms, 2),
                            "record_preparation_ms": round(preparation_ms, 2),
                            "generation_ms": round(
                                (time.perf_counter() - generation_started_at) * 1000,
                                2,
                            ),
                            "pipeline_ms": round(
                                (time.perf_counter() - pipeline_started_at) * 1000,
                                2,
                            ),
                        },
                        separators=(",", ":"),
                        sort_keys=True,
                    )
                )
        except ValidationError:
            return AssistantResponse(
                status="needs_clarification",
                summary=(
                    "I couldn't read the AI response this time. "
                    "Please try again in a moment."
                ),
                observations=[],
                follow_up_questions=[],
                disclaimer=DISCLAIMER,
                evidence=[],
            )

        parsed = response.output_parsed
        if parsed is None:
            return refusal_response()

        summary = self._without_embedded_disclaimer(parsed.summary)

        # The response schema contains only one short summary. A local policy
        # check avoids a second remote moderation round-trip on every request.
        output_disposition = classify_request_text(summary)
        if output_disposition == "safety_escalation":
            return safety_escalation_response(request.language)
        if contains_medical_advice(summary):
            return refusal_response()

        # The disclaimer is enforced server-side even if a model omits or changes it.
        return AssistantResponse(
            status="ok",
            summary=summary,
            observations=[],
            follow_up_questions=[],
            disclaimer=DISCLAIMER,
            evidence=deterministic_summary.evidence,
            doctor_summary_table=(
                build_doctor_summary_table(request, deterministic_summary)
                if request.question_type is QuestionType.doctor_summary
                else None
            ),
            after_dose_vitals_table=(
                build_after_dose_vitals_table(request, deterministic_summary)
                if self._wants_after_dose_vitals_table(request)
                else None
            ),
            check_in_timing_table=(
                build_check_in_timing_table(request)
                if self._wants_check_in_timing_table(request)
                else None
            ),
        )

    @staticmethod
    def _without_embedded_disclaimer(summary: str) -> str:
        """Remove a model-repeated disclaimer before output safety classification.

        The server adds the disclaimer in a dedicated UI field. If a model repeats
        it inside the answer, the words “diagnosis” and “treatment” must not be
        mistaken for medical advice.
        """

        without_disclaimer = re.sub(re.escape(DISCLAIMER), "", summary, flags=re.IGNORECASE)
        normalized = " ".join(without_disclaimer.split())
        if without_disclaimer != summary:
            normalized = normalized.strip(" —–-.")
        return normalized or "Here is a summary of the selected records."
