from fastapi.testclient import TestClient

from app.config import settings
from app.main import app
from app.services.assistant_service import AssistantService


def test_health_endpoint() -> None:
    response = TestClient(app).get("/health")
    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "ai_model": settings.openai_model,
        "reasoning_effort": AssistantService._reasoning_effort(),
    }
