from django.core.management.base import BaseCommand

from billing.trial import purge_old_claims


class Command(BaseCommand):
    """Delete trial claims older than TRIAL_CLAIM_RETENTION_DAYS (run daily)."""

    help = "Delete free-trial claims older than TRIAL_CLAIM_RETENTION_DAYS (run daily)."

    def handle(self, *args, **options) -> None:
        """Run the purge and print how many claims were deleted."""
        deleted = purge_old_claims()
        self.stdout.write(self.style.SUCCESS(f"Deleted {deleted} old trial claims."))
