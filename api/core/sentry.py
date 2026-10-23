"""Sentry filter: health data and credentials never leave the server."""

from typing import Any

SENSITIVE_PARTS = (
    "weight",
    "food",
    "kcal",
    "calorie",
    "carb",
    "protein",
    "fat",
    "glucose",
    "insulin",
    "meal",
    "diary",
    "height",
    "birth",
    "token",
    "password",
    "secret",
    "authorization",
    "cookie",
    "email",
)
FILTERED = "[Filtered]"


def _is_sensitive(key: str) -> bool:
    lowered = key.lower()
    return any(part in lowered for part in SENSITIVE_PARTS)


def scrub(value: Any) -> Any:
    if isinstance(value, dict):
        return {
            key: FILTERED if isinstance(key, str) and _is_sensitive(key) else scrub(item)
            for key, item in value.items()
        }
    if isinstance(value, list):
        return [scrub(item) for item in value]
    return value


def before_send(event: dict, hint: dict) -> dict:
    event = scrub(event)
    request = event.get("request")
    if isinstance(request, dict):
        request.pop("data", None)
        request.pop("cookies", None)
    event.pop("user", None)
    return event
