"""Base models for all TAMRA data.

Every table with user data inherits from OwnedModel:
- UUID primary key (the app can create IDs offline)
- created_at / updated_at for sync
- deleted_at for soft delete (deleted rows are synced as deletions)
"""

import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone


class ActiveManager(models.Manager):
    """Default manager: hides soft-deleted rows."""

    def get_queryset(self) -> models.QuerySet:
        """Only rows that are not soft-deleted."""
        return super().get_queryset().filter(deleted_at__isnull=True)


class TimeStampedModel(models.Model):
    """Base for every table: UUID id, created/updated timestamps and soft delete."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True, db_index=True)
    deleted_at = models.DateTimeField(null=True, blank=True, db_index=True)

    objects = ActiveManager()
    all_objects = models.Manager()  # noqa: DJ012  (ruff reads this manager as a field)

    class Meta:
        abstract = True

    def soft_delete(self) -> None:
        """Hide the row instead of deleting it (sync and undo need the row)."""
        self.deleted_at = timezone.now()
        self.save(update_fields=["deleted_at", "updated_at"])


class OwnedModel(TimeStampedModel):
    """A row that belongs to exactly one user."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+")

    class Meta:
        abstract = True

    @property
    def owner(self):  # used by core.permissions.IsOwner
        """The user this row belongs to (used by core.permissions.IsOwner)."""
        return self.user
