import asyncio
import hashlib
import json
import logging
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient

from app.auth import (
    AppleTokenVerifier,
    AuthenticatedUser,
    InvalidAppleToken,
)
from app.config import settings
from app.main import app, request_logger
from app.services.privacy_service import PerUserRateLimiter
from tests.test_assistant_schemas import valid_payload


class SubjectFromTokenVerifier:
    async def verify(self, identity_token: str, raw_nonce: str) -> AuthenticatedUser:
        return AuthenticatedUser(subject=identity_token)


class RejectingVerifier:
    async def verify(self, identity_token: str, raw_nonce: str) -> AuthenticatedUser:
        raise InvalidAppleToken("test rejection")


class StaticSigningKeyClient:
    def __init__(self, public_key) -> None:
        self.public_key = public_key

    def get_signing_key_from_jwt(self, token: str):
        return SimpleNamespace(key=self.public_key)


class MutableClock:
    def __init__(self, now: datetime) -> None:
        self.now = now

    def __call__(self) -> datetime:
        return self.now


def headers_for(subject: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {subject}",
        "X-Apple-Nonce": "raw-test-nonce",
    }


def signed_apple_token(
    private_key,
    *,
    raw_nonce: str,
    audience: str = "misaki.PillMate",
    expires_at: datetime | None = None,
) -> str:
    return jwt.encode(
        {
            "iss": "https://appleid.apple.com",
            "aud": audience,
            "exp": expires_at or datetime.now(UTC) + timedelta(minutes=5),
            "sub": "apple-user-subject",
            "nonce": hashlib.sha256(raw_nonce.encode("utf-8")).hexdigest(),
        },
        private_key,
        algorithm="RS256",
        headers={"kid": "test-key"},
    )


def test_apple_identity_token_signature_claims_and_nonce_are_verified() -> None:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    raw_nonce = "one-time-sign-in-nonce"
    verifier = AppleTokenVerifier(
        client_id="misaki.PillMate",
        signing_key_client=StaticSigningKeyClient(private_key.public_key()),
    )

    user = asyncio.run(
        verifier.verify(
            signed_apple_token(private_key, raw_nonce=raw_nonce),
            raw_nonce,
        )
    )

    assert user == AuthenticatedUser(subject="apple-user-subject")


@pytest.mark.parametrize(
    ("audience", "provided_nonce", "expires_at"),
    [
        ("another.client", "one-time-sign-in-nonce", None),
        ("misaki.PillMate", "wrong-nonce", None),
        (
            "misaki.PillMate",
            "one-time-sign-in-nonce",
            datetime.now(UTC) - timedelta(minutes=1),
        ),
    ],
)
def test_apple_identity_token_rejects_invalid_security_claims(
    audience: str,
    provided_nonce: str,
    expires_at: datetime | None,
) -> None:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    signed_nonce = "one-time-sign-in-nonce"
    verifier = AppleTokenVerifier(
        client_id="misaki.PillMate",
        signing_key_client=StaticSigningKeyClient(private_key.public_key()),
    )
    token = signed_apple_token(
        private_key,
        raw_nonce=signed_nonce,
        audience=audience,
        expires_at=expires_at,
    )

    with pytest.raises(InvalidAppleToken):
        asyncio.run(verifier.verify(token, provided_nonce))


def test_apple_identity_token_rejects_untrusted_signature() -> None:
    trusted_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    untrusted_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    raw_nonce = "one-time-sign-in-nonce"
    verifier = AppleTokenVerifier(
        client_id="misaki.PillMate",
        signing_key_client=StaticSigningKeyClient(trusted_key.public_key()),
    )
    token = signed_apple_token(untrusted_key, raw_nonce=raw_nonce)

    with pytest.raises(InvalidAppleToken):
        asyncio.run(verifier.verify(token, raw_nonce))


def test_analyze_rejects_unauthenticated_requests() -> None:
    response = TestClient(app).post("/v1/assistant/analyze", json=valid_payload())

    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"
    assert response.json() == {"detail": "A valid Sign in with Apple credential is required"}


def test_analyze_rejects_token_without_nonce_header() -> None:
    response = TestClient(app).post(
        "/v1/assistant/analyze",
        json=valid_payload(),
        headers={"Authorization": "Bearer token-without-nonce"},
    )

    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


def test_analyze_rejects_invalid_apple_token(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(app.state, "apple_token_verifier", RejectingVerifier())

    response = TestClient(app).post(
        "/v1/assistant/analyze",
        json=valid_payload(),
        headers=headers_for("invalid-token"),
    )

    assert response.status_code == 401
    assert response.json() == {"detail": "A valid Sign in with Apple credential is required"}


def test_request_context_is_user_scoped_and_deletable(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(app.state, "apple_token_verifier", SubjectFromTokenVerifier())
    monkeypatch.setattr(settings, "openai_api_key", None)
    payload = valid_payload()
    payload["requestId"] = "isolation-request"
    client = TestClient(app)

    analyze = client.post(
        "/v1/assistant/analyze",
        json=payload,
        headers=headers_for("user-a"),
    )
    own_context = client.get(
        "/v1/assistant/requests/isolation-request",
        headers=headers_for("user-a"),
    )
    other_context = client.get(
        "/v1/assistant/requests/isolation-request",
        headers=headers_for("user-b"),
    )
    other_delete = client.delete(
        "/v1/assistant/requests",
        headers=headers_for("user-b"),
    )
    own_delete = client.delete(
        "/v1/assistant/requests",
        headers=headers_for("user-a"),
    )
    deleted_context = client.get(
        "/v1/assistant/requests/isolation-request",
        headers=headers_for("user-a"),
    )

    assert analyze.status_code == 503
    assert own_context.status_code == 200
    assert own_context.json()["requestId"] == "isolation-request"
    assert own_context.json()["statusCode"] == 503
    assert set(own_context.json()) == {
        "requestId",
        "createdAt",
        "completedAt",
        "statusCode",
        "errorType",
    }
    assert other_context.status_code == 404
    assert other_delete.json() == {"deletedCount": 0}
    assert own_delete.json() == {"deletedCount": 1}
    assert deleted_context.status_code == 404


def test_rate_limits_are_per_user_and_include_a_daily_cap(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    clock = MutableClock(datetime(2026, 9, 14, 0, 0, tzinfo=UTC))
    limiter = PerUserRateLimiter(
        requests_per_minute=1,
        daily_request_limit=2,
        clock=clock,
    )
    monkeypatch.setattr(app.state, "apple_token_verifier", SubjectFromTokenVerifier())
    monkeypatch.setattr(app.state, "rate_limiter", limiter)
    monkeypatch.setattr(settings, "openai_api_key", None)
    client = TestClient(app)

    def analyze(subject: str, request_id: str):
        payload = valid_payload()
        payload["requestId"] = request_id
        return client.post(
            "/v1/assistant/analyze",
            json=payload,
            headers=headers_for(subject),
        )

    assert analyze("user-a", "rate-a-1").status_code == 503
    minute_limited = analyze("user-a", "rate-a-2")
    assert minute_limited.status_code == 429
    assert minute_limited.headers["retry-after"] == "61"
    assert analyze("user-b", "rate-b-1").status_code == 503

    clock.now += timedelta(seconds=61)
    assert analyze("user-a", "rate-a-3").status_code == 503
    clock.now += timedelta(seconds=61)
    daily_limited = analyze("user-a", "rate-a-4")
    assert daily_limited.status_code == 429
    assert int(daily_limited.headers["retry-after"]) > 60


def test_request_log_contains_only_redacted_operational_fields(
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    sensitive_question = "Private health prompt about dizziness"
    sensitive_note = "Private medication note after breakfast"
    payload = valid_payload()
    payload["requestId"] = "redacted-log-request"
    payload["userQuestion"] = sensitive_question
    payload["medicationEvents"][0]["notes"] = sensitive_note
    monkeypatch.setattr(app.state, "apple_token_verifier", SubjectFromTokenVerifier())
    monkeypatch.setattr(settings, "openai_api_key", None)
    request_logger.addHandler(caplog.handler)
    caplog.set_level(logging.INFO, logger="pillmate.request")

    try:
        response = TestClient(app).post(
            "/v1/assistant/analyze",
            json=payload,
            headers=headers_for("private-apple-subject"),
        )
    finally:
        request_logger.removeHandler(caplog.handler)

    assert response.status_code == 503
    records = [record for record in caplog.records if record.name == "pillmate.request"]
    assert len(records) == 1
    logged = json.loads(records[0].getMessage())
    assert set(logged) == {"request_id", "duration_ms", "status_code", "error_type"}
    assert logged["request_id"] == "redacted-log-request"
    assert logged["status_code"] == 503
    assert logged["error_type"] == "AIServiceNotConfigured"
    assert sensitive_question not in records[0].getMessage()
    assert sensitive_note not in records[0].getMessage()
    assert "private-apple-subject" not in records[0].getMessage()
