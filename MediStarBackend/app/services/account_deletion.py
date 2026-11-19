"""Exchange a fresh Apple code, bind its identity, then revoke the grant."""
import asyncio
import json
import ssl
import time
from urllib.parse import urlencode
from urllib.request import Request, urlopen

import certifi
import jwt
from fastapi import HTTPException
from ..config import settings


def _post(endpoint: str, fields: dict) -> dict:
    request = Request(
        'https://appleid.apple.com/auth/' + endpoint,
        data=urlencode(fields).encode(),
        headers={'Content-Type': 'application/x-www-form-urlencoded'},
        method='POST',
    )
    with urlopen(request, timeout=15, context=ssl.create_default_context(cafile=certifi.where())) as response:
        body = response.read()
        return json.loads(body) if body else {}


async def revoke_authorization(code: str, nonce: str, subject: str, verifier) -> None:
    if not all((settings.apple_client_id, settings.apple_team_id,
                settings.apple_key_id, settings.apple_private_key)):
        raise HTTPException(503, 'Account deletion is not configured. Please try again later.')
    try:
        now = int(time.time())
        secret = jwt.encode(
            {'iss': settings.apple_team_id, 'iat': now, 'exp': now + 300,
             'aud': 'https://appleid.apple.com', 'sub': settings.apple_client_id},
            settings.apple_private_key.replace('\\n', '\n'), algorithm='ES256',
            headers={'kid': settings.apple_key_id},
        )
        fields = {'client_id': settings.apple_client_id, 'client_secret': secret}
        tokens = await asyncio.to_thread(_post, 'token', {
            **fields, 'code': code, 'grant_type': 'authorization_code',
        })
        # Never revoke a code belonging to a different user from the authenticated request.
        owner = await verifier.verify(tokens['id_token'], nonce)
        if owner.subject != subject:
            raise HTTPException(403, 'Sign in with the same Apple account to delete your data.')
        token = tokens.get('refresh_token') or tokens.get('access_token')
        if not token:
            raise ValueError('Missing revocable token')
        await asyncio.to_thread(_post, 'revoke', {
            **fields, 'token': token,
            'token_type_hint': 'refresh_token' if tokens.get('refresh_token') else 'access_token',
        })
    except HTTPException:
        raise
    except Exception:
        # Never expose Apple responses, codes, tokens or signing keys in errors/logs.
        raise HTTPException(502, 'Apple authorization could not be revoked. Sign in again and retry.') from None
