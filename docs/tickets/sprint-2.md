# Sprint 2 – Foods

Read `QWEN.md` before every ticket.

---

## T-20: Food model (api)

**Goal:** One table for all foods (from Open Food Facts and user-created).

**Files to read:** `api/core/models.py`, `api/config/settings/base.py`

**Files to create/change:**
- create Django app `api/foods/` (`__init__.py`, `apps.py`, `models.py`, `admin.py`,
  `serializers.py`, `migrations/__init__.py`, `migrations/0001_initial.py`, `tests/__init__.py`, `tests/test_models.py`)
- change `api/config/settings/base.py` (`"foods"` in `INSTALLED_APPS`)

**Model `Food(TimeStampedModel)`**
| Field | Type |
| --- | --- |
| `name` | `CharField(max_length=255, db_index=True)` |
| `brand` | `CharField(max_length=255, blank=True)` |
| `barcode` | `CharField(max_length=32, null=True, blank=True, unique=True)` |
| `source` | choices `off`, `user`, `tamra`; default `user` |
| `created_by` | `ForeignKey(AUTH_USER_MODEL, null=True, blank=True, on_delete=SET_NULL, related_name="+")` |
| `language` | `CharField(max_length=5, blank=True)` |
| `countries` | `CharField(max_length=255, blank=True)` (comma-separated ISO codes, e.g. `de,fr`) |
| `kcal`, `protein`, `carbs`, `sugar`, `fat`, `saturated_fat`, `fiber`, `salt`, `alcohol` | `DecimalField(max_digits=7, decimal_places=2, default=0)` – all per 100 g |
| `serving_size_g` | `DecimalField(max_digits=7, decimal_places=2, null=True, blank=True)` |
| `serving_label` | `CharField(max_length=100, blank=True)` |
| `image_url` | `URLField(blank=True)` |
| `off_last_modified` | `DateTimeField(null=True, blank=True)` |

Methods: `nutrients_for(grams: Decimal) -> dict` returning the 9 nutrients for that amount
(value × grams / 100, `Decimal`, not rounded). `__str__` = `"name (brand)"` or `name`.
Admin: list `name, brand, barcode, source, kcal`, search `name, brand, barcode`, filter `source`.
`FoodSerializer`: all fields except `created_by`, `deleted_at`; `source` read-only.

**Tests:** `nutrients_for(150)` with kcal 200 → 300; barcode unique; `__str__`.

---

## T-21: Open Food Facts mapping and import (api)

**Goal:** Turn Open Food Facts products into `Food` rows (bulk import and single barcode).

**Files to read:** `api/foods/models.py`, `api/config/settings/base.py` (`OFF_USER_AGENT`, `OFF_BASE_URL`)

**Files to create/change:**
- create `api/foods/off.py`
- create `api/foods/management/__init__.py`, `api/foods/management/commands/__init__.py`,
  `api/foods/management/commands/import_off_jsonl.py`
- create `api/foods/tests/fixtures/off_product.json` (one realistic product, see below)
- create `api/foods/tests/test_off.py`
- change `api/requirements.txt` (add `requests>=2.32,<3.0`)

**`off.py`**
- `map_off_product(product: dict) -> dict | None`: reads `code`, `product_name` (or `product_name_<lang>`),
  `brands`, `lang`, `countries_tags` (`en:germany` → `de`; map at least germany→de, france→fr,
  italy→it, belgium→be, united-states→us, canada→ca, saudi-arabia→sa,
  united-arab-emirates→ae, egypt→eg, morocco→ma, tunisia→tn), `image_front_url`,
  `last_modified_t` (unix seconds), and from `nutriments`: `energy-kcal_100g`,
  `proteins_100g`, `carbohydrates_100g`, `sugars_100g`, `fat_100g`, `saturated-fat_100g`,
  `fiber_100g`, `salt_100g`, `alcohol_100g`. Returns `None` when there is no name or no
  `energy-kcal_100g`. Missing nutrients → 0. Negative or absurd values (> 1000 kcal, > 100 g) → `None`.
- `upsert_food(data: dict) -> Food`: `update_or_create` by `barcode`, `source="off"`.
- `fetch_off_product(barcode: str) -> dict | None`: `GET {OFF_BASE_URL}/api/v2/product/{barcode}.json`
  with header `User-Agent: settings.OFF_USER_AGENT`, timeout 5 s. Return `product` when
  `status == 1`, else `None`. Network errors → `None` (log a warning without product data).
- Management command `import_off_jsonl <path> [--countries de,fr,it,be] [--limit N]`:
  reads an Open Food Facts JSONL dump line by line, keeps products sold in one of the
  countries, maps and upserts them, prints the count. Must not load the whole file into memory.

**Tests:** mapping of the fixture (all fields); `None` for missing kcal; country mapping;
`fetch_off_product` with `unittest.mock.patch("foods.off.requests.get")` (status 1 and 0 and
exception); command with a temporary JSONL file of 3 lines (1 valid DE, 1 without kcal, 1 only US
with `--countries de`) → 1 food created.

---

## T-22: Food search, barcode lookup, custom food (api)

**Files to read:** `api/foods/models.py`, `api/foods/serializers.py`, `api/foods/off.py`,
`api/core/permissions.py`, `api/config/urls.py`

**Files to create/change:** `api/foods/views.py`, `api/foods/urls.py`, `api/config/urls.py`
(`path("api/v1/foods/", include("foods.urls"))`), `api/foods/tests/test_api.py`, `docs/openapi.yaml`

**Endpoints** (all need login)
- `GET /api/v1/foods/?q=<text>` (name `food-list`): `q` at least 2 characters else 400;
  `name__icontains` OR `brand__icontains`; foods from Open Food Facts and the user's own
  (`created_by=request.user`), not other users' custom foods; ordered by `name`; paginated.
- `GET /api/v1/foods/barcode/<str:barcode>/` (name `food-barcode`): local first; if missing call
  `fetch_off_product` → `map_off_product` → `upsert_food`; not found → 404. Barcode must be
  8–14 digits else 400. Throttle scope `barcode` = `30/min` (add to `DEFAULT_THROTTLE_RATES`).
- `POST /api/v1/foods/` : custom food, `source="user"`, `created_by=request.user`;
  `kcal` required, others default 0; values ≥ 0; `kcal` ≤ 900, grams ≤ 100.
- `GET /api/v1/foods/<uuid>/` detail (own custom or OFF foods only, else 404).

**Tests:** 401; search finds by name and brand; `q` too short 400; other user's custom food
not found; barcode local hit; barcode remote hit (mock `fetch_off_product`); not found 404;
invalid barcode 400; create custom food 201 and appears in own search only.

---

## T-23: App – food search (app)

**Files to read:** `QWEN.md`, `app/lib/core/api/api_client.dart`, `app/lib/core/nutrition/nutrition.dart`,
`app/lib/app/router.dart`, `app/lib/l10n/*`

**Files to create/change:**
- `app/lib/features/food/domain/food.dart` (`Food` with `fromJson`, field `per100g` of type `NutritionPer100g`)
- `app/lib/features/food/data/food_repository.dart` (`search(q)`, `byBarcode(code)`, `createCustom(...)`, `byId(id)`)
- `app/lib/features/food/presentation/food_search_screen.dart`
- `app/lib/features/food/presentation/custom_food_screen.dart`
- `ApiClient` methods, router routes `/food/search`, `/food/custom`, texts in 5 languages
- tests in `app/test/features/food/`

**Specification:** search field with debounce 400 ms and minimum 2 characters (never one request
per keystroke); result list with name, brand, kcal per 100 g; empty state with button
"create own food"; error state with retry. Tap on a result returns the `Food` to the caller
(`context.pop(food)`).

**Tests:** debounce (only one repository call after typing fast, use `tester.pump(Duration)`),
results shown, empty state, custom food form validation (kcal required, ≤ 900).

---

## T-24: App – barcode scanner (app)

**Files to read:** `QWEN.md`, `app/lib/features/food/data/food_repository.dart`, `app/pubspec.yaml`,
`app/ios/Runner/Info.plist`, `app/android/app/src/main/AndroidManifest.xml`

**Files to create/change:**
- `app/pubspec.yaml` (add `mobile_scanner: ^6.0.0`)
- `app/ios/Runner/Info.plist` (add `NSCameraUsageDescription`: "TAMRA uses the camera to scan barcodes of foods.")
- `app/android/app/src/main/AndroidManifest.xml` (add `<uses-permission android:name="android.permission.CAMERA" />`)
- `app/lib/features/food/presentation/barcode_screen.dart`, route `/food/scan`, texts
- tests in `app/test/features/food/`

**Specification:** camera preview with a frame; on first detected EAN-8/EAN-13/UPC code stop
scanning and call `byBarcode`; found → `context.pop(food)`; 404 → dialog "not found" with
button to create the food (prefill barcode); camera permission denied → explanation text and
button to open settings. Wrap `MobileScanner` behind a small interface `BarcodeSource` so the
widget test can inject fake codes.

**Tests:** fake code → repository called once even if the same code arrives twice; not found
dialog shown.
