"""Uniform error format for the whole API.

Every error response looks like:
    {"code": "validation_error", "message": "Invalid input.", "fields": {"email": ["..."]}}
"""

from django.utils.translation import gettext as _
from rest_framework.exceptions import ValidationError
from rest_framework.views import exception_handler


def api_exception_handler(exc, context):
    response = exception_handler(exc, context)
    if response is None:
        return None

    data = response.data
    if isinstance(exc, ValidationError):
        fields = data if isinstance(data, dict) else {"non_field_errors": data}
        response.data = {
            "code": "validation_error",
            "message": _("Invalid input."),
            "fields": fields,
        }
        return response

    detail = data.get("detail") if isinstance(data, dict) else data
    code = getattr(detail, "code", None) or getattr(exc, "default_code", "error")
    response.data = {"code": str(code), "message": str(detail), "fields": {}}
    return response
