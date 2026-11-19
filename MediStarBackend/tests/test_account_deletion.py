import asyncio
from unittest.mock import AsyncMock
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from app.main import app, require_apple_user
from app.auth import AuthenticatedUser
from app.services import account_deletion as service
from app.config import settings


@pytest.fixture
def configured(monkeypatch):
    for key in ('apple_client_id', 'apple_team_id', 'apple_key_id', 'apple_private_key'):
        monkeypatch.setattr(settings, key, 'test-only')
    monkeypatch.setattr(service.jwt, 'encode', lambda *a, **k: 'secret')


def test_revoke_requires_same_user(configured, monkeypatch):
    calls = []
    def post(endpoint, fields):
        calls.append(endpoint)
        return {'id_token': 'identity', 'refresh_token': 'refresh'}
    monkeypatch.setattr(service, '_post', post)
    verifier = AsyncMock()
    verifier.verify.return_value = AuthenticatedUser('other-user')
    with pytest.raises(HTTPException) as error:
        asyncio.run(service.revoke_authorization('code', 'nonce', 'owner', verifier))
    assert error.value.status_code == 403
    assert calls == ['token']


def test_exchange_then_revoke(configured, monkeypatch):
    calls = []
    def post(endpoint, fields):
        calls.append((endpoint, fields))
        return {'id_token': 'identity', 'refresh_token': 'refresh'}
    monkeypatch.setattr(service, '_post', post)
    verifier = AsyncMock()
    verifier.verify.return_value = AuthenticatedUser('owner')
    asyncio.run(service.revoke_authorization('code', 'nonce', 'owner', verifier))
    assert [c[0] for c in calls] == ['token', 'revoke']
    assert calls[1][1]['token'] == 'refresh'
    verifier.verify.assert_awaited_once_with('identity', 'nonce')


def test_missing_configuration_fails_before_contacting_apple(monkeypatch):
    monkeypatch.setattr(settings, 'apple_private_key', None)
    with pytest.raises(HTTPException) as error:
        asyncio.run(service.revoke_authorization('code', 'nonce', 'owner', AsyncMock()))
    assert error.value.status_code == 503


def test_provider_errors_do_not_expose_credentials(configured, monkeypatch):
    def post(*args):
        raise ValueError('sensitive-provider-response')
    monkeypatch.setattr(service, '_post', post)
    with pytest.raises(HTTPException) as error:
        asyncio.run(service.revoke_authorization('code', 'nonce', 'owner', AsyncMock()))
    assert error.value.status_code == 502
    assert 'sensitive-provider-response' not in error.value.detail


def test_endpoint_authentication_and_cleanup(monkeypatch):
    with TestClient(app) as client:
        assert client.post('/v1/account/delete', json={'authorization_code': 'code'}).status_code == 401
        app.dependency_overrides[require_apple_user] = lambda: AuthenticatedUser('owner')
        try:
            store = app.state.request_context_store
            store.begin('owner', 'delete-test')
            store.begin('other', 'keep-test')
            fail = AsyncMock(side_effect=HTTPException(502, 'Unavailable'))
            monkeypatch.setattr('app.main.revoke_authorization', fail)
            args = dict(json={'authorization_code': 'code'}, headers={'X-Apple-Nonce': 'nonce'})
            assert client.post('/v1/account/delete', **args).status_code == 502
            assert store.get('owner', 'delete-test') is not None
            monkeypatch.setattr('app.main.revoke_authorization', AsyncMock())
            assert client.post('/v1/account/delete', **args).status_code == 200
            assert store.get('owner', 'delete-test') is None
            assert store.get('other', 'keep-test') is not None
        finally:
            app.dependency_overrides.pop(require_apple_user, None)
            app.state.request_context_store.clear()
