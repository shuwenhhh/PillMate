import asyncio
import hashlib
import hmac
from dataclasses import dataclass
from typing import Protocol

import jwt

from .config import settings


APPLE_ID_TOKEN_ALGORITHM = "RS256"
MAX_ID_TOKEN_LENGTH = 8192
MAX_NONCE_LENGTH = 256


class InvalidAppleToken(Exception):
    """The presented credential cannot authenticate a PillMate user."""


class AppleAuthenticationUnavailable(Exception):
    """Apple token verification is not configured or temporarily unavailable."""


@dataclass(frozen=True)
class AuthenticatedUser:
    subject: str


class SigningKeyClient(Protocol):
    def get_signing_key_from_jwt(self, token: str): ...


class AppleTokenVerifier:
    """Verify an Apple identity token without retaining identity claims."""

    def __init__(
        self,
        *,
        client_id: str | None = None,
        issuer: str | None = None,
        jwks_url: str | None = None,
        jwks_cache_seconds: int | None = None,
        signing_key_client: SigningKeyClient | None = None,
    ) -> None:
        self.client_id = client_id if client_id is not None else settings.apple_client_id
        self.issuer = issuer or settings.apple_issuer
        self.jwks_url = jwks_url or settings.apple_jwks_url
        cache_seconds = jwks_cache_seconds or settings.apple_jwks_cache_seconds
        self.signing_key_client = signing_key_client or jwt.PyJWKClient(
            self.jwks_url,
            cache_keys=True,
            cache_jwk_set=True,
            lifespan=cache_seconds,
            timeout=5,
        )

    async def verify(self, identity_token: str, raw_nonce: str) -> AuthenticatedUser:
        if not self.client_id:
            raise AppleAuthenticationUnavailable("APPLE_CLIENT_ID is not configured")
        if not identity_token or len(identity_token) > MAX_ID_TOKEN_LENGTH:
            raise InvalidAppleToken("identity token has an invalid length")
        if not raw_nonce or len(raw_nonce) > MAX_NONCE_LENGTH:
            raise InvalidAppleToken("nonce has an invalid length")

        try:
            signing_key = await asyncio.to_thread(
                self.signing_key_client.get_signing_key_from_jwt,
                identity_token,
            )
            claims = jwt.decode(
                identity_token,
                signing_key.key,
                algorithms=[APPLE_ID_TOKEN_ALGORITHM],
                audience=self.client_id,
                issuer=self.issuer,
                options={"require": ["iss", "aud", "exp", "sub", "nonce"]},
            )
        except jwt.PyJWKClientConnectionError as error:
            raise AppleAuthenticationUnavailable("Apple signing keys are unavailable") from error
        except (jwt.InvalidTokenError, jwt.PyJWKClientError, ValueError, TypeError) as error:
            raise InvalidAppleToken("identity token verification failed") from error

        subject = claims.get("sub")
        token_nonce = claims.get("nonce")
        expected_nonce = hashlib.sha256(raw_nonce.encode("utf-8")).hexdigest()
        if not isinstance(subject, str) or not subject or len(subject) > 255:
            raise InvalidAppleToken("identity token subject is invalid")
        if not isinstance(token_nonce, str) or not hmac.compare_digest(token_nonce, expected_nonce):
            raise InvalidAppleToken("identity token nonce is invalid")

        return AuthenticatedUser(subject=subject)
