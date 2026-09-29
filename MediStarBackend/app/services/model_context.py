from __future__ import annotations

from collections import Counter, defaultdict
from datetime import timedelta
from typing import Any
from zoneinfo import ZoneInfo

from ..schemas import AssistantRequest, DeterministicSummary, Evidence
from .record_summary import medication_timing


_ADHERENCE_STATISTICS = {
    "medication.taken_count": "completedCheckIns",
    "medication.window_inside_count": "onTimeCheckIns",
    "medication.window_outside_count": "outsideScheduleCheckIns",
    "medication.window_unclassified_count": "checkInsWithoutTimingDetails",
    "medication.scheduled_day_count": "scheduledDays",
    "medication.fully_completed_day_count": "daysAllScheduledMedicinesCompleted",
}

_RELATION_LABELS = {
    None: "not linked to a dose",
    "before": "before",
    "after": "after",
    "same_time": "at the same time",
    "same_record": "in the same check-in",
}


def _scheduled_dose_count(frequency: str) -> int | None:
    return {
        "daily": 1,
        "once a day": 1,
        "once daily": 1,
        "twice a day": 2,
        "twice daily": 2,
        "three times a day": 3,
        "three times daily": 3,
        "four times a day": 4,
        "four times daily": 4,
    }.get(" ".join(frequency.casefold().replace("-", " ").split()))


def _counter_rows(counter: Counter[tuple[str, str]], limit: int = 10) -> list[dict[str, Any]]:
    ordered = sorted(
        counter.items(),
        key=lambda item: (-item[1], item[0][0].casefold(), item[0][1]),
    )[:limit]
    return [
        {"value": value, "count": count, "timing": timing}
        for (value, timing), count in ordered
    ]


def _number_summary(values: list[tuple[Any, int]]) -> dict[str, Any] | None:
    if not values:
        return None
    ordered = sorted(values, key=lambda item: item[0])
    numbers = [value for _, value in ordered]
    return {
        "count": len(numbers),
        "minimum": min(numbers),
        "maximum": max(numbers),
        "firstRecorded": numbers[0],
        "lastRecorded": numbers[-1],
    }


def _blood_pressure_summary(
    values: list[tuple[Any, tuple[int, int]]],
) -> dict[str, Any] | None:
    if not values:
        return None
    ordered = sorted(values, key=lambda item: item[0])
    readings = [value for _, value in ordered]
    systolic = [value[0] for value in readings]
    diastolic = [value[1] for value in readings]
    return {
        "count": len(readings),
        "systolicMinimum": min(systolic),
        "systolicMaximum": max(systolic),
        "diastolicMinimum": min(diastolic),
        "diastolicMaximum": max(diastolic),
        "firstRecorded": {"systolic": readings[0][0], "diastolic": readings[0][1]},
        "lastRecorded": {"systolic": readings[-1][0], "diastolic": readings[-1][1]},
    }


def _linked_event_id(evidence: Evidence, event_ids: set[str]) -> str | None:
    return next(
        (source_id for source_id in evidence.source_record_ids if source_id in event_ids),
        None,
    )


def build_model_facts(
    request: AssistantRequest,
    deterministic_summary: DeterministicSummary,
) -> dict[str, Any]:
    """Build a small, factual model context without duplicating raw records.

    The server performs counting and linking. The model only turns these facts into
    warm prose, which reduces input size and prevents arithmetic drift.
    """

    medicines = {medicine.id: medicine for medicine in request.medications}
    events = {event.id: event for event in request.medication_events}
    event_ids = set(events)

    adherence: dict[str, int | float | str] = {}
    for evidence in deterministic_summary.evidence:
        if key := _ADHERENCE_STATISTICS.get(evidence.statistic):
            adherence[key] = evidence.value

    # A medication event represents a completed dose even if its optional clock
    # time was not captured. Calculate exact incomplete dates separately from
    # timing so “Which day did I forget?” has a direct, factual answer.
    completed_by_day: dict[tuple[object, str], int] = Counter()
    for event in request.medication_events:
        if event.is_completed is True or (event.is_completed is None and event.taken_at is not None):
            completed_by_day[(event.recorded_at.date(), event.medicine_id)] += 1
    missing_scheduled_dates: list[str] = []
    day = request.date_range.start
    while day <= request.date_range.end:
        required = [
            (medicine.id, dose_count)
            for medicine in request.medications
            if (dose_count := _scheduled_dose_count(medicine.frequency)) is not None
            and (medicine.start_date is None or medicine.start_date <= day)
            and (medicine.end_date is None or day <= medicine.end_date)
            and medicine.is_active
        ]
        if required and any(completed_by_day[(day, medicine_id)] < dose_count for medicine_id, dose_count in required):
            missing_scheduled_dates.append(day.isoformat())
        day += timedelta(days=1)

    observations: dict[str, dict[str, Counter[tuple[str, str]]]] = defaultdict(
        lambda: {
            "recordedFeelings": Counter(),
            "recordedSymptoms": Counter(),
            "recordedMoods": Counter(),
        }
    )
    unlinked: dict[str, Counter[tuple[str, str]]] = {
        "recordedSymptoms": Counter(),
        "recordedMoods": Counter(),
    }

    for event in request.medication_events:
        if event.feeling:
            observations[event.medicine_id]["recordedFeelings"][
                (event.feeling, "in the same check-in")
            ] += 1

    for evidence in deterministic_summary.evidence:
        category = {
            "symptoms.recorded_value": "recordedSymptoms",
            "mood.recorded_value": "recordedMoods",
        }.get(evidence.statistic)
        if category is None:
            continue
        timing = _RELATION_LABELS[evidence.relation]
        linked_event_id = _linked_event_id(evidence, event_ids)
        linked_event = events.get(linked_event_id) if linked_event_id else None
        key = (str(evidence.value), timing)
        if linked_event is None:
            unlinked[category][key] += 1
        else:
            observations[linked_event.medicine_id][category][key] += 1

    heart_rate_values: list[tuple[Any, int]] = []
    blood_pressure_values: list[tuple[Any, tuple[int, int]]] = []
    medication_heart_rates: dict[str, list[tuple[Any, int]]] = defaultdict(list)
    medication_blood_pressures: dict[str, list[tuple[Any, tuple[int, int]]]] = defaultdict(list)

    for event in request.medication_events:
        if event.heart_rate is not None:
            value = (event.recorded_at, event.heart_rate)
            heart_rate_values.append(value)
            medication_heart_rates[event.medicine_id].append(value)
        if event.blood_pressure is not None:
            value = (
                event.recorded_at,
                (event.blood_pressure.systolic, event.blood_pressure.diastolic),
            )
            blood_pressure_values.append(value)
            medication_blood_pressures[event.medicine_id].append(value)

    offsets: dict[tuple[str, str], Evidence] = {}
    for evidence in deterministic_summary.evidence:
        if evidence.statistic in {
            "heart_rate.medication_offset_minutes",
            "blood_pressure.medication_offset_minutes",
        }:
            offsets[(evidence.statistic, evidence.source_record_ids[0])] = evidence

    for entry in request.journal_entries:
        if entry.heart_rate is not None:
            value = (entry.recorded_at, entry.heart_rate)
            heart_rate_values.append(value)
            linked_id = entry.medication_event_id if entry.medication_event_id in events else None
            if linked_id is None:
                association = offsets.get(("heart_rate.medication_offset_minutes", entry.id))
                linked_id = _linked_event_id(association, event_ids) if association else None
            if linked_id:
                medication_heart_rates[events[linked_id].medicine_id].append(value)
        if entry.blood_pressure is not None:
            value = (
                entry.recorded_at,
                (entry.blood_pressure.systolic, entry.blood_pressure.diastolic),
            )
            blood_pressure_values.append(value)
            linked_id = entry.medication_event_id if entry.medication_event_id in events else None
            if linked_id is None:
                association = offsets.get(("blood_pressure.medication_offset_minutes", entry.id))
                linked_id = _linked_event_id(association, event_ids) if association else None
            if linked_id:
                medication_blood_pressures[events[linked_id].medicine_id].append(value)

    medication_rows: list[dict[str, Any]] = []
    for medicine_id, medicine in sorted(
        medicines.items(), key=lambda item: (item[1].name.casefold(), item[0])
    ):
        counters = observations[medicine_id]
        row: dict[str, Any] = {
            "medicine": medicine.name,
            "dose": medicine.dose,
            "completedCheckIns": sum(
                1
                for event in request.medication_events
                if event.medicine_id == medicine_id and event.taken_at is not None
            ),
        }
        for category in ("recordedFeelings", "recordedSymptoms", "recordedMoods"):
            if counters[category]:
                row[category] = _counter_rows(counters[category])
        if summary := _number_summary(medication_heart_rates[medicine_id]):
            row["nearbyHeartRate"] = summary
        if summary := _blood_pressure_summary(medication_blood_pressures[medicine_id]):
            row["nearbyBloodPressure"] = summary
        medication_rows.append(row)

    facts: dict[str, Any] = {
        "selectedPeriod": {
            "start": request.date_range.start.isoformat(),
            "end": request.date_range.end.isoformat(),
        },
        "adherence": adherence,
        "medications": medication_rows,
    }
    if missing_scheduled_dates:
        facts["missingScheduledDates"] = missing_scheduled_dates
    if summary := _number_summary(heart_rate_values):
        facts["overallHeartRate"] = summary
    if summary := _blood_pressure_summary(blood_pressure_values):
        facts["overallBloodPressure"] = summary
    if unlinked["recordedSymptoms"]:
        facts["symptomsNotLinkedToOneMedicine"] = _counter_rows(
            unlinked["recordedSymptoms"]
        )
    if unlinked["recordedMoods"]:
        facts["moodsNotLinkedToOneMedicine"] = _counter_rows(unlinked["recordedMoods"])
    return facts


def build_doctor_summary_table(
    request: AssistantRequest,
    deterministic_summary: DeterministicSummary,
) -> dict[str, Any]:
    """Create display-ready, deterministic rows for the doctor-summary table."""

    facts = build_model_facts(request, deterministic_summary)
    medicines: list[dict[str, Any]] = []
    for medicine in facts["medications"]:
        counts: Counter[str] = Counter()
        for key in ("recordedSymptoms", "recordedFeelings"):
            for item in medicine.get(key, []):
                counts[item["value"]] += item["count"]
        if not counts:
            continue
        symptoms = [
            {"label": label, "count": count}
            for label, count in sorted(counts.items(), key=lambda item: (-item[1], item[0].casefold()))[:6]
        ]
        medicines.append({"medicine": medicine["medicine"], "symptoms": symptoms})

    table: dict[str, Any] = {"medicines": medicines}
    if heart_rate := facts.get("overallHeartRate"):
        table["heartRate"] = {
            "range": f"{heart_rate['minimum']}–{heart_rate['maximum']} bpm",
            "latest": f"{heart_rate['lastRecorded']} bpm",
        }
    if blood_pressure := facts.get("overallBloodPressure"):
        table["bloodPressure"] = {
            "range": (
                f"{blood_pressure['systolicMinimum']}–{blood_pressure['systolicMaximum']} / "
                f"{blood_pressure['diastolicMinimum']}–{blood_pressure['diastolicMaximum']} mmHg"
            ),
            "latest": (
                f"{blood_pressure['lastRecorded']['systolic']} / "
                f"{blood_pressure['lastRecorded']['diastolic']} mmHg"
            ),
        }
    return table


def build_after_dose_vitals_table(
    request: AssistantRequest,
    deterministic_summary: DeterministicSummary,
) -> dict[str, Any]:
    """Create one compact row per medicine with recorded after-dose vitals."""

    facts = build_model_facts(request, deterministic_summary)
    medicines: list[dict[str, Any]] = []
    for medicine in facts["medications"]:
        heart_rate = medicine.get("nearbyHeartRate")
        blood_pressure = medicine.get("nearbyBloodPressure")
        if heart_rate is None and blood_pressure is None:
            continue

        row: dict[str, Any] = {
            "medicine": medicine["medicine"],
            "heartRateCount": heart_rate["count"] if heart_rate else 0,
            "heartRateRange": (
                f"{heart_rate['minimum']}–{heart_rate['maximum']} bpm"
                if heart_rate
                else None
            ),
            "bloodPressureCount": blood_pressure["count"] if blood_pressure else 0,
            "bloodPressureRange": (
                f"{blood_pressure['systolicMinimum']}–{blood_pressure['systolicMaximum']} / "
                f"{blood_pressure['diastolicMinimum']}–{blood_pressure['diastolicMaximum']} mmHg"
                if blood_pressure
                else None
            ),
        }
        medicines.append(row)
    return {"medicines": medicines}


def build_check_in_timing_table(request: AssistantRequest) -> dict[str, Any]:
    """Create per-medicine timing counts and record-driven completion days."""

    timezone = ZoneInfo(request.timezone)
    medicine_by_id = {medicine.id: medicine for medicine in request.medications}
    completed_events = [
        event
        for event in request.medication_events
        if event.is_completed is True
        or (event.is_completed is None and event.taken_at is not None)
    ]
    events_by_medicine: dict[str, list[Any]] = defaultdict(list)
    for event in completed_events:
        events_by_medicine[event.medicine_id].append(event)

    rows: list[dict[str, Any]] = []
    first_day: dict[str, Any] = {}
    required_count: dict[str, int] = {}
    completed_by_day: Counter[tuple[Any, str]] = Counter()

    for medicine_id, events in events_by_medicine.items():
        medicine = medicine_by_id.get(medicine_id)
        if medicine is None:
            continue
        timing_counts: Counter[str] = Counter(
            medication_timing(event, medicine.time_window, timezone) for event in events
        )
        rows.append(
            {
                "medicine": medicine.name,
                "taken": len(events),
                "onTime": timing_counts["on_time"],
                "early": timing_counts["early"],
                "late": timing_counts["late"],
                "withoutTiming": timing_counts["without_timing"],
            }
        )

        event_days = [
            (
                event.recorded_at.replace(tzinfo=timezone)
                if event.recorded_at.tzinfo is None
                else event.recorded_at.astimezone(timezone)
            ).date()
            for event in events
        ]
        first_day[medicine_id] = min(event_days)
        per_day = Counter(event_days)
        configured_count = _scheduled_dose_count(medicine.frequency) or 1
        required_count[medicine_id] = min(configured_count, max(per_day.values()))
        for day, count in per_day.items():
            completed_by_day[(day, medicine_id)] = count

    rows.sort(key=lambda row: row["medicine"].casefold())
    complete_days = 0
    tracked_days = 0
    day = request.date_range.start
    while day <= request.date_range.end:
        required_medicines = [
            medicine_id
            for medicine_id in events_by_medicine
            if medicine_id in first_day
            and first_day[medicine_id] <= day
            and (
                medicine_by_id[medicine_id].end_date is None
                or day <= medicine_by_id[medicine_id].end_date
            )
        ]
        if required_medicines:
            tracked_days += 1
            if all(
                completed_by_day[(day, medicine_id)] >= required_count[medicine_id]
                for medicine_id in required_medicines
            ):
                complete_days += 1
        day += timedelta(days=1)

    return {
        "medicines": rows,
        "completeDays": complete_days,
        "trackedDays": tracked_days,
    }
