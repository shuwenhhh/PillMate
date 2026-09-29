import hashlib
import json
import re
from collections import defaultdict
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from ..schemas import (
    AssistantRequest,
    DeterministicSummary,
    Evidence,
    JournalEntry,
    MedicationEvent,
)


_CLOCK_PATTERN = re.compile(
    r"^(?P<hour>\d{1,2}):(?P<minute>\d{2})(?:\s*(?P<suffix>AM|PM))?$",
    re.IGNORECASE,
)


def _clock_minutes(value: str, inherited_suffix: str | None = None) -> int | None:
    match = _CLOCK_PATTERN.fullmatch(value.strip())
    if match is None:
        return None
    hour = int(match.group("hour"))
    minute = int(match.group("minute"))
    suffix = (match.group("suffix") or inherited_suffix or "").upper()
    if minute > 59:
        return None
    if suffix:
        if not 1 <= hour <= 12:
            return None
        hour = hour % 12 + (12 if suffix == "PM" else 0)
    elif hour > 23:
        return None
    return hour * 60 + minute


def _time_window_minutes(value: str) -> tuple[int, int] | None:
    parts = [part.strip() for part in value.replace("–", "-").split("-")]
    if len(parts) != 2 or not all(parts):
        return None
    suffix_match = re.search(r"\b(AM|PM)\b", parts[1], re.IGNORECASE)
    suffix = suffix_match.group(1) if suffix_match else None
    start = _clock_minutes(parts[0], suffix)
    end = _clock_minutes(parts[1])
    return (start, end) if start is not None and end is not None else None


def _event_time(event: MedicationEvent, timezone: ZoneInfo) -> datetime | None:
    if event.taken_at is None:
        return None
    minutes = _clock_minutes(event.taken_at)
    if minutes is None:
        return None
    recorded_at = event.recorded_at
    if recorded_at.tzinfo is None:
        local_date = recorded_at.date()
    else:
        local_date = recorded_at.astimezone(timezone).date()
    return datetime.combine(local_date, time(minutes // 60, minutes % 60), timezone)


def medication_timing(
    event: MedicationEvent,
    medicine_window: str,
    timezone: ZoneInfo,
) -> str:
    """Classify one completed check-in without treating early/late as incomplete."""

    event_time = _event_time(event, timezone)
    window_text = event.scheduled_window or medicine_window
    window = _time_window_minutes(window_text)
    if event.taken_at is None or event_time is None or window is None:
        return "without_timing"

    actual = event_time.hour * 60 + event_time.minute
    start, end = window
    normalized_end = end + 24 * 60 if end < start else end
    closest: tuple[int, str] | None = None
    for shift in (-24 * 60, 0, 24 * 60):
        shifted_start = start + shift
        shifted_end = normalized_end + shift
        if shifted_start <= actual <= shifted_end:
            return "on_time"
        candidate = (
            (shifted_start - actual, "early")
            if actual < shifted_start
            else (actual - shifted_end, "late")
        )
        if closest is None or candidate[0] < closest[0]:
            closest = candidate
    return closest[1] if closest else "without_timing"


def _relation(offset_minutes: int, *, same_record: bool = False) -> str:
    if same_record:
        return "same_record"
    if offset_minutes < 0:
        return "before"
    if offset_minutes > 0:
        return "after"
    return "same_time"


def _local_datetime(value: datetime, timezone: ZoneInfo) -> datetime:
    return value.replace(tzinfo=timezone) if value.tzinfo is None else value.astimezone(timezone)


def _daily_dose_count(frequency: str) -> int | None:
    """Return scheduled daily doses; PRN and unknown schedules are not assumed."""

    normalized = " ".join(frequency.casefold().replace("-", " ").split())
    counts = {
        "daily": 1,
        "once a day": 1,
        "once daily": 1,
        "twice a day": 2,
        "twice daily": 2,
        "three times a day": 3,
        "three times daily": 3,
        "four times a day": 4,
        "four times daily": 4,
    }
    return counts.get(normalized)


def _evidence(
    statistic: str,
    value: int | float | str,
    source_record_ids: list[str],
    *,
    unit: str | None = None,
    relation: str | None = None,
) -> Evidence:
    identity = json.dumps(
        {
            "statistic": statistic,
            "value": value,
            "unit": unit,
            "relation": relation,
            "sourceRecordIds": source_record_ids,
        },
        ensure_ascii=True,
        separators=(",", ":"),
        sort_keys=True,
    )
    digest = hashlib.sha256(identity.encode("utf-8")).hexdigest()[:20]
    return Evidence(
        id=f"evidence:{statistic}:{digest}",
        statistic=statistic,
        value=value,
        unit=unit,
        relation=relation,
        source_record_ids=source_record_ids,
    )


def _nearest_medication(
    recorded_at: datetime,
    medication_times: list[tuple[datetime, str]],
    timezone: ZoneInfo,
) -> tuple[int, str] | None:
    if not medication_times:
        return None
    local_recorded_at = _local_datetime(recorded_at, timezone)
    medication_time, medication_id = min(
        medication_times,
        key=lambda item: (
            abs((local_recorded_at - item[0]).total_seconds()),
            item[0],
            item[1],
        ),
    )
    offset_minutes = round((local_recorded_at - medication_time).total_seconds() / 60)
    return offset_minutes, medication_id


def _assert_unambiguous_ids(request: AssistantRequest) -> None:
    medication_ids = [event.id for event in request.medication_events]
    journal_ids = [entry.id for entry in request.journal_entries]
    if len(medication_ids) != len(set(medication_ids)):
        raise ValueError("medication event IDs must be unique")
    if len(journal_ids) != len(set(journal_ids)):
        raise ValueError("journal entry IDs must be unique")
    if set(medication_ids) & set(journal_ids):
        raise ValueError("record IDs must be unique across medication events and journal entries")


def summarize_records(request: AssistantRequest) -> DeterministicSummary:
    """Calculate stable facts; language models must not calculate record statistics."""
    _assert_unambiguous_ids(request)
    timezone = ZoneInfo(request.timezone)
    evidence: list[Evidence] = []
    medicine_windows = {medicine.id: medicine.time_window for medicine in request.medications}

    taken_events: list[tuple[MedicationEvent, datetime | None]] = [
        (event, _event_time(event, timezone))
        for event in request.medication_events
        if event.is_completed is True or (event.is_completed is None and event.taken_at is not None)
    ]
    taken_events.sort(
        key=lambda item: (item[1] or datetime.max.replace(tzinfo=timezone), item[0].id)
    )
    if taken_events:
        evidence.append(
            _evidence(
                "medication.taken_count",
                len(taken_events),
                sorted(event.id for event, _ in taken_events),
                unit="records",
            )
        )

    timing_groups: dict[str, list[str]] = {"inside": [], "outside": [], "unclassified": []}
    for event, _ in taken_events:
        timing = medication_timing(
            event,
            medicine_windows.get(event.medicine_id, ""),
            timezone,
        )
        group = {
            "on_time": "inside",
            "early": "outside",
            "late": "outside",
            "without_timing": "unclassified",
        }[timing]
        timing_groups[group].append(event.id)
    for name in ("inside", "outside", "unclassified"):
        source_ids = sorted(timing_groups[name])
        if source_ids:
            evidence.append(
                _evidence(
                    f"medication.window_{name}_count",
                    len(source_ids),
                    source_ids,
                    unit="records",
                )
            )

    # Count days on which every scheduled dose for every active medication was
    # completed. PRN and unknown-frequency medicines are excluded rather than
    # guessed. Medication lifecycle dates make fully missed days visible too.
    scheduled_medications = {
        medicine.id: (medicine, dose_count)
        for medicine in request.medications
        if (dose_count := _daily_dose_count(medicine.frequency)) is not None
        and (medicine.is_active or medicine.end_date is not None)
    }
    taken_by_day_and_medicine: dict[date, dict[str, list[str]]] = defaultdict(
        lambda: defaultdict(list)
    )
    all_taken_ids = sorted(event.id for event, _ in taken_events)
    for event, event_time in taken_events:
        event_date = (
            event_time.date()
            if event_time is not None
            else _local_datetime(event.recorded_at, timezone).date()
        )
        taken_by_day_and_medicine[event_date][event.medicine_id].append(event.id)

    scheduled_days = 0
    fully_completed_days = 0
    completed_day_source_ids: list[str] = []
    current_day = request.date_range.start
    while current_day <= request.date_range.end:
        required = {
            medicine_id: dose_count
            for medicine_id, (medicine, dose_count) in scheduled_medications.items()
            if (medicine.start_date is None or medicine.start_date <= current_day)
            and (medicine.end_date is None or current_day <= medicine.end_date)
        }
        if required:
            scheduled_days += 1
            completed = taken_by_day_and_medicine.get(current_day, {})
            if all(len(completed.get(medicine_id, [])) >= count for medicine_id, count in required.items()):
                fully_completed_days += 1
                completed_day_source_ids.extend(
                    event_id
                    for medicine_id in sorted(required)
                    for event_id in sorted(completed.get(medicine_id, []))
                )
        current_day += timedelta(days=1)

    if scheduled_days and all_taken_ids:
        evidence.append(
            _evidence(
                "medication.scheduled_day_count",
                scheduled_days,
                all_taken_ids,
                unit="days",
            )
        )
        evidence.append(
            _evidence(
                "medication.fully_completed_day_count",
                fully_completed_days,
                sorted(set(completed_day_source_ids)) or all_taken_ids,
                unit="days",
            )
        )

    by_medicine: dict[str, list[tuple[datetime, str]]] = defaultdict(list)
    medication_times: list[tuple[datetime, str]] = []
    for event, event_time in taken_events:
        if event_time is not None:
            by_medicine[event.medicine_id].append((event_time, event.id))
            medication_times.append((event_time, event.id))
    medication_times.sort(key=lambda item: (item[0], item[1]))
    for medicine_id in sorted(by_medicine):
        events = sorted(by_medicine[medicine_id], key=lambda item: (item[0], item[1]))
        for previous, current in zip(events, events[1:]):
            minutes = round((current[0] - previous[0]).total_seconds() / 60)
            evidence.append(
                _evidence(
                    "medication.interval_minutes",
                    minutes,
                    [previous[1], current[1]],
                    unit="minutes",
                    relation="after",
                )
            )

    journal_groups: dict[str, list[JournalEntry]] = {
        entry_type: sorted(
            (entry for entry in request.journal_entries if entry.entry_type == entry_type),
            key=lambda entry: (_local_datetime(entry.recorded_at, timezone), entry.id),
        )
        for entry_type in ("mood", "symptoms", "bloodPressure", "heartRate")
    }
    statistic_names = {
        "mood": "mood.record_count",
        "symptoms": "symptoms.record_count",
    }
    for entry_type in ("mood", "symptoms"):
        entries = journal_groups[entry_type]
        if entries:
            evidence.append(
                _evidence(
                    statistic_names[entry_type],
                    len(entries),
                    [entry.id for entry in entries],
                    unit="records",
                )
            )

    # Preserve the actual words the person recorded (for example, “Feeling
    # good” or “Dizzy”), not merely their total count.  When a journal entry is
    # linked to a check-in, its evidence also carries that exact dose event.
    for entry_type in ("mood", "symptoms"):
        for entry in journal_groups[entry_type]:
            value = entry.mood if entry_type == "mood" else entry.symptom
            if not value:
                continue
            source_ids = [entry.id]
            relation = None
            if entry.medication_event_id:
                source_ids.append(entry.medication_event_id)
                relation = "same_record"
            else:
                nearest = _nearest_medication(entry.recorded_at, medication_times, timezone)
                if nearest is not None:
                    offset, medication_event_id = nearest
                    source_ids.append(medication_event_id)
                    relation = _relation(offset)
            evidence.append(
                _evidence(
                    f"{entry_type}.recorded_value",
                    value,
                    source_ids,
                    relation=relation,
                )
            )

    for event, _ in taken_events:
        if event.feeling:
            evidence.append(
                _evidence(
                    "medication.feeling",
                    event.feeling,
                    [event.id],
                    relation="same_record",
                )
            )

    medication_bp = sorted(
        (event for event in request.medication_events if event.blood_pressure is not None),
        key=lambda event: event.id,
    )
    medication_hr = sorted(
        (event for event in request.medication_events if event.heart_rate is not None),
        key=lambda event: event.id,
    )
    blood_pressure_ids = sorted(
        [entry.id for entry in journal_groups["bloodPressure"]] + [event.id for event in medication_bp]
    )
    heart_rate_ids = sorted(
        [entry.id for entry in journal_groups["heartRate"]] + [event.id for event in medication_hr]
    )
    if blood_pressure_ids:
        evidence.append(
            _evidence(
                "blood_pressure.record_count",
                len(blood_pressure_ids),
                blood_pressure_ids,
                unit="records",
            )
        )
    if heart_rate_ids:
        evidence.append(
            _evidence(
                "heart_rate.record_count",
                len(heart_rate_ids),
                heart_rate_ids,
                unit="records",
            )
        )

    for entry_type in ("mood", "symptoms", "bloodPressure", "heartRate"):
        statistic = {
            "mood": "mood.medication_offset_minutes",
            "symptoms": "symptoms.medication_offset_minutes",
            "bloodPressure": "blood_pressure.medication_offset_minutes",
            "heartRate": "heart_rate.medication_offset_minutes",
        }[entry_type]
        for entry in journal_groups[entry_type]:
            nearest = _nearest_medication(entry.recorded_at, medication_times, timezone)
            if nearest is not None:
                offset, medication_id = nearest
                evidence.append(
                    _evidence(
                        statistic,
                        offset,
                        [entry.id, medication_id],
                        unit="minutes",
                        relation=_relation(offset),
                    )
                )
    for event in medication_bp:
        evidence.append(
            _evidence(
                "blood_pressure.medication_offset_minutes",
                0,
                [event.id],
                unit="minutes",
                relation="same_record",
            )
        )
    for event in medication_hr:
        evidence.append(
            _evidence(
                "heart_rate.medication_offset_minutes",
                0,
                [event.id],
                unit="minutes",
                relation="same_record",
            )
        )

    return DeterministicSummary(evidence=evidence)
