# Sprint 4 – Weight, water, statistics, settings

Read `QWEN.md` before every ticket.

---

## T-40: Weight and water logs (api)

**Files to read:** `api/core/models.py`, `api/core/permissions.py`, `api/config/urls.py`, `api/diary/views.py` (pattern)

**Files to create/change:** new Django app `api/tracking/` (models, serializers, views, urls, admin,
migrations, tests), settings, `config/urls.py` (`path("api/v1/", include("tracking.urls"))`), `docs/openapi.yaml`

**Models (both `OwnedModel`)**
- `WeightLog`: `date` (DateField), `weight_kg` (Decimal 5,1; 30–300). One per user and day:
  `UniqueConstraint(fields=["user", "date"], condition=Q(deleted_at__isnull=True))`; POST for an
  existing day updates it (return 200 instead of 201).
- `WaterLog`: `date`, `amount_ml` (PositiveIntegerField, 1–5000). Many per day.

**Endpoints:** `GET/POST /api/v1/weight/?from=&to=`, `PATCH/DELETE /api/v1/weight/<uuid>/`,
`GET/POST /api/v1/water/?date=`, `DELETE /api/v1/water/<uuid>/`,
`GET /api/v1/water/summary/?date=` → `{"date", "total_ml"}`.
After saving a weight, also update `Profile.weight_kg` with the newest weight and recalculate targets
(reuse `profiles.calculations`).

**Tests:** CRUD, ownership 404, unique per day update, range filter, water total, profile updated.

---

## T-41: App – weight and water (app)

**Files to read:** `QWEN.md`, `app/lib/core/api/api_client.dart`, `app/lib/core/nutrition/nutrition.dart`,
`app/lib/features/diary/presentation/diary_screen.dart`, `app/lib/app/router.dart`, `app/lib/l10n/*`

**Files to create/change:** `app/pubspec.yaml` (add `fl_chart: ^0.69.0`),
`app/lib/features/tracking/{domain,data,presentation}/...`, a water card on the diary screen,
route `/weight`, bottom navigation (Diary, Weight, Statistics, Settings) in `lib/app/`, texts, tests.

**Specification:** weight screen with line chart (last 90 days), list, add/edit dialog in kg or lb
(profile `weight_unit`, convert with `Units`); water card: 8 glass buttons of 250 ml, tap adds,
long-press removes the last one, goal 2000 ml.

**Tests:** lb input saves kg value; chart shows with 0, 1 and many points without crashing;
water card add/remove with fake repository.

---

## T-42: Statistics – 7 days (api + app)

**API:** `GET /api/v1/stats/summary/?from=YYYY-MM-DD&to=YYYY-MM-DD` (max 31 days else 400) →
list per day `{date, kcal, protein, carbs, fat, water_ml, weight_kg}` (missing day = zeros, weight null).
Put the view in `api/tracking/` or a new app `api/stats/`. Tests: totals, empty days, range limit, ownership.

**App:** statistics screen (tab from T-41): bar chart kcal per day vs. target line, averages for
protein/carbs/fat, weight change in the period. Free version shows 7 days (later PRO: more).
Tests with fake repository; German and Arabic render.

---

## T-43: Settings, data export, delete account (api + app)

**API**
- `GET /api/v1/me/export/` → JSON with profile, consents, custom foods, diary entries, weight
  and water logs of the user (GDPR Art. 20). Header `Content-Disposition: attachment; filename="tamra-export.json"`.
- `DELETE /api/v1/me/` with body `{"password": "..."}` → wrong password 400; correct → user and all
  data deleted for real (not soft) → 204. Blacklist all the user's refresh tokens.
- Tests: export contains only own data; delete removes everything; wrong password keeps data.

**App:** settings screen: language (5 + "device"), weight unit, energy unit, carb unit (g/KE/BE),
withdraw health-data consent (with warning), export data (save/share the JSON file), logout,
delete account (confirmation dialog + password). Changes PATCH the profile. Tests for each action
with fakes.

---

## T-44: Accessibility, RTL and store texts [Claude]

Done by Claude with the owner: screen reader labels, contrast, text scaling, Arabic review,
store descriptions in 5 languages, screenshots.
