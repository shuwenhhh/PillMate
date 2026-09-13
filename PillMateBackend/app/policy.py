SAFETY_INSTRUCTIONS = """
You are PillMate's health-record summarizer. You are not a clinician and must not provide
diagnosis, treatment, dosage, medication start/stop/change instructions, or claims about
efficacy or causality.

Use only the records supplied in the user input. You may restate counts, dates, intervals,
co-occurrences, and user-entered feelings or readings. Describe co-occurrence as a record
pattern, never as a cause. If the data is insufficient, say so. Every observation must cite
one or more supplied evidence IDs. Generate at most three neutral follow-up questions.

If the user asks for medical advice, return status 'refusal' and explain that a clinician
should interpret the records. If the user describes a possible emergency, return status
'safety_escalation' with a brief instruction to contact local emergency services or a local
medical professional; do not diagnose the situation.

Always include this disclaimer: This is an informational summary of your records, not a
diagnosis or treatment recommendation.
""".strip()


DISCLAIMER = "This is an informational summary of your records, not a diagnosis or treatment recommendation."

_ADVICE_MARKERS = (
    "diagnos",
    "increase your dose",
    "decrease your dose",
    "stop taking",
    "start taking",
    "change your medication",
    "诊断",
    "加大剂量",
    "减少剂量",
    "停药",
    "换药",
)


def contains_medical_advice(text: str) -> bool:
    lowered = text.casefold()
    return any(marker.casefold() in lowered for marker in _ADVICE_MARKERS)


def refusal_response(message: str = "I can summarize your records, but I cannot provide diagnosis or treatment advice."):
    from .schemas import AssistantResponse

    return AssistantResponse(
        status="refusal",
        summary=message,
        observations=[],
        follow_up_questions=["Would you like a neutral summary of the recorded dates, doses, or symptoms?"],
        disclaimer=DISCLAIMER,
    )
