import json
import logging
import re
import time
from typing import NoReturn
from uuid import uuid4

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .auth import (
    AppleAuthenticationUnavailable,
    AppleTokenVerifier,
    AuthenticatedUser,
    InvalidAppleToken,
)
from .config import settings
from .schemas import (
    AssistantRequest,
    AssistantResponse,
    DeleteRequestDataResponse,
    RequestContextResponse,
)
from .services.assistant_service import AssistantService
from .services.privacy_service import (
    PerUserRateLimiter,
    RateLimitExceeded,
    RequestContextStore,
)


REQUEST_ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$")
request_logger = logging.getLogger("medistar.request")
request_logger.setLevel(logging.INFO)
request_logger.propagate = False
if not request_logger.handlers:
    request_log_handler = logging.StreamHandler()
    request_log_handler.setFormatter(logging.Formatter("%(message)s"))
    request_logger.addHandler(request_log_handler)
# The structured middleware below is the only HTTP access log for this service.
logging.getLogger("uvicorn.access").disabled = True
bearer_scheme = HTTPBearer(auto_error=False)


app = FastAPI(
    title="MediStar Backend",
    version="0.1.0",
    description="Safe, records-only assistant endpoint for MediStar.",
)
app.state.apple_token_verifier = AppleTokenVerifier()
app.state.request_context_store = RequestContextStore()
app.state.rate_limiter = PerUserRateLimiter(
    requests_per_minute=settings.per_user_requests_per_minute,
    daily_request_limit=settings.per_user_daily_request_limit,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.origins,
    allow_credentials=False,
    allow_methods=["DELETE", "GET", "POST"],
    allow_headers=["Authorization", "Content-Type", "X-Apple-Nonce", "X-Request-ID"],
)


@app.exception_handler(RequestValidationError)
async def redacted_validation_error(
    request: Request,
    error: RequestValidationError,
) -> JSONResponse:
    """Return useful schema errors without echoing health data from the request."""

    request.state.error_type = "ValidationError"
    safe_errors = [
        {
            "type": item.get("type", "validation_error"),
            "loc": list(item.get("loc", ())),
            "msg": item.get("msg", "Invalid request value"),
        }
        for item in error.errors()
    ]
    return JSONResponse(status_code=422, content={"detail": safe_errors})


def _safe_request_id(value: str | None) -> str:
    if value and REQUEST_ID_PATTERN.fullmatch(value):
        return value
    return str(uuid4())


def _default_error_type(status_code: int) -> str | None:
    return {
        401: "AuthenticationError",
        404: "NotFound",
        409: "Conflict",
        422: "ValidationError",
        429: "RateLimitExceeded",
        502: "UpstreamServiceError",
        503: "ServiceUnavailable",
    }.get(status_code, "HTTPError" if status_code >= 400 else None)


@app.middleware("http")
async def redacted_request_log(request: Request, call_next):
    request.state.request_id = _safe_request_id(request.headers.get("x-request-id"))
    started_at = time.perf_counter()
    try:
        response = await call_next(request)
    except Exception as error:
        request_logger.info(
            json.dumps(
                {
                    "request_id": request.state.request_id,
                    "duration_ms": round((time.perf_counter() - started_at) * 1000, 2),
                    "status_code": 500,
                    "error_type": type(error).__name__,
                },
                separators=(",", ":"),
                sort_keys=True,
            )
        )
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error"},
        )

    status_code = response.status_code
    request_logger.info(
        json.dumps(
            {
                "request_id": request.state.request_id,
                "duration_ms": round((time.perf_counter() - started_at) * 1000, 2),
                "status_code": status_code,
                "error_type": getattr(request.state, "error_type", None)
                or _default_error_type(status_code),
            },
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return response


def _http_error(
    request: Request,
    *,
    status_code: int,
    detail: str,
    error_type: str,
    headers: dict[str, str] | None = None,
) -> NoReturn:
    request.state.error_type = error_type
    raise HTTPException(
        status_code=status_code,
        detail=detail,
        headers=headers,
    )


async def require_apple_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    apple_nonce: str | None = Header(default=None, alias="X-Apple-Nonce"),
) -> AuthenticatedUser:
    if credentials is None or credentials.scheme.lower() != "bearer" or apple_nonce is None:
        _http_error(
            request,
            status_code=401,
            detail="A valid Sign in with Apple credential is required",
            error_type="AuthenticationRequired",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        return await request.app.state.apple_token_verifier.verify(
            credentials.credentials,
            apple_nonce,
        )
    except AppleAuthenticationUnavailable:
        _http_error(
            request,
            status_code=503,
            detail="Authentication service is temporarily unavailable",
            error_type="AuthenticationUnavailable",
        )
    except InvalidAppleToken:
        _http_error(
            request,
            status_code=401,
            detail="A valid Sign in with Apple credential is required",
            error_type="InvalidAppleToken",
            headers={"WWW-Authenticate": "Bearer"},
        )


@app.get("/health")
async def health() -> dict[str, str]:
    return {
        "status": "ok",
        "ai_model": settings.openai_model,
        "reasoning_effort": AssistantService._reasoning_effort(),
    }


@app.post("/v1/assistant/analyze", response_model=AssistantResponse)
async def analyze_records(
    payload: AssistantRequest,
    request: Request,
    user: AuthenticatedUser = Depends(require_apple_user),
) -> AssistantResponse:
    request.state.request_id = payload.request_id

    try:
        request.app.state.rate_limiter.consume(user.subject)
    except RateLimitExceeded as error:
        _http_error(
            request,
            status_code=429,
            detail="Per-user AI request limit reached",
            error_type=f"{error.period.title()}RateLimitExceeded",
            headers={"Retry-After": str(error.retry_after_seconds)},
        )

    store: RequestContextStore = request.app.state.request_context_store
    if not store.begin(user.subject, payload.request_id):
        _http_error(
            request,
            status_code=409,
            detail="requestId has already been used",
            error_type="DuplicateRequestId",
        )

    if payload.question_type.value == "free_text" and not payload.user_question.strip():
        store.complete(
            user.subject,
            payload.request_id,
            status_code=422,
            error_type="MissingUserQuestion",
        )
        _http_error(
            request,
            status_code=422,
            detail="user_question is required for free_text requests",
            error_type="MissingUserQuestion",
        )

    if not settings.openai_api_key:
        store.complete(
            user.subject,
            payload.request_id,
            status_code=503,
            error_type="AIServiceNotConfigured",
        )
        _http_error(
            request,
            status_code=503,
            detail="AI service is not configured",
            error_type="AIServiceNotConfigured",
        )

    try:
        result = await AssistantService().generate(payload)
    except HTTPException as error:
        error_type = "AssistantRequestError"
        store.complete(
            user.subject,
            payload.request_id,
            status_code=error.status_code,
            error_type=error_type,
        )
        request.state.error_type = error_type
        raise
    except Exception as error:
        error_type = type(error).__name__
        store.complete(
            user.subject,
            payload.request_id,
            status_code=502,
            error_type=error_type,
        )
        # Do not return provider details or health data in the error response or logs.
        _http_error(
            request,
            status_code=502,
            detail="AI service temporarily unavailable",
            error_type=error_type,
        )

    store.complete(
        user.subject,
        payload.request_id,
        status_code=200,
        error_type=None,
    )
    return result


@app.get(
    "/v1/assistant/requests/{request_id}",
    response_model=RequestContextResponse,
)
async def get_request_context(
    request_id: str,
    request: Request,
    user: AuthenticatedUser = Depends(require_apple_user),
) -> RequestContextResponse:
    request.state.request_id = _safe_request_id(request_id)
    context = request.app.state.request_context_store.get(user.subject, request_id)
    if context is None:
        _http_error(
            request,
            status_code=404,
            detail="AI request context was not found",
            error_type="RequestContextNotFound",
        )
    return RequestContextResponse.model_validate(context, from_attributes=True)


@app.delete("/v1/assistant/requests", response_model=DeleteRequestDataResponse)
async def delete_request_data(
    request: Request,
    user: AuthenticatedUser = Depends(require_apple_user),
) -> DeleteRequestDataResponse:
    deleted_count = request.app.state.request_context_store.delete_all(user.subject)
    return DeleteRequestDataResponse(deleted_count=deleted_count)
