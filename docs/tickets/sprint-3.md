# Sprint 3 – Diary

Read `QWEN.md` before every ticket.

---

## T-30: Diary entries and day summary (api)

**Files to read:** `api/core/models.py`, `api/core/permissions.py`, `api/foods/models.py`,
`api/profiles/models.py`, `api/config/urls.py`, `api/config/settings/base.py`

**Files to create/change:** new Django app `api/diary/` (models, serializers, views, urls, admin,
migrations, tests), `api/config/settings/base.py`, `api/config/urls.py`
(`path("api/v1/diary/", include("diary.urls"))`), `docs/openapi.yaml`

**Model `DiaryEntry(OwnedModel)`**
| Field | Type |
| --- | --- |
| `date` | `DateField(db_index=True)` (the user's local day) |
| `meal` | choices `breakfast, lunch, dinner, snack` |
| `food` | `ForeignKey(Food, on_delete=PROTECT, related_name="+")` |
| `amount_g` | `DecimalField(max_digits=7, decimal_places=2)` (> 0, ≤ 5000) |
| `unit_label` | `CharField(max_length=50, blank=True)` (e.g. "1 slice") |
| `kcal`, `protein`, `carbs`, `sugar`, `fat`, `fiber`, `salt` | `DecimalField(max_digits=8, decimal_places=2)` – snapshot for this amount |

Snapshot rule: on create and whenever `amount_g` or `food` changes, set the 7 nutrient fields from
`food.nutrients_for(amount_g)` in the serializer's `create`/`update`. The client never sends them.
`id` may be sent by the client (UUID, for offline use); if it already exists for another user → 400.

**Endpoints**
- `GET /api/v1/diary/?date=YYYY-MM-DD` (required) → the user's entries of that day, ordered by meal then `created_at`.
- `POST /api/v1/diary/` `{"id"?, "date", "meal", "food", "amount_g", "unit_label"?}` → 201 with
  nested food summary (`id`, `name`, `brand`).
- `PATCH /api/v1/diary/<uuid>/` (`meal`, `amount_g`, `unit_label`, `date`) → 200.
- `DELETE /api/v1/diary/<uuid>/` → soft delete → 204.
- `GET /api/v1/diary/summary/?date=YYYY-MM-DD` → `{"date", "totals": {kcal, protein, carbs, sugar, fat, fiber, salt},
  "meals": {"breakfast": {...totals}, ...}, "targets": {kcal, protein_g, carbs_g, fat_g} (from Profile, null if missing)}`.
  Sums as strings with 2 decimals (DRF `DecimalField` output).

**Tests:** snapshot values; PATCH amount recalculates; other user → 404 for GET/PATCH/DELETE;
deleted entries not listed and not summed; summary totals per meal; missing `date` → 400;
amount 0 → 400.

---

## T-31: App – diary screen and add entry (app)

**Files to read:** `QWEN.md`, `app/lib/core/api/api_client.dart`, `app/lib/core/nutrition/nutrition.dart`,
`app/lib/features/food/domain/food.dart`, `app/lib/features/food/presentation/food_search_screen.dart`,
`app/lib/app/router.dart`, `app/lib/l10n/*`

**Files to create/change:** `app/lib/features/diary/domain/diary_entry.dart`,
`app/lib/features/diary/data/diary_repository.dart`, `app/lib/features/diary/presentation/diary_screen.dart`,
`app/lib/features/diary/presentation/add_entry_screen.dart`, widgets in
`app/lib/features/diary/presentation/widgets/`, router (diary becomes `/`), texts, tests.

**Specification**
- Diary screen: date bar (previous/next day, tap for date picker, "today"), calorie summary
  (eaten / target / remaining), three macro progress rings (protein, carbs, fat in g vs. target),
  four meal sections with entries (name, amount, kcal) and "+" per meal.
- "+" opens food search (T-23) or barcode scan (T-24); after a food is chosen → add-entry screen:
  amount input in g (or serving if `serving_size_g` exists), live preview of nutrients via
  `NutritionPer100g.forGrams`, save → `POST /diary/` → back to diary, refreshed.
- Swipe an entry to delete (with undo snackbar 4 s, then `DELETE`). Tap to edit amount/meal.
- Display units from profile (`energy_unit`) via `Units`.

**Tests:** diary renders summary and meals with a fake repository; add entry flow; delete with undo
(no DELETE call when undo pressed); German and Arabic render; kJ display when profile says `kj`.

---

## T-32: Copy meal or day (api + app)

**API:** `POST /api/v1/diary/copy/` `{"from_date", "to_date", "meal"?}` → copies the user's
non-deleted entries (all or one meal) with new UUIDs and fresh snapshots → 201 `{"copied": n}`.
Tests: copy day, copy meal, nothing to copy → 201 with 0, other user's entries never copied.

**App:** menu on the diary screen: "copy yesterday" (whole day) and per meal "copy from yesterday";
refresh after success; texts in 5 languages; widget test with fake repository.

**Files to read:** `api/diary/*`, `app/lib/features/diary/*`, `app/lib/l10n/*`

---

## T-33: Offline storage and sync [Claude]

Done by Claude (architecture-critical): `drift` database in the app, sync queue, `GET/POST /api/v1/sync/`,
conflict rule "newest `updated_at` wins", integration tests with airplane mode.
Qwen does not start this ticket.
