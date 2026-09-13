from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .schemas import AssistantRequest, AssistantResponse
from .services.assistant_service import AssistantService


app = FastAPI(
    title="PillMate Backend",
    version="0.1.0",
    description="Safe, records-only assistant endpoint for PillMate.",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.origins,
    allow_credentials=False,
    allow_methods=["POST", "GET"],
    allow_headers=["Authorization", "Content-Type"],
)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/v1/assistant/analyze", response_model=AssistantResponse)
async def analyze_records(request: AssistantRequest) -> AssistantResponse:
    if request.question_type.value == "free_text" and not request.user_question.strip():
        raise HTTPException(status_code=422, detail="user_question is required for free_text requests")

    if not settings.openai_api_key:
        raise HTTPException(status_code=503, detail="AI service is not configured")

    try:
        return await AssistantService().generate(request)
    except HTTPException:
        raise
    except Exception as error:
        # Do not return provider details or health data in the error response.
        raise HTTPException(status_code=502, detail="AI service temporarily unavailable") from error
