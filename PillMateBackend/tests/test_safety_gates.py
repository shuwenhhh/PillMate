import asyncio
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

import app.main as main_module
from app.config import settings
from app.main import app
from app.policy import DISCLAIMER
from app.schemas import AssistantRequest, OpenAIAssistantOutput, OpenAIObservation
from app.services.assistant_service import AssistantService
from app.services.record_summary import summarize_records
from app.services.safety_service import SafetyService


def safety_payload(user_question: str, *, language: str = "en-US") -> dict:
    return {
        "requestId": "batch-5-request",
        "dateRange": {"start": "2026-09-14", "end": "2026-09-14"},
        "questionType": "free_text",
        "userQuestion": user_question,
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
        "language": language,
        "timezone": "Asia/Shanghai",
        "consentVersion": "2026-09-01",
    }


class RecordingModerations:
    def __init__(self, flags: list[bool], events: list[str]):
        self.flags = list(flags)
        self.events = events
        self.calls: list[dict] = []

    async def create(self, **kwargs):
        self.events.append("moderation")
        self.calls.append(kwargs)
        if not self.flags:
            raise AssertionError("unexpected moderation call")
        return SimpleNamespace(results=[SimpleNamespace(flagged=self.flags.pop(0))])


class RecordingResponses:
    def __init__(self, output: OpenAIAssistantOutput | None, events: list[str]):
        self.output = output
        self.events = events
        self.calls: list[dict] = []

    async def parse(self, **kwargs):
        self.events.append("model")
        self.calls.append(kwargs)
        if self.output is None:
            raise AssertionError("the model must not be called for a locally handled request")
        return SimpleNamespace(output_parsed=self.output)


class RecordingClient:
    def __init__(self, flags: list[bool], output: OpenAIAssistantOutput | None):
        self.events: list[str] = []
        self.moderations = RecordingModerations(flags, self.events)
        self.responses = RecordingResponses(output, self.events)


def ordinary_output(evidence_id: str) -> OpenAIAssistantOutput:
    return OpenAIAssistantOutput(
        status="ok",
        summary="One medication event was recorded.",
        observations=[
            OpenAIObservation(
                text="One dose was recorded in the selected period.",
                evidence_ids=[evidence_id],
            )
        ],
        follow_up_questions=[],
        # This exact text contains the word "diagnosis". It must be ignored and
        # replaced server-side instead of making every ordinary output a refusal.
        disclaimer=DISCLAIMER,
    )


@pytest.mark.parametrize(
    "question",
    [
        "Do I have diabetes based on these readings?",
        "Should I increase my dose?",
        "我应该停药吗？",
        "Can I switch to a different medication?",
        "Did this medicine cause my headache?",
        "我该怎么改药？",
        "这个药是不是导致了头痛？",
    ],
)
def test_medical_boundary_requests_are_refused_before_model(question: str) -> None:
    request = AssistantRequest.model_validate(safety_payload(question))
    client = RecordingClient([False], output=None)

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "refusal"
    assert result.observations == []
    assert result.evidence == []
    assert result.disclaimer == DISCLAIMER
    assert client.events == ["moderation"]
    assert question in client.moderations.calls[0]["input"]


def test_dangerous_description_gets_neutral_local_safety_escalation() -> None:
    question = "我现在胸痛、呼吸困难，我应该停药吗？"
    request = AssistantRequest.model_validate(safety_payload(question, language="zh-CN"))
    client = RecordingClient([True], output=None)

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "safety_escalation"
    assert result.summary == "这段描述可能需要及时关注。请立即联系当地急救服务或就近医疗机构。"
    assert result.observations == []
    assert result.evidence == []
    assert result.follow_up_questions == []
    assert result.disclaimer == DISCLAIMER
    assert client.events == ["moderation"]


@pytest.mark.parametrize(
    ("question", "language", "expected_status"),
    [
        ("我应该停药吗？", "zh-CN", "refusal"),
        ("我现在胸痛、呼吸困难。", "zh-CN", "safety_escalation"),
    ],
)
def test_http_endpoint_returns_server_controlled_safety_status(
    monkeypatch: pytest.MonkeyPatch,
    auth_headers: dict[str, str],
    question: str,
    language: str,
    expected_status: str,
) -> None:
    client = RecordingClient([False], output=None)
    service = AssistantService(client=client)
    monkeypatch.setattr(settings, "openai_api_key", "server-only-test-key")
    monkeypatch.setattr(main_module, "AssistantService", lambda: service)

    response = TestClient(app).post(
        "/v1/assistant/analyze",
        json=safety_payload(question, language=language),
        headers=auth_headers,
    )

    assert response.status_code == 200
    assert response.json()["status"] == expected_status
    assert response.json()["disclaimer"] == DISCLAIMER
    assert client.events == ["moderation"]


def test_flagged_input_is_refused_without_model_call() -> None:
    request = AssistantRequest.model_validate(safety_payload("Summarize the recorded dates."))
    client = RecordingClient([True], output=None)

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "refusal"
    assert result.disclaimer == DISCLAIMER
    assert client.events == ["moderation"]


def test_ordinary_summary_is_moderated_before_and_after_model() -> None:
    request = AssistantRequest.model_validate(safety_payload("Summarize the recorded dates."))
    evidence_id = summarize_records(request).evidence[0].id
    client = RecordingClient([False, False], ordinary_output(evidence_id))

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "ok"
    assert result.observations[0].evidence_ids == [evidence_id]
    assert result.disclaimer == DISCLAIMER
    assert client.events == ["moderation", "model", "moderation"]
    assert len(client.moderations.calls) == 2
    assert client.moderations.calls[0]["model"] == settings.openai_moderation_model
    assert "disclaimer" not in client.moderations.calls[1]["input"]


@pytest.mark.parametrize(
    "question",
    [
        "Do I have enough records for a summary?",
        "Should I change the date range for this summary?",
        "Summarize the records because of my upcoming appointment.",
    ],
)
def test_non_medical_phrasing_is_not_overblocked(question: str) -> None:
    request = AssistantRequest.model_validate(safety_payload(question))
    evidence_id = summarize_records(request).evidence[0].id
    client = RecordingClient([False, False], ordinary_output(evidence_id))

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "ok"
    assert client.events == ["moderation", "model", "moderation"]


def test_flagged_model_output_is_refused() -> None:
    request = AssistantRequest.model_validate(safety_payload("Summarize the recorded dates."))
    evidence_id = summarize_records(request).evidence[0].id
    client = RecordingClient([False, True], ordinary_output(evidence_id))

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "refusal"
    assert result.observations == []
    assert result.evidence == []
    assert result.disclaimer == DISCLAIMER
    assert client.events == ["moderation", "model", "moderation"]


@pytest.mark.parametrize(
    "unsafe_summary",
    [
        "You should stop taking your medication now.",
        "These records diagnose a heart condition.",
        "The medicine caused the headache.",
        "你应该换药。",
    ],
)
def test_restricted_model_output_is_refused_after_moderation(unsafe_summary: str) -> None:
    request = AssistantRequest.model_validate(safety_payload("Summarize the recorded dates."))
    evidence_id = summarize_records(request).evidence[0].id
    unsafe_output = ordinary_output(evidence_id).model_copy(
        update={"summary": unsafe_summary}
    )
    client = RecordingClient([False, False], unsafe_output)

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "refusal"
    assert result.disclaimer == DISCLAIMER
    assert client.events == ["moderation", "model", "moderation"]


def test_dangerous_model_copy_is_replaced_with_neutral_server_escalation() -> None:
    request = AssistantRequest.model_validate(safety_payload("Summarize the recorded dates."))
    evidence_id = summarize_records(request).evidence[0].id
    dangerous_output = ordinary_output(evidence_id).model_copy(
        update={"summary": "The user reported chest pain and difficulty breathing."}
    )
    client = RecordingClient([False, False], dangerous_output)

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "safety_escalation"
    assert result.summary.startswith("This description may need prompt attention.")
    assert result.observations == []
    assert result.evidence == []
    assert result.disclaimer == DISCLAIMER


def test_missing_moderation_result_fails_closed() -> None:
    class EmptyModerations:
        async def create(self, **kwargs):
            return SimpleNamespace(results=[])

    client = SimpleNamespace(moderations=EmptyModerations())

    with pytest.raises(RuntimeError, match="did not include a result"):
        asyncio.run(SafetyService(client=client).is_flagged("record content"))


def test_unverified_model_evidence_id_is_refused() -> None:
    request = AssistantRequest.model_validate(safety_payload("Summarize the recorded dates."))
    output = ordinary_output("evidence:invented")
    client = RecordingClient([False, False], output)

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "refusal"
    assert "verify the evidence" in result.summary
    assert result.observations == []
    assert result.evidence == []
    assert result.disclaimer == DISCLAIMER
    assert client.events == ["moderation", "model", "moderation"]
