from copy import deepcopy

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.config import settings
from app.main import app
from app.schemas import MAX_MEDICATIONS, MAX_RECORDS_PER_TYPE, AssistantRequest, AssistantResponse


def valid_payload() -> dict:
    return {
        "requestId": "request-20260914-001",
        "dateRange": {"start": "2026-08-16", "end": "2026-09-14"},
        "questionType": "vitals",
        "userQuestion": "Summarize the recorded vital signs.",
        "medications": [
            {
                "id": "medicine-1",
                "name": "Example medicine",
                "dose": "10 mg",
                "timeWindow": "Morning",
                "frequency": "Once a day",
                "isActive": True,
            }
        ],
        "medicationEvents": [
            {
                "id": "medication-event-1",
                "medicineId": "medicine-1",
                "recordedAt": "2026-09-14T08:00:00+08:00",
                "scheduledWindow": "Morning",
                "takenAt": "08:00",
                "feeling": "Fine",
                "interval": "24 hours",
                "heartRate": 72,
                "bloodPressure": {"systolic": 118, "diastolic": 76},
                "notes": "Taken after breakfast.",
            }
        ],
        "journalEntries": [
            {
                "id": "journal-entry-1",
                "entryType": "mood",
                "recordedAt": "2026-09-14T09:00:00+08:00",
                "mood": "Calm",
            }
        ],
        "language": "en-US",
        "timezone": "Asia/Shanghai",
        "consentVersion": "2026-09-01",
    }


def test_request_accepts_camel_case_contract() -> None:
    request = AssistantRequest.model_validate(valid_payload())

    assert request.medication_events[0].interval == "24 hours"
    assert request.model_dump(mode="json", by_alias=True)["consentVersion"] == "2026-09-01"


@pytest.mark.parametrize(
    ("systolic", "diastolic"),
    [(39, 76), (301, 76), (118, 19), (118, 201), (80, 80), (70, 80)],
)
def test_request_rejects_invalid_blood_pressure(systolic: int, diastolic: int) -> None:
    payload = valid_payload()
    payload["medicationEvents"][0]["bloodPressure"] = {
        "systolic": systolic,
        "diastolic": diastolic,
    }

    with pytest.raises(ValidationError):
        AssistantRequest.model_validate(payload)


@pytest.mark.parametrize("heart_rate", [19, 301, True])
def test_request_rejects_invalid_heart_rate(heart_rate: object) -> None:
    payload = valid_payload()
    payload["journalEntries"][0]["heartRate"] = heart_rate

    with pytest.raises(ValidationError):
        AssistantRequest.model_validate(payload)


def test_request_rejects_reversed_date_range() -> None:
    payload = valid_payload()
    payload["dateRange"] = {"start": "2026-09-15", "end": "2026-09-14"}

    with pytest.raises(ValidationError):
        AssistantRequest.model_validate(payload)


def test_request_rejects_date_range_longer_than_limit() -> None:
    payload = valid_payload()
    payload["dateRange"] = {"start": "2025-01-01", "end": "2026-01-02"}

    with pytest.raises(ValidationError):
        AssistantRequest.model_validate(payload)


def test_request_rejects_overlong_medication_notes() -> None:
    payload = valid_payload()
    payload["medicationEvents"][0]["notes"] = "x" * 1001

    with pytest.raises(ValidationError):
        AssistantRequest.model_validate(payload)


@pytest.mark.parametrize(
    ("field", "limit"),
    [
        ("medications", MAX_MEDICATIONS),
        ("medicationEvents", MAX_RECORDS_PER_TYPE),
        ("journalEntries", MAX_RECORDS_PER_TYPE),
    ],
)
def test_request_rejects_oversized_arrays(field: str, limit: int) -> None:
    payload = valid_payload()
    payload[field] = [deepcopy(payload[field][0]) for _ in range(limit + 1)]

    with pytest.raises(ValidationError):
        AssistantRequest.model_validate(payload)


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("name", "Private Person"),
        ("email", "person@example.com"),
        ("address", "1 Private Street"),
        ("gps", {"latitude": 1.0, "longitude": 2.0}),
        ("deviceId", "device-123"),
        ("swiftDataDatabase", "opaque-export"),
    ],
)
def test_request_rejects_direct_identity_device_and_location_fields(field: str, value: object) -> None:
    payload = valid_payload()
    payload[field] = value

    with pytest.raises(ValidationError):
        AssistantRequest.model_validate(payload)


def test_request_rejects_unplanned_nested_health_fields() -> None:
    payload = valid_payload()
    payload["journalEntries"][0]["note"] = "Journal notes are not in the Batch 2 allowlist."

    with pytest.raises(ValidationError):
        AssistantRequest.model_validate(payload)


def test_endpoint_rejects_invalid_payload_before_service_call() -> None:
    payload = valid_payload()
    payload["deviceId"] = "device-123"

    response = TestClient(app).post("/v1/assistant/analyze", json=payload)

    assert response.status_code == 422
    assert response.json()["detail"][0]["type"] == "extra_forbidden"


def test_endpoint_accepts_valid_contract(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "openai_api_key", None)

    response = TestClient(app).post("/v1/assistant/analyze", json=valid_payload())

    assert response.status_code == 503
    assert response.json() == {"detail": "AI service is not configured"}


def test_response_contract_accepts_camel_case_fields() -> None:
    response = AssistantResponse.model_validate(
        {
            "status": "ok",
            "summary": "One record was supplied.",
            "observations": [
                {"text": "One event was recorded.", "evidenceIds": ["evidence-1"]}
            ],
            "evidence": [
                {
                    "id": "evidence-1",
                    "statistic": "medication.taken_count",
                    "value": 1,
                    "unit": "records",
                    "sourceRecordIds": ["medication-event-1"],
                }
            ],
            "followUpQuestions": [],
            "disclaimer": "Informational summary only.",
        }
    )

    assert response.observations[0].evidence_ids == ["evidence-1"]


def test_response_contract_rejects_empty_evidence() -> None:
    with pytest.raises(ValidationError):
        AssistantResponse.model_validate(
            {
                "status": "ok",
                "summary": "One record was supplied.",
                "observations": [{"text": "One event was recorded.", "evidenceIds": []}],
                "followUpQuestions": [],
                "disclaimer": "Informational summary only.",
            }
        )


def test_response_contract_rejects_untraceable_observation() -> None:
    with pytest.raises(ValidationError, match="included evidence"):
        AssistantResponse.model_validate(
            {
                "status": "ok",
                "summary": "One record was supplied.",
                "observations": [{"text": "One event was recorded.", "evidenceIds": ["missing"]}],
                "evidence": [],
                "followUpQuestions": [],
                "disclaimer": "Informational summary only.",
            }
        )


def test_response_contract_rejects_unknown_fields() -> None:
    with pytest.raises(ValidationError):
        AssistantResponse.model_validate(
            {
                "status": "ok",
                "summary": "One record was supplied.",
                "observations": [],
                "followUpQuestions": [],
                "disclaimer": "Informational summary only.",
                "patientName": "Private Person",
            }
        )
