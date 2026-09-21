import asyncio
import json
from copy import deepcopy
from types import SimpleNamespace

import pytest

from app.policy import DISCLAIMER
from app.schemas import (
    AI_CONSENT_VERSION,
    AssistantNarrative,
    AssistantRequest,
    Observation,
)
from app.services.assistant_service import AssistantService
from app.services.record_summary import summarize_records


def summary_payload() -> dict:
    return {
        "requestId": "batch-3-request",
        "dateRange": {"start": "2026-09-13", "end": "2026-09-14"},
        "questionType": "consistency",
        "userQuestion": "Summarize the records.",
        "medications": [
            {
                "id": "medicine-1",
                "name": "Example",
                "dose": "10 mg",
                "timeWindow": "8:00–10:00 AM",
                "frequency": "daily",
                "isActive": True,
            }
        ],
        "medicationEvents": [
            {
                "id": "dose-2",
                "medicineId": "medicine-1",
                "recordedAt": "2026-09-14T00:00:00+08:00",
                "scheduledWindow": "8:00–10:00 AM",
                "takenAt": "11:00 AM",
                "interval": "model must ignore this string",
                "heartRate": 76,
            },
            {
                "id": "dose-untaken",
                "medicineId": "medicine-1",
                "recordedAt": "2026-09-14T00:00:00+08:00",
                "scheduledWindow": "8:00–10:00 AM",
            },
            {
                "id": "dose-1",
                "medicineId": "medicine-1",
                "recordedAt": "2026-09-13T00:00:00+08:00",
                "scheduledWindow": "8:00–10:00 AM",
                "takenAt": "9:00 AM",
                "interval": "not trusted for calculation",
                "heartRate": 72,
                "bloodPressure": {"systolic": 118, "diastolic": 76},
            },
        ],
        "journalEntries": [
            {
                "id": "symptom-1",
                "entryType": "symptoms",
                "recordedAt": "2026-09-14T11:30:00+08:00",
                "symptom": "Headache",
                "severity": "mild",
            },
            {
                "id": "mood-1",
                "entryType": "mood",
                "recordedAt": "2026-09-14T10:30:00+08:00",
                "mood": "Calm",
            },
            {
                "id": "bp-1",
                "entryType": "bloodPressure",
                "recordedAt": "2026-09-14T11:00:00+08:00",
                "bloodPressure": {"systolic": 121, "diastolic": 79},
            },
            {
                "id": "hr-1",
                "entryType": "heartRate",
                "recordedAt": "2026-09-13T10:00:00+08:00",
                "heartRate": 70,
            },
        ],
        "language": "en-US",
        "timezone": "Asia/Shanghai",
        "consentVersion": AI_CONSENT_VERSION,
    }


def evidence_by_statistic(request: AssistantRequest) -> dict[str, list]:
    result: dict[str, list] = {}
    for item in summarize_records(request).evidence:
        result.setdefault(item.statistic, []).append(item)
    return result


def test_summary_calculates_counts_windows_intervals_and_time_relationships() -> None:
    request = AssistantRequest.model_validate(summary_payload())
    facts = evidence_by_statistic(request)

    assert facts["medication.taken_count"][0].value == 2
    assert facts["medication.taken_count"][0].source_record_ids == ["dose-1", "dose-2"]
    assert facts["medication.window_inside_count"][0].source_record_ids == ["dose-1"]
    assert facts["medication.window_outside_count"][0].source_record_ids == ["dose-2"]
    assert facts["medication.interval_minutes"][0].value == 26 * 60
    assert facts["medication.interval_minutes"][0].source_record_ids == ["dose-1", "dose-2"]

    assert facts["mood.record_count"][0].value == 1
    assert facts["symptoms.record_count"][0].value == 1
    assert facts["blood_pressure.record_count"][0].value == 2
    assert facts["heart_rate.record_count"][0].value == 3

    mood_relation = facts["mood.medication_offset_minutes"][0]
    symptom_relation = facts["symptoms.medication_offset_minutes"][0]
    assert (mood_relation.value, mood_relation.relation) == (-30, "before")
    assert mood_relation.source_record_ids == ["mood-1", "dose-2"]
    assert (symptom_relation.value, symptom_relation.relation) == (30, "after")
    assert any(item.relation == "same_record" for item in facts["blood_pressure.medication_offset_minutes"])
    assert any(item.relation == "same_time" for item in facts["blood_pressure.medication_offset_minutes"])


def test_summary_is_identical_for_repeated_and_reordered_input() -> None:
    payload = summary_payload()
    first = summarize_records(AssistantRequest.model_validate(payload)).model_dump(mode="json", by_alias=True)
    second = summarize_records(AssistantRequest.model_validate(deepcopy(payload))).model_dump(mode="json", by_alias=True)
    reordered = deepcopy(payload)
    reordered["medicationEvents"].reverse()
    reordered["journalEntries"].reverse()
    third = summarize_records(AssistantRequest.model_validate(reordered)).model_dump(mode="json", by_alias=True)

    assert first == second == third
    assert len({item["id"] for item in first["evidence"]}) == len(first["evidence"])


def test_every_evidence_item_traces_to_supplied_record_ids() -> None:
    request = AssistantRequest.model_validate(summary_payload())
    supplied_ids = {event.id for event in request.medication_events} | {
        entry.id for entry in request.journal_entries
    }

    for item in summarize_records(request).evidence:
        assert item.source_record_ids
        assert set(item.source_record_ids) <= supplied_ids


def test_summary_rejects_ambiguous_record_ids() -> None:
    payload = summary_payload()
    payload["journalEntries"][0]["id"] = "dose-1"

    with pytest.raises(ValueError, match="unique across"):
        summarize_records(AssistantRequest.model_validate(payload))


def test_cross_midnight_window_is_calculated_deterministically() -> None:
    payload = summary_payload()
    payload["medicationEvents"] = [
        {
            "id": "night-dose",
            "medicineId": "medicine-1",
            "recordedAt": "2026-09-14T00:00:00+08:00",
            "scheduledWindow": "9:00 PM–1:00 AM",
            "takenAt": "12:30 AM",
        }
    ]
    payload["journalEntries"] = []

    facts = evidence_by_statistic(AssistantRequest.model_validate(payload))

    assert facts["medication.window_inside_count"][0].value == 1


class FakeSafety:
    def request_text(self, payload: dict) -> str:
        return json.dumps(payload)

    async def is_flagged(self, text: str) -> bool:
        return False


class FakeResponses:
    def __init__(self, evidence_id: str):
        self.evidence_id = evidence_id
        self.input_payload: dict | None = None

    async def parse(self, **kwargs):
        self.input_payload = json.loads(kwargs["input"])
        parsed = AssistantNarrative(
            status="ok",
            summary="Deterministic summary.",
            observations=[Observation(text="Two doses were recorded.", evidence_ids=[self.evidence_id])],
            disclaimer="model supplied text",
        )
        return SimpleNamespace(output_parsed=parsed)


class FakeClient:
    def __init__(self, evidence_id: str):
        self.responses = FakeResponses(evidence_id)


def test_model_receives_precomputed_evidence_not_raw_records() -> None:
    request = AssistantRequest.model_validate(summary_payload())
    deterministic = summarize_records(request)
    client = FakeClient(deterministic.evidence[0].id)
    service = AssistantService(client=client)
    service.safety = FakeSafety()

    response = asyncio.run(service.generate(request))

    assert client.responses.input_payload is not None
    assert "deterministicSummary" in client.responses.input_payload
    assert "medicationEvents" not in client.responses.input_payload
    assert "journalEntries" not in client.responses.input_payload
    assert response.disclaimer == DISCLAIMER
    assert response.evidence == deterministic.evidence
    assert response.observations[0].evidence_ids[0] in {item.id for item in response.evidence}
