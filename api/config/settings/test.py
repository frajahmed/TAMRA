from .base import *  # noqa: F403

DEBUG = False
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]
REST_FRAMEWORK = {
    **REST_FRAMEWORK,  # noqa: F405
    "DEFAULT_THROTTLE_CLASSES": [],
    # Views with their own throttle (login, register) must not slow the test run down.
    "DEFAULT_THROTTLE_RATES": {
        **REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"],  # noqa: F405
        "login": "1000/min",
        "register": "1000/min",
    },
}
CELERY_TASK_ALWAYS_EAGER = True
