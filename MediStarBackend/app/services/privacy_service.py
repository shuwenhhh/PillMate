from collections import defaultdict, deque
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from threading import RLock
from typing import Callable


@dataclass(frozen=True)
class RequestContext:
    request_id: str
    created_at: datetime
    completed_at: datetime | None = None
    status_code: int | None = None
    error_type: str | None = None


class RequestContextStore:
    """In-memory, per-user metadata store; health payloads are never retained."""

    def __init__(self, clock: Callable[[], datetime] | None = None) -> None:
        self._clock = clock or (lambda: datetime.now(UTC))
        self._contexts: dict[str, dict[str, RequestContext]] = defaultdict(dict)
        self._lock = RLock()

    def begin(self, user_id: str, request_id: str) -> bool:
        with self._lock:
            user_contexts = self._contexts[user_id]
            if request_id in user_contexts:
                return False
            user_contexts[request_id] = RequestContext(
                request_id=request_id,
                created_at=self._clock(),
            )
            return True

    def complete(
        self,
        user_id: str,
        request_id: str,
        *,
        status_code: int,
        error_type: str | None,
    ) -> None:
        with self._lock:
            existing = self._contexts.get(user_id, {}).get(request_id)
            if existing is None:
                return
            self._contexts[user_id][request_id] = RequestContext(
                request_id=existing.request_id,
                created_at=existing.created_at,
                completed_at=self._clock(),
                status_code=status_code,
                error_type=error_type,
            )

    def get(self, user_id: str, request_id: str) -> RequestContext | None:
        with self._lock:
            return self._contexts.get(user_id, {}).get(request_id)

    def delete_all(self, user_id: str) -> int:
        with self._lock:
            return len(self._contexts.pop(user_id, {}))

    def clear(self) -> None:
        with self._lock:
            self._contexts.clear()


class RateLimitExceeded(Exception):
    def __init__(self, *, period: str, retry_after_seconds: int) -> None:
        super().__init__(f"{period} rate limit exceeded")
        self.period = period
        self.retry_after_seconds = max(1, retry_after_seconds)


class PerUserRateLimiter:
    """Single-process per-user minute and UTC-day request limits."""

    def __init__(
        self,
        *,
        requests_per_minute: int,
        daily_request_limit: int,
        clock: Callable[[], datetime] | None = None,
    ) -> None:
        self.requests_per_minute = requests_per_minute
        self.daily_request_limit = daily_request_limit
        self._clock = clock or (lambda: datetime.now(UTC))
        self._minute_events: dict[str, deque[datetime]] = defaultdict(deque)
        self._daily_counts: dict[str, tuple[date, int]] = {}
        self._lock = RLock()

    def consume(self, user_id: str) -> None:
        now = self._clock()
        if now.tzinfo is None:
            now = now.replace(tzinfo=UTC)
        else:
            now = now.astimezone(UTC)
        minute_start = now - timedelta(minutes=1)
        today = now.date()

        with self._lock:
            events = self._minute_events[user_id]
            while events and events[0] <= minute_start:
                events.popleft()

            if len(events) >= self.requests_per_minute:
                retry_after = (
                    int((events[0] + timedelta(minutes=1) - now).total_seconds()) + 1
                )
                raise RateLimitExceeded(period="minute", retry_after_seconds=retry_after)

            usage_day, daily_count = self._daily_counts.get(user_id, (today, 0))
            if usage_day != today:
                daily_count = 0
            if daily_count >= self.daily_request_limit:
                tomorrow = datetime.combine(
                    today + timedelta(days=1),
                    datetime.min.time(),
                    tzinfo=UTC,
                )
                retry_after = int((tomorrow - now).total_seconds()) + 1
                raise RateLimitExceeded(period="day", retry_after_seconds=retry_after)

            events.append(now)
            self._daily_counts[user_id] = (today, daily_count + 1)

    def reset(self) -> None:
        with self._lock:
            self._minute_events.clear()
            self._daily_counts.clear()
