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

`OPENAI_MODEL` selects the Responses API model and defaults to `gpt-5.6-terra`. The backend uses
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

## Production container

The included `Dockerfile` runs the API as a non-root user with one Uvicorn worker and disables
the access log. One worker is intentional while request metadata and rate limits remain in
memory. Build and test it locally with:

```bash
docker build -t medistar-backend .
docker run --rm -p 8000:8000 --env-file .env medistar-backend
curl http://localhost:8000/health
```

For a hosted deployment, configure the variables from `.env.example` in the provider's secret
settings. At minimum, production requires `OPENAI_API_KEY`, `APPLE_CLIENT_ID=misaki.MediStar`,
and an HTTPS public URL. Never copy `.env` into the image or commit it to Git.
## Apple account deletion

`POST /v1/account/delete` requires a fresh Apple identity token, `X-Apple-Nonce`,
and a JSON `authorization_code` from reauthentication. The server exchanges the
code, verifies the returned identity matches the authenticated user, revokes the
Apple refresh token, and clears that user's in-memory request metadata and limits.
No authorization codes or refresh tokens are persisted.

Configure these secrets in Render before deploying the deletion feature:

- `APPLE_CLIENT_ID`: the app bundle ID (`misaki.MediStar`).
- `APPLE_TEAM_ID`: your Apple Developer Team ID.
- `APPLE_KEY_ID`: the ID of a Sign in with Apple key authorized for this app.
- `APPLE_PRIVATE_KEY`: the contents of that key's `.p8` file (multiline or escaped newlines).

Never commit the private key or include it in the iOS app. Without these settings,
the endpoint returns 503 and the app keeps local data for retry. A failed or timed-out
exchange/revocation requires fresh Sign in with Apple confirmation because codes
are single-use. Validate the complete flow on a test account after deployment.

## App privacy declaration audit — November 3, 2026

The app must not declare "Data Not Collected". The shipped privacy manifest now
declares the following data for App Functionality, linked to the user, with no
tracking. Mirror these choices manually in App Store Connect > App Privacy:

| App Store data type | Implementation evidence |
| --- | --- |
| Health | Selected medication, symptom and vital facts sent for optional AI summaries |
| Other User Content | User questions and relevant free-text entries sent for AI processing |
| User ID | Verified Apple subject keys server-memory request metadata and rate limits |
| Product Interaction | Request timestamps, usage counters and question categories |
| Performance Data | Request and AI pipeline processing durations |
| Other Diagnostic Data | Request IDs, response statuses, errors and payload sizes |

Linked-to-user is conservative: requests are authenticated and request IDs can
join logs to account metadata. Temporary record IDs do not make the entire
request anonymous. No advertising, tracking or behavioral analytics purpose is
implemented. Only device-local data is excluded from this table.

This declaration assumes default OpenAI retention, not an unverified Zero Data
Retention approval. Responses use store=False, but default abuse-monitoring
retention can still include prompts and responses for up to 30 days, with the
provider's stated legal/safety exceptions. Backend request metadata has no TTL;
it stays in process memory until restart or explicit account deletion.

Before release, verify actual OpenAI project data controls and Render log retention
against this policy, deploy the updated public pages and account deletion endpoint,
and upload a new iOS build. The local manifest does not update App Store Connect.
Provider log retention settings have not been verified by this source-code audit.
Do not promise that account deletion erases provider logs.

References:
- https://developer.apple.com/app-store/app-privacy-details/
- https://developer.apple.com/documentation/technotes/tn3184-adding-data-collection-details-to-your-privacy-manifest
- https://developers.openai.com/api/docs/guides/your-data
