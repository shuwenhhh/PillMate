from datetime import date, datetime
from enum import Enum
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class BloodPressure(StrictModel):
    systolic: int = Field(ge=40, le=300)
    diastolic: int = Field(ge=20, le=200)


class MedicationDefinition(StrictModel):
    id: str = Field(min_length=1, max_length=64)
    name: str = Field(min_length=1, max_length=120)
    dose: str = Field(default="", max_length=120)
    schedule: str = Field(default="", max_length=120)
    frequency: str = Field(default="", max_length=80)
    is_active: bool = True


class MedicationEvent(StrictModel):
    id: str = Field(min_length=1, max_length=64)
    medicine_id: str = Field(min_length=1, max_length=64)
    recorded_at: datetime
    scheduled_window: str = Field(default="", max_length=120)
    taken_at: str | None = Field(default=None, max_length=80)
    feeling: str | None = Field(default=None, max_length=80)
    heart_rate: int | None = Field(default=None, ge=20, le=300)
    blood_pressure: BloodPressure | None = None
    note: str = Field(default="", max_length=1000)


class JournalEntry(StrictModel):
    id: str = Field(min_length=1, max_length=64)
    entry_type: Literal["mood", "symptoms", "blood_pressure", "heart_rate"]
    recorded_at: datetime
    mood: str | None = Field(default=None, max_length=80)
    symptom: str | None = Field(default=None, max_length=120)
    severity: str | None = Field(default=None, max_length=40)
    heart_rate: int | None = Field(default=None, ge=20, le=300)
    blood_pressure: BloodPressure | None = None
    note: str = Field(default="", max_length=1000)


class QuestionType(str, Enum):
    side_effects = "side_effects"
    consistency = "consistency"
    vitals = "vitals"
    doctor_summary = "doctor_summary"
    free_text = "free_text"


class DateRange(StrictModel):
    start: date
    end: date

    @field_validator("end")
    @classmethod
    def end_must_not_precede_start(cls, value: date, info):
        start = info.data.get("start")
        if start and value < start:
            raise ValueError("date range end must not precede start")
        return value


class AssistantRequest(StrictModel):
    request_id: str = Field(min_length=1, max_length=64)
    date_range: DateRange
    question_type: QuestionType
    user_question: str = Field(default="", max_length=1000)
    medications: list[MedicationDefinition] = Field(default_factory=list, max_length=100)
    medication_events: list[MedicationEvent] = Field(default_factory=list, max_length=1000)
    journal_entries: list[JournalEntry] = Field(default_factory=list, max_length=1000)
    locale: str = Field(default="en-US", max_length=20)
    timezone: str = Field(default="UTC", max_length=64)
    consent_version: str = Field(min_length=1, max_length=40)


class Observation(StrictModel):
    text: str = Field(min_length=1, max_length=600)
    evidence_ids: list[str] = Field(default_factory=list, max_length=50)


class AssistantResponse(StrictModel):
    status: Literal["ok", "needs_clarification", "refusal", "safety_escalation"]
    summary: str = Field(min_length=1, max_length=1200)
    observations: list[Observation] = Field(default_factory=list, max_length=10)
    follow_up_questions: list[str] = Field(default_factory=list, max_length=5)
    disclaimer: str = Field(min_length=1, max_length=300)
