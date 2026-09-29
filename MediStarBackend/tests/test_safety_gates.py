import asyncio
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

import app.main as main_module
from app.config import settings
from app.main import app
from app.policy import DISCLAIMER
from app.schemas import (
    AI_CONSENT_VERSION,
    AssistantRequest,
    OpenAIAssistantOutput,
    OpenAIObservation,
)
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
        "consentVersion": AI_CONSENT_VERSION,
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
        "Is this medication safe for me?",
        "Is this reading serious?",
        "Should I see a doctor about this?",
        "What dose should I take?",
        "这个药安全吗？",
        "这个症状严重吗？",
        "我要不要去医院？",
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
    assert client.events == []


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
    assert client.events == []


@pytest.mark.parametrize(
    ("question", "language"),
    [
        ("hi", "en-US"),
        ("你好！", "zh-CN"),
    ],
)
def test_standalone_greeting_is_sent_to_the_model_for_a_natural_reply(
    question: str, language: str
) -> None:
    request = AssistantRequest.model_validate(safety_payload(question, language=language))
    evidence_id = summarize_records(request).evidence[0].id
    client = RecordingClient([False, False], ordinary_output(evidence_id))

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "ok"
    assert client.events == ["model"]


def test_doctor_summary_question_is_allowed_when_record_text_contains_advice() -> None:
    payload = safety_payload("Which changes in my records may be useful to show my doctor?")
    payload["medications"][0]["name"] = "Should I see a doctor"
    request = AssistantRequest.model_validate(payload)
    evidence_id = summarize_records(request).evidence[0].id
    client = RecordingClient([False, False], ordinary_output(evidence_id))

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "ok"
    assert client.events == ["moderation", "model"]


def test_after_dose_feelings_is_sent_to_the_model() -> None:
    payload = safety_payload("I want to know my symptoms after taking Vitamin D")
    payload["medications"][0]["name"] = "Vitamin D3"
    payload["journalEntries"] = [
        {
            "id": "journal-1",
            "entryType": "mood",
            "recordedAt": "2026-09-14T01:00:00+08:00",
            "mood": "Feeling good",
            "medicationEventId": "dose-1",
        }
    ]
    request = AssistantRequest.model_validate(payload)
    evidence_id = summarize_records(request).evidence[0].id
    client = RecordingClient([False, False], ordinary_output(evidence_id))

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "ok"
    assert client.events == ["moderation", "model"]


def test_recorded_symptoms_question_is_not_refused_by_server_policy() -> None:
    request = AssistantRequest.model_validate(
        safety_payload("Which symptoms were recorded most often near medication check-ins?")
    )
    evidence_id = summarize_records(request).evidence[0].id
    client = RecordingClient([False, False], ordinary_output(evidence_id))

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "ok"
    assert "cannot provide" not in result.summary.lower()
    assert client.events == ["moderation", "model"]


def test_doctor_summary_is_sent_to_the_model() -> None:
    payload = safety_payload("Which changes in my records may be useful to show my doctor?")
    payload["questionType"] = "doctor_summary"
    request = AssistantRequest.model_validate(payload)
    evidence_id = summarize_records(request).evidence[0].id
    client = RecordingClient([False, False], ordinary_output(evidence_id))

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "ok"
    assert client.events == ["model"]


def test_check_in_timing_is_sent_to_the_model() -> None:
    payload = safety_payload("How many completed check-ins were on time?")
    payload["questionType"] = "consistency"
    request = AssistantRequest.model_validate(payload)
    evidence_id = summarize_records(request).evidence[0].id
    client = RecordingClient([False, False], ordinary_output(evidence_id))

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "ok"
    assert client.events == ["model"]


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
    assert client.events == []


def test_flagged_input_is_refused_without_model_call() -> None:
    request = AssistantRequest.model_validate(safety_payload("Summarize the recorded dates."))
    client = RecordingClient([True], output=None)

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "refusal"
    assert result.disclaimer == DISCLAIMER
    assert client.events == ["moderation"]


def test_ordinary_summary_is_moderated_before_model_only() -> None:
    request = AssistantRequest.model_validate(safety_payload("Summarize the recorded dates."))
    evidence_id = summarize_records(request).evidence[0].id
    client = RecordingClient([False, False], ordinary_output(evidence_id))

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "ok"
    assert result.observations == []
    assert result.evidence[0].id == evidence_id
    assert result.disclaimer == DISCLAIMER
    assert client.events == ["moderation", "model"]
    assert len(client.moderations.calls) == 1
    assert client.moderations.calls[0]["model"] == settings.openai_moderation_model
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
    assert client.events == ["moderation", "model"]


@pytest.mark.parametrize(
    "unsafe_summary",
    [
        "You should stop taking your medication now.",
        "These records diagnose a heart condition.",
        "The medicine caused the headache.",
        "你应该换药。",
        "This medication is safe and effective for you.",
        "Take 20 mg each morning.",
        "请改成每天服用20毫克。",
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
    assert client.events == ["moderation", "model"]


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


@pytest.mark.parametrize(
    ("question", "language"),
    [
        ("My lips are blue and I cannot wake the person next to me.", "en-US"),
        ("他现在嘴唇发紫，而且叫不醒。", "zh-CN"),
    ],
)
def test_additional_urgent_signals_are_escalated_before_model(
    question: str,
    language: str,
) -> None:
    request = AssistantRequest.model_validate(safety_payload(question, language=language))
    client = RecordingClient([False], output=None)

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "safety_escalation"
    assert result.observations == []
    assert result.evidence == []
    assert client.events == []


def test_missing_moderation_result_fails_closed() -> None:
    class EmptyModerations:
        async def create(self, **kwargs):
            return SimpleNamespace(results=[])

    client = SimpleNamespace(moderations=EmptyModerations())

    with pytest.raises(RuntimeError, match="did not include a result"):
        asyncio.run(SafetyService(client=client).is_flagged("record content"))


def test_unverified_model_evidence_id_hides_only_that_bullet() -> None:
    request = AssistantRequest.model_validate(safety_payload("Summarize the recorded dates."))
    output = ordinary_output("evidence:invented")
    client = RecordingClient([False, False], output)

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "ok"
    assert result.summary == "One medication event was recorded."
    assert result.observations == []
    assert result.evidence
    assert result.disclaimer == DISCLAIMER
    assert client.events == ["moderation", "model"]


def test_model_repeating_the_disclaimer_does_not_turn_a_valid_summary_into_a_refusal() -> None:
    request = AssistantRequest.model_validate(
        safety_payload("Which symptoms were recorded most often near medication check-ins?")
    )
    evidence_id = summarize_records(request).evidence[0].id
    output = ordinary_output(evidence_id).model_copy(
        update={"summary": f"One symptom was recorded. {DISCLAIMER}"}
    )
    client = RecordingClient([False, False], output)

    result = asyncio.run(AssistantService(client=client).generate(request))

    assert result.status == "ok"
    assert result.summary == "One symptom was recorded"
    assert result.disclaimer == DISCLAIMER
