# Sprint 5 – Activity, sport apps and calorie balance

Read `QWEN.md` before every ticket. Background and decisions: `docs/ARCHITECTURE.md`,
section "Activity and calorie balance".

Goal: TAMRA collects sport and steps from other apps (Apple Health, Health Connect and through
them Garmin, Fitbit, Polar, Samsung Health, Strava, …), shows a daily calorie balance
(eaten – burned against the target) and the history over weeks and months.

---

## T-50: Activity model, CRUD and import (api)

**Files to read:** `api/core/models.py`, `api/core/permissions.py`, `api/config/urls.py`,
`api/diary/views.py` (pattern), `api/accounts/data.py` (export and delete)

**Files to create/change:** new Django app `api/activity/` (models, serializers, views, urls, admin,
migrations, tests), settings, `config/urls.py` (`path("api/v1/", include("activity.urls"))`),
`api/accounts/data.py` (activities in export and delete), `docs/openapi.yaml`

**Model `Activity(OwnedModel)`**
- `date` (DateField, the local day of the start), `started_at` (DateTimeField, null),
  `kind` (choices: walking, running, cycling, swimming, strength, yoga, hiit, team_sport, hiking,
  dancing, other), `title` (CharField 100, blank),
- `duration_min` (PositiveIntegerField, 1–1440), `kcal` (Decimal 7,1; 0–10000),
  `distance_m` (PositiveIntegerField, null),
- `source` (choices: manual, apple_health, health_connect, strava, garmin, fitbit, polar),
  `external_id` (CharField 200, blank).
- `UniqueConstraint(fields=["user", "source", "external_id"], condition=~Q(external_id="") & Q(deleted_at__isnull=True))`.

**Model `StepDay(OwnedModel)`:** `date`, `steps` (PositiveIntegerField, ≤ 200000), `source`.
`UniqueConstraint(fields=["user", "date"], condition=Q(deleted_at__isnull=True))`.

**Endpoints**
- `GET/POST /api/v1/activities/?date=` or `?from=&to=` (max 366 days), `PATCH/DELETE /api/v1/activities/<uuid>/`.
  Only `source=manual` may be changed by PATCH; imported ones only deleted (soft).
- `POST /api/v1/activities/import/` – body `{"activities": [...max 500], "steps": [{date, steps, source}]}`.
  Idempotent upsert: same `user + source + external_id` updates instead of duplicating; a soft-deleted
  import stays deleted (the user removed it on purpose). Steps: one value per day, the higher wins.
  Answer `{"created": n, "updated": n, "skipped": n}`.
- `GET /api/v1/activities/summary/?date=` → `{"date", "burned_kcal", "minutes", "steps"}`.

**Tests:** CRUD, ownership 404, import twice = no duplicates, deleted import stays deleted, range limit,
PATCH on imported → 400, steps max per day, export contains activities, account delete removes them.

---

## T-51: Calorie balance and history (api)

**Files to read:** `api/diary/views.py` (summary), `api/profiles/models.py`, `api/activity/` (T-50),
the T-42 stats view

**Files to create/change:** the stats view from T-42 (`api/stats/` or `api/tracking/`), tests, `docs/openapi.yaml`

**Rules (see ARCHITECTURE "Activity and calorie balance")**
- `budget = kcal_target + burned_kcal` when the profile setting `count_activity_kcal` is true (default true),
  otherwise `budget = kcal_target`.
- `remaining = budget – eaten_kcal`. Steps are shown, but only workouts count as burned kcal
  (no double counting with the activity level of the target).
- Add `count_activity_kcal` (BooleanField, default True) to `Profile` (migration, PATCH /me/profile/).

**Endpoints**
- `GET /api/v1/stats/day/?date=` → `{date, kcal_target, eaten_kcal, burned_kcal, budget, remaining,
  protein, carbs, fat, steps, activities: [...]}`.
- Extend `GET /api/v1/stats/summary/?from=&to=` (T-42) per day with `burned_kcal`, `steps`, `balance`
  (`eaten – budget`) and allow up to 366 days with `?group=day|week|month` (week = ISO week, values are
  averages per logged day; month the same).

**Tests:** budget with and without `count_activity_kcal`, days without data, week and month grouping,
366-day limit, ownership.

---

## T-52: App – activities and manual sport entry (app)

**Files to read:** `QWEN.md`, `app/lib/core/api/api_client.dart`, `app/lib/core/nutrition/nutrition.dart`,
`app/lib/app/router.dart`, `app/lib/l10n/*`, `app/lib/features/food/` (pattern)

**Files to create/change:** `app/lib/features/activity/{domain,data,presentation}/...`,
`nutrition.dart` (`activityKcal`), routes `/activity` and `/activity/add`, texts, tests

**Specification**
- `activityKcal({required double met, required double weightKg, required int minutes})`
  = MET × weight kg × minutes / 60 (in `nutrition.dart`, unit-tested). MET table in
  `features/activity/domain/met.dart` (walking 3.5, running 9.8, cycling 7.5, swimming 6.0,
  strength 5.0, yoga 2.5, hiit 8.0, team_sport 7.0, hiking 6.0, dancing 5.0, other 4.0).
- Add screen: kind (grid with icons), duration, optional distance, kcal suggested from MET and the
  profile weight and editable.
- Activity list of the day with source icon (hand, Apple Health, Health Connect, …); imported entries
  can only be deleted.
- Onboarding activity question gets the hint "daily life without sport – sport is added separately".

**Tests:** MET formula; suggested kcal updates when duration changes; edited kcal is kept;
imported entry has no edit button; texts in all 5 languages.

---

## T-53: App – connect Apple Health and Health Connect [Claude]

Package `health`, iOS HealthKit entitlement and usage texts, Android Health Connect permissions and
privacy-policy activity, settings screen "Connected apps" (connect, last sync, disconnect,
"also delete imported data"). Reads workouts (active energy, duration, distance), steps per day and
weight; writes eaten kcal and macros back (optional switch). Sync on app start and pull-to-refresh,
last 30 days on first connect, then since the last sync; uploads through `/activities/import/`
(idempotent). Garmin, Fitbit, Polar, Samsung Health and Strava are covered when the user lets them
write into Apple Health / Health Connect (in-app help text per app).

---

## T-54: App – balance dashboard and history (app)

**Files to read:** `QWEN.md`, T-51 endpoints, `app/lib/features/diary/` (T-31), the statistics screen (T-42)

**Specification**
- Diary header: ring "remaining kcal" with the line `target + sport – eaten = remaining`
  (the formula is always visible), steps and sport minutes below.
- Statistics: switch 7 days / 4 weeks / 12 months (`group=day|week|month`); bars eaten vs. budget,
  burned kcal as a second series, weight line; averages.
- Free: 7 days and 4 weeks; 12 months marked for PRO (only a lock icon now, no payment yet).

**Tests:** formula text with numbers in German and Arabic; switch changes the request; empty history
renders without errors.

---

## Later (phase 3): direct cloud connections [Claude]

Strava (OAuth, webhooks), Garmin Health API (partner approval needed), Fitbit Web API,
Polar AccessLink – server-side, tokens encrypted, only when users need data that does not reach
Apple Health / Health Connect.
