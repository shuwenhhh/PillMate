# PillMate Backend

Python + FastAPI backend for PillMate's records-only AI assistant.

## Responsibilities

- Accept a date-bounded, minimal JSON payload from the SwiftUI app.
- Validate medication and health-record fields with Pydantic.
- Run input and output moderation around the AI request.
- Call the OpenAI Responses API with a strict `AssistantResponse` schema and `store=False`.
- Enforce a fixed disclaimer, evidence IDs, and a small server-side advice filter before returning structured JSON.

The backend must never expose `OPENAI_API_KEY` to the iOS app. Keep SwiftData as the source
of truth in the first version and send only the records needed for the selected question.

## Local development

```bash
cd PillMateBackend
python3 -m venv .venv
source .venv/bin/activate
pip install -e '.[dev]'
cp .env.example .env
uvicorn app.main:app --reload --port 8000
```

Health check:

```bash
curl http://localhost:8000/health
```

AI endpoint: `POST /v1/assistant/analyze`

The endpoint intentionally returns `503` until `OPENAI_API_KEY` is configured. Do not put a
real key in source control.

## Safety boundary

The assistant summarizes supplied records only. It must not diagnose, interpret a reading as
a disease, recommend starting/stopping/changing medication, or claim that one event caused
another. The API returns a refusal or neutral emergency escalation when a request crosses
that boundary.

## Next steps

1. Add authentication (for example, verify Sign in with Apple tokens at the backend).
2. Add per-user rate limits and a redacted request ID log.
3. Add deterministic statistics before the model call.
4. Connect `RecordsAssistantView` with Swift `URLSession`.
5. Add adversarial safety tests and deploy behind HTTPS.
