import asyncio
import json
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

import app.main as main_module
from app.config import Settings, settings
from app.main import app
from app.schemas import (
    AI_CONSENT_VERSION,
    AssistantRequest,
    AssistantResponse,
    OpenAIAssistantOutput,
    OpenAIObservation,
)
from app.services.assistant_service import AssistantService
from app.services.record_summary import summarize_records


def assistant_payload() -> dict:
    return {
        "requestId": "batch-4-request",
        "dateRange": {"start": "2026-09-14", "end": "2026-09-14"},
        "questionType": "consistency",
        "userQuestion": "Summarize the supplied records.",
        "medications": [
            {
                "id": "medicine-1",
                "name": "Example medicine",
                "dose": "10 mg",
                "timeWindow": "8:00-10:00 AM",
                "frequency": "daily",
                "isActive": True,
            }
        ],
        "medicationEvents": [
            {
                "id": "dose-1",
                "medicineId": "medicine-1",
                "recordedAt": "2026-09-14T00:00:00+08:00",
                "scheduledWindow": "8:00-10:00 AM",
                "takenAt": "9:00 AM",
            }
        ],
        "journalEntries": [],
        "language": "en-US",
        "timezone": "Asia/Shanghai",
        "consentVersion": AI_CONSENT_VERSION,
    }


class AllowAllSafety:
    def request_text(self, payload: dict) -> str:
        return json.dumps(payload)

    async def is_flagged(self, text: str) -> bool:
        return False


class RecordingResponses:
    def __init__(self, evidence_id: str):
        self.evidence_id = evidence_id
        self.parse_kwargs: dict | None = None

    async def parse(self, **kwargs):
        self.parse_kwargs = kwargs
        return SimpleNamespace(
            output_parsed=OpenAIAssistantOutput(
                status="ok",
                summary="One medication event was recorded.",
                observations=[
                    OpenAIObservation(
                        text="One dose was recorded in the selected period.",
                        evidence_ids=[self.evidence_id],
                    )
                ],
                follow_up_questions=[],
                disclaimer="Model-provided disclaimer.",
            )
        )


class RecordingOpenAIClient:
    def __init__(self, evidence_id: str):
        self.responses = RecordingResponses(evidence_id)


def test_settings_reads_openai_model_from_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("OPENAI_MODEL", "model-from-environment")

    configured = Settings(_env_file=None)

    assert configured.openai_model == "model-from-environment"


def test_default_generation_budget_favors_short_reliable_summaries() -> None:
    configured = Settings(_env_file=None)

    assert configured.openai_reasoning_effort == "none"
    assert configured.openai_max_output_tokens == 320
    assert configured.openai_max_retries == 1


def test_legacy_mini_model_does_not_receive_unsupported_none_reasoning(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(settings, "openai_model", "gpt-5-mini")
    monkeypatch.setattr(settings, "openai_reasoning_effort", "none")

    assert AssistantService._reasoning_effort() == "minimal"


def test_endpoint_without_api_key_returns_503_before_creating_client(
    monkeypatch: pytest.MonkeyPatch,
    auth_headers: dict[str, str],
) -> None:
    monkeypatch.setattr(settings, "openai_api_key", None)

    def unexpected_service_creation():
        raise AssertionError("OpenAI client must not be created without a server API key")

    monkeypatch.setattr(main_module, "AssistantService", unexpected_service_creation)

    response = TestClient(app).post(
        "/v1/assistant/analyze",
        json=assistant_payload(),
        headers=auth_headers,
    )

    assert response.status_code == 503
    assert response.json() == {"detail": "AI service is not configured"}


def test_configured_endpoint_returns_structured_assistant_response_without_state(
    monkeypatch: pytest.MonkeyPatch,
    auth_headers: dict[str, str],
) -> None:
    payload = assistant_payload()
    payload["questionType"] = "free_text"
    request = AssistantRequest.model_validate(payload)
    evidence_id = summarize_records(request).evidence[0].id
    client = RecordingOpenAIClient(evidence_id)
    service = AssistantService(client=client)
    service.safety = AllowAllSafety()
    server_only_key = "server-only-test-key"
    configured_model = "configured-test-model"
    monkeypatch.setattr(settings, "openai_api_key", server_only_key)
    monkeypatch.setattr(settings, "openai_model", configured_model)
    monkeypatch.setattr(main_module, "AssistantService", lambda: service)

    response = TestClient(app).post(
        "/v1/assistant/analyze",
        json=payload,
        headers=auth_headers,
    )

    assert response.status_code == 200
    parsed_response = AssistantResponse.model_validate(response.json())
    assert parsed_response.status == "ok"
    assert parsed_response.observations == []
    assert parsed_response.evidence[0].id == evidence_id
    assert server_only_key not in response.text

    call = client.responses.parse_kwargs
    assert call is not None
    assert call["model"] == configured_model
    assert call["text_format"] is OpenAIAssistantOutput
    assert call["reasoning"] == {"effort": service._reasoning_effort()}
    assert call["max_output_tokens"] == settings.openai_max_output_tokens
    assert call["store"] is False
    assert "conversation" not in call
    assert "previous_response_id" not in call
    assert server_only_key not in call["input"]
    model_input = json.loads(call["input"])
    assert model_input["recordFacts"]["medications"][0]["medicine"] == "Example medicine"
    assert model_input["recordFacts"]["medications"][0]["completedCheckIns"] == 1
    assert "selectedRecords" not in model_input
    assert "deterministicSummary" not in model_input


def test_service_returns_pydantic_validated_structured_output() -> None:
    request = AssistantRequest.model_validate(assistant_payload())
    evidence_id = summarize_records(request).evidence[0].id
    client = RecordingOpenAIClient(evidence_id)
    service = AssistantService(client=client)
    service.safety = AllowAllSafety()

    result = asyncio.run(service.generate(request))

    assert isinstance(result, AssistantResponse)
    assert result.summary == "One medication event was recorded."
    assert result.observations == []
    assert result.evidence[0].id == evidence_id


def test_service_removes_a_model_repeated_disclaimer_from_the_summary() -> None:
    summary = AssistantService._without_embedded_disclaimer(
        "A concise summary. This is an informational summary of your records, not a diagnosis or treatment recommendation."
    )

    assert summary == "A concise summary"


def test_openai_schema_uses_only_supported_structured_output_constraints() -> None:
    schema = OpenAIAssistantOutput.model_json_schema(by_alias=True)
    unsupported_keywords = {
        "minLength",
        "maxLength",
        "pattern",
        "format",
        "minimum",
        "maximum",
        "multipleOf",
        "patternProperties",
        "minItems",
        "maxItems",
    }

    def collect_keys(value: object) -> set[str]:
        if isinstance(value, dict):
            return set(value) | {key for item in value.values() for key in collect_keys(item)}
        if isinstance(value, list):
            return {key for item in value for key in collect_keys(item)}
        return set()

    assert collect_keys(schema).isdisjoint(unsupported_keywords)
    assert set(schema["properties"]) == {"summary"}
