# MediStar Backend

Python + FastAPI backend for MediStar's records-only AI assistant.

## Responsibilities

- Accept a date-bounded, minimal JSON payload from the SwiftUI app.
- Validate medication and health-record fields with Pydantic.
- Run input and output moderation around the AI request.
- Call the OpenAI Responses API with a strict `AssistantResponse` schema and `store=False`.
- Enforce a fixed disclaimer, evidence IDs, and a small server-side advice filter before returning structured JSON.
- Verify Sign in with Apple identity tokens and nonces before accepting AI requests.
- Isolate minimal request metadata and enforce per-user minute and UTC-day quotas.

The backend must never expose `OPENAI_API_KEY` to the iOS app. Keep SwiftData as the source
of truth in the first version and send only the records needed for the selected question.

## Local development

```bash
cd MediStarBackend
python3 -m venv .venv
source .venv/bin/activate
pip install -e '.[dev]'
cp .env.example .env
uvicorn app.main:app --reload --port 8000 --no-access-log
```

Health check:

```bash
curl http://localhost:8000/health
```

AI endpoint: `POST /v1/assistant/analyze`

AI routes require both headers below. `APPLE_CLIENT_ID` must match the app's Sign in with
Apple client ID (the native app bundle ID for the iOS flow).

```text
Authorization: Bearer <apple-identity-token>
X-Apple-Nonce: <raw-sign-in-nonce>
```

The server verifies the token signature against Apple's JWKS and validates its issuer,
audience, expiry, subject, and SHA-256 nonce. It never uses the token's email or name as the
user key. The iOS sign-in request must send `SHA256(raw-sign-in-nonce)` to Apple, while the API
header sends the corresponding raw value. `PER_USER_REQUESTS_PER_MINUTE` and
`PER_USER_DAILY_REQUEST_LIMIT` configure the single-process limits; Batch 9 deployment must use
one worker or replace this in-memory limiter with a shared atomic store before scaling
horizontally.

The endpoint intentionally returns `503` until `OPENAI_API_KEY` is configured. Do not put a
real key in source control.

`OPENAI_MODEL` selects the Responses API model and defaults to `gpt-5-mini`. The backend uses
the official OpenAI Python SDK's Pydantic parsing helper so model output must match the
structured assistant schema. Every request explicitly sets `store=False`; it does not attach a
conversation or previous response ID, so calls do not use long-lived conversation state.

## Privacy controls

The iOS app must obtain an active `Allow AI analysis` choice before it sends any health
payload. The API also rejects missing, stale, or unrecognized `consentVersion` values so an
older client cannot silently use a superseded disclosure. This version check is defense in
depth; it does not replace the client's on-screen disclosure and affirmative consent flow.

The backend does not persist the health payload, medication notes, full question, identity
token, nonce, or model output. It keeps only per-user in-memory request metadata: request ID,
timestamps, status code, and error type. Request IDs are one-time within each user's namespace.

- `GET /v1/assistant/requests/{requestId}` reads only the authenticated user's metadata.
- `DELETE /v1/assistant/requests` deletes all of the authenticated user's request metadata.

Application request logs are JSON objects containing only `request_id`, `duration_ms`,
`status_code`, and `error_type`. The app disables Uvicorn's separate access logger; keep
`--no-access-log` in deployment commands as defense in depth.

## Safety boundary

The assistant summarizes supplied records only. It must not diagnose, interpret a reading as
a disease, recommend starting/stopping/changing medication, or claim that one event caused
another. The API returns a refusal or neutral emergency escalation when a request crosses
that boundary. Every model-bound request is moderated first, and every generated narrative is
moderated again before it can be returned. Server-side rules then verify that observation
evidence IDs exist in the deterministic summary and replace the model's disclaimer with the
fixed application disclaimer.

## Next steps

1. Add adversarial safety evaluations.
2. Move rate-limit state to a shared atomic store when deploying multiple workers.
3. Deploy behind HTTPS with Uvicorn's default access log disabled.
