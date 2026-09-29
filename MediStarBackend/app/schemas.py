from datetime import date, datetime
from enum import Enum
from typing import Literal, Self
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from pydantic.alias_generators import to_camel


MAX_DATE_RANGE_DAYS = 366
MAX_MEDICATIONS = 100
MAX_RECORDS_PER_TYPE = 500
AI_CONSENT_VERSION = "2026-09-15.3"


def strict_int_field(*, minimum: int, maximum: int):
    return Field(strict=True, ge=minimum, le=maximum)


class StrictModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        extra="forbid",
        populate_by_name=True,
        str_strip_whitespace=True,
    )


class BloodPressure(StrictModel):
    systolic: int = strict_int_field(minimum=40, maximum=300)
    diastolic: int = strict_int_field(minimum=20, maximum=200)

    @model_validator(mode="after")
    def systolic_must_exceed_diastolic(self) -> Self:
        if self.systolic <= self.diastolic:
            raise ValueError("systolic blood pressure must exceed diastolic blood pressure")
        return self


class MedicationDefinition(StrictModel):
    id: str = Field(min_length=1, max_length=64)
    name: str = Field(min_length=1, max_length=120)
    dose: str = Field(default="", max_length=120)
    time_window: str = Field(default="", max_length=120)
    frequency: str = Field(default="", max_length=80)
    is_active: bool = True
    start_date: date | None = None
    end_date: date | None = None

    @model_validator(mode="after")
    def end_date_must_not_precede_start_date(self) -> Self:
        if self.start_date and self.end_date and self.end_date < self.start_date:
            raise ValueError("medication end date must not precede start date")
        return self


class MedicationEvent(StrictModel):
    id: str = Field(min_length=1, max_length=64)
    medicine_id: str = Field(min_length=1, max_length=64)
    recorded_at: datetime
    scheduled_window: str = Field(default="", max_length=120)
    # Older app versions omitted this field; their completed records are
    # inferred from takenAt for backwards compatibility.
    is_completed: bool | None = None
    taken_at: str | None = Field(default=None, max_length=80)
    feeling: str | None = Field(default=None, max_length=80)
    interval: str = Field(default="", max_length=80)
    heart_rate: int | None = Field(default=None, strict=True, ge=20, le=300)
    blood_pressure: BloodPressure | None = None
    notes: str = Field(default="", max_length=1000)


class JournalEntry(StrictModel):
    id: str = Field(min_length=1, max_length=64)
    entry_type: Literal["mood", "symptoms", "bloodPressure", "heartRate"]
    recorded_at: datetime
    mood: str | None = Field(default=None, max_length=80)
    symptom: str | None = Field(default=None, max_length=120)
    severity: str | None = Field(default=None, max_length=40)
    heart_rate: int | None = Field(default=None, strict=True, ge=20, le=300)
    blood_pressure: BloodPressure | None = None
    medication_event_id: str | None = Field(default=None, max_length=64)


class QuestionType(str, Enum):
    side_effects = "side_effects"
    consistency = "consistency"
    vitals = "vitals"
    doctor_summary = "doctor_summary"
    free_text = "free_text"


class DateRange(StrictModel):
    start: date
    end: date

    @model_validator(mode="after")
    def validate_range(self) -> Self:
        if self.end < self.start:
            raise ValueError("date range end must not precede start")
        inclusive_days = (self.end - self.start).days + 1
        if inclusive_days > MAX_DATE_RANGE_DAYS:
            raise ValueError(f"date range cannot exceed {MAX_DATE_RANGE_DAYS} days")
        return self


class AssistantRequest(StrictModel):
    request_id: str = Field(
        min_length=1,
        max_length=64,
        pattern=r"^[A-Za-z0-9][A-Za-z0-9._:-]*$",
    )
    date_range: DateRange
    question_type: QuestionType
    user_question: str = Field(default="", max_length=1000)
    medications: list[MedicationDefinition] = Field(default_factory=list, max_length=MAX_MEDICATIONS)
    medication_events: list[MedicationEvent] = Field(default_factory=list, max_length=MAX_RECORDS_PER_TYPE)
    journal_entries: list[JournalEntry] = Field(default_factory=list, max_length=MAX_RECORDS_PER_TYPE)
    language: str = Field(
        default="en-US",
        min_length=2,
        max_length=35,
        pattern=r"^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$",
    )
    timezone: str = Field(default="UTC", max_length=64)
    consent_version: str = Field(min_length=1, max_length=40)

    @field_validator("consent_version")
    @classmethod
    def consent_must_match_current_disclosure(cls, value: str) -> str:
        if value != AI_CONSENT_VERSION:
            raise ValueError("consentVersion must match the current AI data disclosure")
        return value

    @field_validator("timezone")
    @classmethod
    def timezone_must_be_known(cls, value: str) -> str:
        try:
            ZoneInfo(value)
        except (ValueError, ZoneInfoNotFoundError) as error:
            raise ValueError("timezone must be a valid IANA time zone") from error
        return value


class Observation(StrictModel):
    text: str = Field(min_length=1, max_length=600)
    evidence_ids: list[str] = Field(min_length=1, max_length=50)


class Evidence(StrictModel):
    id: str = Field(min_length=1, max_length=120)
    statistic: str = Field(min_length=1, max_length=80)
    value: int | float | str
    unit: str | None = Field(default=None, max_length=40)
    relation: Literal["before", "after", "same_time", "same_record"] | None = None
    source_record_ids: list[str] = Field(min_length=1, max_length=1000)


class DeterministicSummary(StrictModel):
    evidence: list[Evidence] = Field(default_factory=list, max_length=5000)


class OpenAIObservation(StrictModel):
    """Provider schema limited to constraints supported by Structured Outputs."""

    text: str
    evidence_ids: list[str]


class OpenAIAssistantOutput(StrictModel):
    """Minimal model contract: prose only; safety and UI fields stay server-owned."""

    # Ignore legacy fixture fields while the API schema intentionally remains
    # summary-only. The Responses SDK receives only this declared field.
    model_config = ConfigDict(extra="ignore", populate_by_name=True)
    summary: str


class DoctorSummarySymptom(StrictModel):
    label: str = Field(min_length=1, max_length=120)
    count: int = strict_int_field(minimum=1, maximum=500)


class DoctorSummaryMedicineRow(StrictModel):
    medicine: str = Field(min_length=1, max_length=120)
    symptoms: list[DoctorSummarySymptom] = Field(default_factory=list, max_length=6)


class DoctorSummaryVital(StrictModel):
    range: str = Field(min_length=1, max_length=80)
    latest: str = Field(min_length=1, max_length=40)


class DoctorSummaryTable(StrictModel):
    medicines: list[DoctorSummaryMedicineRow] = Field(default_factory=list, max_length=20)
    heart_rate: DoctorSummaryVital | None = None
    blood_pressure: DoctorSummaryVital | None = None


class AfterDoseVitalsMedicineRow(StrictModel):
    medicine: str = Field(min_length=1, max_length=120)
    heart_rate_count: int = strict_int_field(minimum=0, maximum=500)
    heart_rate_range: str | None = Field(default=None, min_length=1, max_length=80)
    blood_pressure_count: int = strict_int_field(minimum=0, maximum=500)
    blood_pressure_range: str | None = Field(default=None, min_length=1, max_length=80)


class AfterDoseVitalsTable(StrictModel):
    medicines: list[AfterDoseVitalsMedicineRow] = Field(default_factory=list, max_length=20)


class CheckInTimingMedicineRow(StrictModel):
    medicine: str = Field(min_length=1, max_length=120)
    taken: int = strict_int_field(minimum=0, maximum=500)
    on_time: int = strict_int_field(minimum=0, maximum=500)
    early: int = strict_int_field(minimum=0, maximum=500)
    late: int = strict_int_field(minimum=0, maximum=500)
    without_timing: int = strict_int_field(minimum=0, maximum=500)


class CheckInTimingTable(StrictModel):
    medicines: list[CheckInTimingMedicineRow] = Field(default_factory=list, max_length=20)
    complete_days: int = strict_int_field(minimum=0, maximum=366)
    tracked_days: int = strict_int_field(minimum=0, maximum=366)


class AssistantNarrative(StrictModel):
    status: Literal["ok", "needs_clarification", "refusal", "safety_escalation"]
    summary: str = Field(min_length=1, max_length=1200)
    observations: list[Observation] = Field(default_factory=list, max_length=10)
    follow_up_questions: list[str] = Field(default_factory=list, max_length=5)
    disclaimer: str = Field(min_length=1, max_length=300)
    doctor_summary_table: DoctorSummaryTable | None = None
    after_dose_vitals_table: AfterDoseVitalsTable | None = None
    check_in_timing_table: CheckInTimingTable | None = None


class AssistantResponse(AssistantNarrative):
    evidence: list[Evidence] = Field(default_factory=list, max_length=5000)

    @model_validator(mode="after")
    def observations_must_reference_included_evidence(self) -> Self:
        evidence_ids = [item.id for item in self.evidence]
        if len(evidence_ids) != len(set(evidence_ids)):
            raise ValueError("evidence IDs must be unique")
        unknown_ids = {
            evidence_id
            for observation in self.observations
            for evidence_id in observation.evidence_ids
            if evidence_id not in evidence_ids
        }
        if unknown_ids:
            raise ValueError("every observation must reference included evidence")
        return self


class RequestContextResponse(StrictModel):
    request_id: str
    created_at: datetime
    completed_at: datetime | None = None
    status_code: int | None = None
    error_type: str | None = None


class DeleteRequestDataResponse(StrictModel):
    deleted_count: int = Field(ge=0)
