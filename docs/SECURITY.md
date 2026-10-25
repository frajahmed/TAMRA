# TAMRA – Security

Short overview of how TAMRA protects accounts and health data. Keep it up to date when
security-relevant code changes.

## Passwords
| Measure | Implementation |
| --- | --- |
| One-way hash, never reversible | Django password hashers; the clear password is never stored or logged |
| Random salt per user | Generated for every hash and stored inside the hash string |
| Algorithm | **Argon2id** (OWASP first choice, memory-hard against GPU cracking) via `Django[argon2]` |
| Older hashes | PBKDF2-SHA256 stays as fallback and is upgraded to Argon2id automatically at the next login |
| Why not bcrypt | bcrypt only uses the first 72 bytes of a password and is not memory-hard; Argon2id is the stronger, current recommendation |
| Minimum length | 10 characters, plus Django checks against common passwords, numeric-only and similarity to the email |
| Guessing protection | Login limited to 10 attempts per minute per IP, registration 10 per hour |
| Tokens | JWT access 15 min, refresh 30 days, rotation and blacklist on logout and account deletion |

Settings: `PASSWORD_HASHERS`, `AUTH_PASSWORD_VALIDATORS`, `DEFAULT_THROTTLE_RATES` in `api/config/settings/base.py`.
Tests: `api/accounts/tests/test_security.py`.

## Hash functions – where and which
| Purpose | Function | Why |
| --- | --- | --- |
| Passwords | Argon2id (slow, salted) | Must resist offline cracking |
| Free-trial check | HMAC-SHA256 with secret `TRIAL_HASH_KEY` | Fast and one-way; the secret key stops anyone from testing emails against the stored hashes |
| JWT signature | HMAC-SHA256 with `DJANGO_SECRET_KEY` | Tokens cannot be forged |

Never use plain SHA-256/MD5 for passwords: they are too fast to brute-force.

## Free-trial abuse protection
- App Store and Google Play already allow one introductory offer per Apple ID / Google account.
- TAMRA adds its own check (all platforms, including a future web shop), `api/billing/trial.py`:
  - email normalised (lower case, no `+tag`, Gmail without dots, googlemail → gmail),
  - stored only as HMAC-SHA256 hash, plus a hash of the device id,
  - not linked to the user, so deleting the account and registering again gives no new trial,
  - disposable email domains get no trial,
  - claims are deleted after 24 months (`python manage.py purge_trial_claims`, run daily).
- API: `GET /api/v1/me/trial/?device_id=` (eligible?), `POST /api/v1/me/trial/` (start trial).
- GDPR: pseudonymous data, legal basis legitimate interest (Art. 6(1)(f)); mention in the privacy policy.

## Database and data
- PostgreSQL in the EU, TLS in transit, encryption at rest and encrypted backups (managed database).
- Own database user for the app without superuser rights in production.
- Health data never in logs, Sentry or analytics (`core/sentry.py` filter).
- Every query for user data is filtered by the logged-in user; other users' data → 404.
- Data export and real deletion (GDPR Art. 15, 17, 20): `/api/v1/me/export/`, `DELETE /api/v1/me/`.

## Secrets (production)
`DJANGO_SECRET_KEY`, `TRIAL_HASH_KEY`, `POSTGRES_PASSWORD`, `SENTRY_DSN` only as environment
variables / secret manager, never in Git. `TRIAL_HASH_KEY` must never change.

## Open items
- Two-factor login (TOTP) – phase 2.
- Check new passwords against known leaks (Have I Been Pwned, k-anonymity) – phase 2.
- Apple App Attest / Google Play Integrity for stronger device ids – with the subscription.
- External penetration test before the public launch.
