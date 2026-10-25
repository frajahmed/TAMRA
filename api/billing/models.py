from django.db import models


class TrialClaim(models.Model):
    """A used free trial, stored only as a keyed hash (see billing/trial.py).

    Deliberately without a link to the user: it must outlive account deletion,
    otherwise deleting and re-registering would give a new trial.
    """

    class Kind(models.TextChoices):
        EMAIL = "email"
        DEVICE = "device"

    kind = models.CharField(max_length=10, choices=Kind.choices)
    identity_hash = models.CharField(max_length=64, unique=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    def __str__(self) -> str:
        return f"{self.kind} {self.identity_hash[:12]}…"
