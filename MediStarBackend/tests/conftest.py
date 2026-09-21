import pytest

from app.auth import AuthenticatedUser
from app.main import app


class StaticAppleTokenVerifier:
    async def verify(self, identity_token: str, raw_nonce: str) -> AuthenticatedUser:
        return AuthenticatedUser(subject=identity_token)


@pytest.fixture(autouse=True)
def reset_request_privacy_state():
    app.state.request_context_store.clear()
    app.state.rate_limiter.reset()
    yield
    app.state.request_context_store.clear()
    app.state.rate_limiter.reset()


@pytest.fixture
def auth_headers(monkeypatch: pytest.MonkeyPatch) -> dict[str, str]:
    monkeypatch.setattr(app.state, "apple_token_verifier", StaticAppleTokenVerifier())
    return {
        "Authorization": "Bearer test-apple-user",
        "X-Apple-Nonce": "test-raw-nonce",
    }
