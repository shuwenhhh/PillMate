import asyncio
import json
from copy import deepcopy
from types import SimpleNamespace

import pytest

from app.policy import DISCLAIMER
from app.schemas import (
    AI_CONSENT_VERSION,
    AssistantRequest,
    OpenAIAssistantOutput,
)
from app.services.assistant_service import AssistantService
from app.services.model_context import (
    build_after_dose_vitals_table,
    build_check_in_timing_table,
    build_doctor_summary_table,
    build_model_facts,
)
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


def test_summary_counts_days_when_every_scheduled_dose_was_completed() -> None:
    payload = summary_payload()
    payload["dateRange"] = {"start": "2026-09-12", "end": "2026-09-14"}
    payload["medications"] = [
        {
            "id": "once-daily",
            "name": "Once daily",
            "frequency": "Once a day",
            "isActive": True,
            "startDate": "2026-09-12",
        },
        {
            "id": "twice-daily",
            "name": "Twice daily",
            "frequency": "Twice a day",
            "isActive": True,
            "startDate": "2026-09-12",
        },
        {
            "id": "as-needed",
            "name": "As needed",
            "frequency": "As needed",
            "isActive": True,
            "startDate": "2026-09-12",
        },
    ]
    payload["medicationEvents"] = [
        {"id": "once-12", "medicineId": "once-daily", "recordedAt": "2026-09-12T08:00:00+08:00", "takenAt": "08:00"},
        {"id": "twice-12-am", "medicineId": "twice-daily", "recordedAt": "2026-09-12T08:30:00+08:00", "takenAt": "08:30"},
        {"id": "twice-12-pm", "medicineId": "twice-daily", "recordedAt": "2026-09-12T20:30:00+08:00", "takenAt": "20:30"},
        {"id": "once-13", "medicineId": "once-daily", "recordedAt": "2026-09-13T08:00:00+08:00", "takenAt": "08:00"},
        {"id": "once-14", "medicineId": "once-daily", "recordedAt": "2026-09-14T08:00:00+08:00", "takenAt": "08:00"},
        {"id": "twice-14-am", "medicineId": "twice-daily", "recordedAt": "2026-09-14T08:30:00+08:00", "takenAt": "08:30"},
        {"id": "twice-14-pm", "medicineId": "twice-daily", "recordedAt": "2026-09-14T20:30:00+08:00", "takenAt": "20:30"},
    ]
    payload["journalEntries"] = []

    facts = evidence_by_statistic(AssistantRequest.model_validate(payload))

    assert facts["medication.scheduled_day_count"][0].value == 3
    assert facts["medication.fully_completed_day_count"][0].value == 2


def test_summary_counts_zero_fully_completed_days_without_guessing_prn_doses() -> None:
    payload = summary_payload()
    payload["dateRange"] = {"start": "2026-09-14", "end": "2026-09-14"}
    payload["medications"] = [
        {"id": "medicine-1", "name": "First", "frequency": "Once a day", "isActive": True},
        {"id": "medicine-2", "name": "Second", "frequency": "Once a day", "isActive": True},
        {"id": "prn", "name": "PRN", "frequency": "As needed", "isActive": True},
    ]
    payload["medicationEvents"] = [
        {"id": "only-first", "medicineId": "medicine-1", "recordedAt": "2026-09-14T08:00:00+08:00", "takenAt": "08:00"}
    ]
    payload["journalEntries"] = []

    facts = evidence_by_statistic(AssistantRequest.model_validate(payload))

    assert facts["medication.scheduled_day_count"][0].value == 1
    assert facts["medication.fully_completed_day_count"][0].value == 0


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
        parsed = OpenAIAssistantOutput(summary="Deterministic summary.")
        return SimpleNamespace(output_parsed=parsed)


class FakeClient:
    def __init__(self, evidence_id: str):
        self.responses = FakeResponses(evidence_id)


def test_model_receives_compact_precomputed_facts_not_raw_records() -> None:
    payload = summary_payload()
    # Timing questions are intentionally answered locally. Use vitals here to
    # verify the remaining model-backed path receives facts, never raw records.
    payload["questionType"] = "vitals"
    request = AssistantRequest.model_validate(payload)
    deterministic = summarize_records(request)
    client = FakeClient(deterministic.evidence[0].id)
    service = AssistantService(client=client)
    service.safety = FakeSafety()

    response = asyncio.run(service.generate(request))

    assert client.responses.input_payload is not None
    assert "recordFacts" in client.responses.input_payload
    assert "selectedRecords" not in client.responses.input_payload
    assert "deterministicSummary" not in client.responses.input_payload
    assert client.responses.input_payload["recordFacts"]["overallHeartRate"]["count"] == 3
    assert response.disclaimer == DISCLAIMER
    assert response.evidence == deterministic.evidence
    assert response.observations == []


def test_compact_model_facts_keep_symptoms_linked_to_the_medicine() -> None:
    payload = summary_payload()
    payload["medicationEvents"][0]["feeling"] = "Energetic"
    request = AssistantRequest.model_validate(payload)
    facts = build_model_facts(request, summarize_records(request))

    medicine = facts["medications"][0]
    assert medicine["medicine"] == "Example"
    assert medicine["recordedFeelings"] == [
        {"value": "Energetic", "count": 1, "timing": "in the same check-in"}
    ]
    assert medicine["recordedSymptoms"] == [
        {"value": "Headache", "count": 1, "timing": "after"}
    ]
    assert facts["adherence"]["onTimeCheckIns"] == 1


def test_model_facts_include_the_specific_incomplete_scheduled_date() -> None:
    payload = summary_payload()
    payload["medicationEvents"] = [
        {
            "id": "completed-13",
            "medicineId": "medicine-1",
            "recordedAt": "2026-09-13T08:00:00+08:00",
            "isCompleted": True,
        }
    ]
    payload["journalEntries"] = []

    facts = build_model_facts(
        AssistantRequest.model_validate(payload),
        summarize_records(AssistantRequest.model_validate(payload)),
    )

    assert facts["missingScheduledDates"] == ["2026-09-14"]


def test_doctor_summary_table_uses_recorded_symptoms_and_vital_ranges() -> None:
    request = AssistantRequest.model_validate(summary_payload())

    table = build_doctor_summary_table(request, summarize_records(request))

    assert table["medicines"] == [
        {"medicine": "Example", "symptoms": [{"label": "Headache", "count": 1}]}
    ]
    assert table["heartRate"] == {"range": "70–76 bpm", "latest": "76 bpm"}
    assert table["bloodPressure"] == {
        "range": "118–121 / 76–79 mmHg",
        "latest": "121 / 79 mmHg",
    }


def test_after_dose_vitals_table_groups_ranges_by_medicine() -> None:
    request = AssistantRequest.model_validate(summary_payload())

    table = build_after_dose_vitals_table(request, summarize_records(request))

    assert table["medicines"] == [
        {
            "medicine": "Example",
            "heartRateCount": 3,
            "heartRateRange": "70–76 bpm",
            "bloodPressureCount": 2,
            "bloodPressureRange": "118–121 / 76–79 mmHg",
        }
    ]


def test_check_in_timing_table_lists_early_and_late_by_medicine() -> None:
    payload = summary_payload()
    payload["dateRange"] = {"start": "2026-09-13", "end": "2026-09-14"}
    payload["medications"] = [
        {
            "id": "morning",
            "name": "Morning medicine",
            "timeWindow": "8:00–10:00 AM",
            "frequency": "Once a day",
        },
        {
            "id": "evening",
            "name": "Evening medicine",
            "timeWindow": "6:00–8:00 PM",
            "frequency": "Once a day",
        },
    ]
    payload["medicationEvents"] = [
        {
            "id": "morning-13",
            "medicineId": "morning",
            "recordedAt": "2026-09-13T07:30:00+08:00",
            "scheduledWindow": "8:00–10:00 AM",
            "takenAt": "7:30 AM",
            "isCompleted": True,
        },
        {
            "id": "evening-13",
            "medicineId": "evening",
            "recordedAt": "2026-09-13T09:00:00+08:00",
            "scheduledWindow": "6:00–8:00 PM",
            "takenAt": "9:00 PM",
            "isCompleted": True,
        },
        {
            "id": "morning-14",
            "medicineId": "morning",
            "recordedAt": "2026-09-14T08:30:00+08:00",
            "scheduledWindow": "8:00–10:00 AM",
            "takenAt": "8:30 AM",
            "isCompleted": True,
        },
    ]
    payload["journalEntries"] = []
    request = AssistantRequest.model_validate(payload)

    table = build_check_in_timing_table(request)

    assert table["completeDays"] == 1
    assert table["trackedDays"] == 2
    assert table["medicines"] == [
        {
            "medicine": "Evening medicine",
            "taken": 1,
            "onTime": 0,
            "early": 0,
            "late": 1,
            "withoutTiming": 0,
        },
        {
            "medicine": "Morning medicine",
            "taken": 2,
            "onTime": 1,
            "early": 1,
            "late": 0,
            "withoutTiming": 0,
        },
    ]
