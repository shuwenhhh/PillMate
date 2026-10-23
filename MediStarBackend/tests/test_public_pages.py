from fastapi.testclient import TestClient

from app.main import app
from app.config import settings


def test_public_pages_do_not_require_login():
    with TestClient(app) as client:
        for path, title in [("/privacy", "Privacy Policy"), ("/support", "Support")]:
            response = client.get(path)
            assert response.status_code == 200
            assert "text/html" in response.headers["content-type"]
            assert f"<h1>{title}</h1>" in response.text
            assert "mailto:jessicayudok@gmail.com" in response.text
            assert 'href="/privacy"' in response.text
            assert 'href="/support"' in response.text
            assert "<script" not in response.text
            assert "set-cookie" not in response.headers


def test_contact_configuration_is_html_escaped(monkeypatch):
    monkeypatch.setattr(settings, "support_email", '<test>"@example.com')
    with TestClient(app) as client:
        response = client.get("/support")
        assert '&lt;test&gt;&quot;@example.com' in response.text
        assert '<test>' not in response.text
