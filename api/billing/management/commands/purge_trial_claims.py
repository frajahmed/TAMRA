from django.core.management.base import BaseCommand

from billing.trial import purge_old_claims


class Command(BaseCommand):
    help = "Delete free-trial claims older than TRIAL_CLAIM_RETENTION_DAYS (run daily)."

    def handle(self, *args, **options) -> None:
        deleted = purge_old_claims()
        self.stdout.write(self.style.SUCCESS(f"Deleted {deleted} old trial claims."))
