"""Free-trial abuse protection.

Problem: someone deletes the account (or makes a new one with "name+1@gmail.com")
to get the free trial again and again.

Solution:
- Normalise the email ("Max.Muster+trial@googlemail.com" → "maxmuster@gmail.com").
- Store only a keyed one-way hash (HMAC-SHA256 with TRIAL_HASH_KEY) of the normalised
  email and of the device id, never the clear text. The hash cannot be turned back into
  the email, and without the secret key it cannot be checked by trying emails either.
- The claim is NOT linked to the user, so it survives account deletion (GDPR: only a
  pseudonymous hash, legitimate interest Art. 6(1)(f), deleted after the retention period).
- Disposable email domains get no trial.

App Store and Google Play also allow one introductory offer per Apple ID / Google
account themselves; this check is an extra layer for every platform (incl. web).
"""

import hashlib
import hmac
from dataclasses import dataclass
from datetime import timedelta

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone

from .models import TrialClaim

# Providers that ignore dots and/or "+tags" in the local part.
DOT_INSENSITIVE_DOMAINS = {"gmail.com"}
DOMAIN_ALIASES = {"googlemail.com": "gmail.com"}

# Small built-in list; extend with settings.DISPOSABLE_EMAIL_DOMAINS.
DISPOSABLE_DOMAINS = {
    "10minutemail.com",
    "guerrillamail.com",
    "mailinator.com",
    "temp-mail.org",
    "tempmail.com",
    "throwawaymail.com",
    "trashmail.com",
    "yopmail.com",
    "sharklasers.com",
    "getnada.com",
    "dispostable.com",
    "maildrop.cc",
}


@dataclass(frozen=True)
class TrialCheck:
    """Result of a trial check: may the user start a trial, and if not, why."""

    eligible: bool
    reason: str = ""  # "", "disposable_email", "already_used"


def normalize_email(email: str) -> str:
    """Canonical form: lower case, no "+tag", Gmail without dots, googlemail → gmail."""
    local, _, domain = email.strip().lower().rpartition("@")
    if not local or not domain:
        return email.strip().lower()
    domain = DOMAIN_ALIASES.get(domain, domain)
    local = local.split("+", 1)[0]
    if domain in DOT_INSENSITIVE_DOMAINS:
        local = local.replace(".", "")
    return f"{local}@{domain}"


def identity_hash(kind: str, value: str) -> str:
    """Keyed one-way hash (HMAC-SHA256). The kind is part of the message, so an email
    hash can never collide with a device hash."""
    key = settings.TRIAL_HASH_KEY.encode()
    message = f"{kind}:{value}".encode()
    return hmac.new(key, message, hashlib.sha256).hexdigest()


def is_disposable(email: str) -> bool:
    """True for throw-away email domains, which never get a trial."""
    domain = normalize_email(email).rpartition("@")[2]
    extra = set(getattr(settings, "DISPOSABLE_EMAIL_DOMAINS", ()))
    return domain in DISPOSABLE_DOMAINS | extra


def _hashes(email: str, device_id: str | None) -> dict[str, str]:
    hashes = {TrialClaim.Kind.EMAIL: identity_hash("email", normalize_email(email))}
    if device_id:
        hashes[TrialClaim.Kind.DEVICE] = identity_hash("device", device_id.strip())
    return hashes


def check_trial(email: str, device_id: str | None = None) -> TrialCheck:
    """Check whether this email (and device) may still start a free trial; changes nothing."""
    if is_disposable(email):
        return TrialCheck(False, "disposable_email")
    hashes = _hashes(email, device_id).values()
    if TrialClaim.objects.filter(identity_hash__in=hashes).exists():
        return TrialCheck(False, "already_used")
    return TrialCheck(True)


def claim_trial(email: str, device_id: str | None = None) -> TrialCheck:
    """Mark the trial as used for this email (and device). Safe against double clicks."""
    result = check_trial(email, device_id)
    if not result.eligible:
        return result
    try:
        with transaction.atomic():
            for kind, value in _hashes(email, device_id).items():
                TrialClaim.objects.create(kind=kind, identity_hash=value)
    except IntegrityError:
        return TrialCheck(False, "already_used")
    return TrialCheck(True)


def purge_old_claims() -> int:
    """Delete claims older than the retention period. Returns the number deleted."""
    limit = timezone.now() - timedelta(days=settings.TRIAL_CLAIM_RETENTION_DAYS)
    deleted, _ = TrialClaim.objects.filter(created_at__lt=limit).delete()
    return deleted
