# TAMRA – Architecture (short version)

Full version: Claude doc "TAMRA – Architektur & Projektsteuerung (Mobile)".

## Decisions
| No. | Decision |
| --- | --- |
| E1 | Mobile first (iOS + Android), web later |
| E2 | Flutter, one codebase |
| E3 | Django REST Framework API |
| E4 | Offline first (drift + sync queue, ticket T-33 by Claude) |
| E5 | Subscriptions via RevenueCat (phase 2) |
| E6 | Hosting in the EU (Frankfurt) |
| E7 | OpenAPI contract `docs/openapi.yaml` from drf-spectacular; the Dart client is written by hand in `app/lib/core/api/api_client.dart` (no code generation, easier for the coding agent) |
| E8 | Monorepo `TAMRA` with `app/`, `api/`, `docs/` |
| E9 | Qwen implements tickets, Claude reviews at sprint end; CI checks every pull request |
| E10 | No code generation in the app (no build_runner): plain Riverpod, hand-written models, translations as Dart maps |
| E11 | Custom user model: email login, UUID primary key |
| E12 | User data: UUID ids, `updated_at`, soft delete (`deleted_at`) via `core.models.OwnedModel` |

## Stack
- App: Flutter stable, flutter_riverpod 2.x, go_router, dio, flutter_secure_storage; later drift, mobile_scanner, fl_chart
- API: Django 5.2, DRF, simplejwt (access 15 min, refresh 30 days, rotation + blacklist), drf-spectacular,
  PostgreSQL 16, Redis, Celery, sentry-sdk (filtered)
- CI: GitHub Actions – `api.yml`, `app.yml`, `autofix.yml` (formats PRs), `bootstrap-flutter.yml` (one-time)

## API v1
| Method | Path | Ticket |
| --- | --- | --- |
| GET | /api/v1/health/ | done |
| GET | /api/v1/schema/ | done |
| POST | /api/v1/auth/login/ · refresh/ · logout/ | done |
| POST | /api/v1/auth/register/ | T-10 |
| GET, PATCH | /api/v1/me/profile/ | T-11 |
| GET, POST | /api/v1/me/consents/ · /me/consents/<type>/withdraw/ | T-12 |
| GET, POST | /api/v1/foods/?q= · /foods/barcode/<code>/ · /foods/<id>/ | T-20–22 |
| GET, POST, PATCH, DELETE | /api/v1/diary/ · /diary/summary/ · /diary/copy/ | T-30, T-32 |
| GET, POST | /api/v1/sync/ | T-33 |
| CRUD | /api/v1/weight/ · /api/v1/water/ | T-40 |
| GET | /api/v1/stats/summary/ | T-42 |
| GET, DELETE | /api/v1/me/export/ · /api/v1/me/ | T-43 |

## Food search (T-22)
- PostgreSQL only (SQLite is no longer supported): extensions `pg_trgm`, generated column `search_vector`.
- Filter: every word must appear in name or brand (`icontains`, trigram GIN index) – finds German compounds ("saft" → "Apfelsaft").
- Order: own custom foods, then foods sold in `?country=`, then full-text rank (name weight A, brand B, prefix match), then name.
- Visibility: shared foods (Open Food Facts, TAMRA) plus the user's own custom foods; never other users' custom foods.
- Barcode: own custom food → local database → Open Food Facts API (5 s timeout, User-Agent) → 404.
- Import: `python manage.py import_off_jsonl <dump.jsonl.gz> --countries de,fr,it,be` (streaming, no full load).

## Error format
`{"code": "validation_error", "message": "Invalid input.", "fields": {"email": ["..."]}}` – for every error.

## Medical boundary
No insulin dose calculation. Carb counting (g / KE 10 g / BE 12 g) and logging only.
