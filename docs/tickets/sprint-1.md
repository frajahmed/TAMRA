# Sprint 1 – Account and onboarding

Read `QWEN.md` before every ticket.

---

## T-10: Register endpoint (api)

**Goal:** A new user can create an account with email and password and is logged in directly.

**Files to read:** `api/accounts/models.py`, `api/accounts/urls.py`, `api/accounts/tests/test_auth.py`,
`api/core/exceptions.py`, `api/config/settings/base.py`

**Files to create/change:**
- create `api/accounts/serializers.py`
- create `api/accounts/views.py`
- change `api/accounts/urls.py`
- create `api/accounts/tests/test_register.py`

**Specification**
- `POST /api/v1/auth/register/`, no authentication (`authentication_classes = []`,
  `permission_classes = [AllowAny]`).
- Request: `{"email": "a@b.de", "password": "..."}`.
- `RegisterSerializer(serializers.ModelSerializer)`, model `User`, fields `id`, `email`, `password`.
  `password` is `write_only`. Validate the password with
  `django.contrib.auth.password_validation.validate_password`. Email is lower-cased.
  Duplicate email (case-insensitive) → validation error on field `email`.
- Create the user with `User.objects.create_user(email=..., password=...)`.
- Response `201`: `{"id": "<uuid>", "email": "a@b.de", "access": "<jwt>", "refresh": "<jwt>"}`.
  Create tokens with `rest_framework_simplejwt.tokens.RefreshToken.for_user(user)`.
- URL name: `auth-register`.

**Tests (all required)**
- 201 with `id`, `email`, `access`, `refresh`; user exists; password is hashed.
- `Test@Example.com` is stored as `test@example.com`.
- duplicate email (also with other upper/lower case) → 400, `fields.email` present.
- weak password `"123"` → 400, `fields.password` present.
- missing email → 400.
- the returned access token works: `GET /api/v1/health/` is public, so instead check
  `POST /api/v1/auth/refresh/` with the returned refresh token → 200.

---

## T-11: Profile endpoint and calorie target (api)

**Goal:** The app can save the user's body data and goals; the server calculates the calorie
and macro targets with the same formula as the app.

**Files to read:** `api/core/models.py`, `api/core/permissions.py`, `api/config/urls.py`,
`api/config/settings/base.py`, `app/lib/core/nutrition/nutrition.dart` (formula reference)

**Files to create/change:**
- create Django app `api/profiles/` with `__init__.py`, `apps.py`, `models.py`, `calculations.py`,
  `serializers.py`, `views.py`, `urls.py`, `admin.py`, `migrations/__init__.py`,
  `migrations/0001_initial.py`, `tests/__init__.py`, `tests/test_calculations.py`, `tests/test_profile.py`
- change `api/config/settings/base.py` (add `"profiles"` to `INSTALLED_APPS`)
- change `api/config/urls.py` (add `path("api/v1/me/", include("profiles.urls"))`)

**Model `Profile(TimeStampedModel)`** (one per user)
| Field | Type |
| --- | --- |
| `user` | `OneToOneField(AUTH_USER_MODEL, on_delete=CASCADE, related_name="profile")` |
| `sex` | `CharField(max_length=10, choices=[("female","female"),("male","male")], blank=True)` |
| `birth_year` | `PositiveSmallIntegerField(null=True, blank=True)` |
| `height_cm` | `DecimalField(max_digits=5, decimal_places=1, null=True, blank=True)` |
| `weight_kg` | `DecimalField(max_digits=5, decimal_places=1, null=True, blank=True)` |
| `activity_level` | choices `sedentary, light, moderate, active, very_active`, default `sedentary` |
| `goal` | choices `lose, maintain, gain`, default `maintain` |
| `kcal_target` | `PositiveIntegerField(null=True, blank=True)` |
| `protein_g`, `carbs_g`, `fat_g` | `PositiveIntegerField(null=True, blank=True)` |
| `weight_unit` | choices `kg, lb`, default `kg` |
| `energy_unit` | choices `kcal, kj`, default `kcal` |
| `carb_unit` | choices `g, ke, be`, default `g` |
| `language` | choices `de, en, fr, it, ar`, default `en` |

Validation: `birth_year` between current year − 100 and current year − 16;
`height_cm` 100–250; `weight_kg` 30–300.

**`calculations.py`** – plain functions, same numbers as Dart:
- `basal_metabolic_rate(sex, weight_kg, height_cm, age_years) -> float`
  (male: 10w + 6.25h − 5a + 5; female: 10w + 6.25h − 5a − 161)
- `ACTIVITY_FACTORS = {"sedentary": 1.2, "light": 1.375, "moderate": 1.55, "active": 1.725, "very_active": 1.9}`
- `daily_calorie_target(sex, weight_kg, height_cm, age_years, activity_level, goal) -> int`
  (lose −500, gain +300, never below max(BMR, 1200 female / 1500 male), rounded
  half away from zero: use `int(Decimal(x).quantize(Decimal("1"), rounding=ROUND_HALF_UP))`)
- `macro_targets(kcal) -> dict` → protein 30 %, carbs 40 %, fat 30 % of kcal;
  protein_g = round(kcal × 0.30 / 4), carbs_g = round(kcal × 0.40 / 4), fat_g = round(kcal × 0.30 / 9)

**Endpoint** `GET` and `PATCH /api/v1/me/profile/` (URL name `me-profile`)
- `RetrieveUpdateAPIView`, `get_object()` = `Profile.objects.get_or_create(user=request.user)[0]`.
- Read-only in the response: `kcal_target`, `protein_g`, `carbs_g`, `fat_g`, `updated_at`.
- After every PATCH: if `sex`, `birth_year`, `height_cm`, `weight_kg` are all set,
  recalculate `kcal_target` and macros and save. Age = current year − birth_year.

**Tests**
- calculations: the same 4 example cases as `app/test/core/nutrition_test.dart`
  (1742, 2182, 1452, 2296) and `macro_targets(2000)` → protein 150, carbs 200, fat 67.
- GET without token → 401. GET first time → 200 with defaults (profile created).
- PATCH complete body data → 200 and `kcal_target` filled.
- PATCH `height_cm: 50` → 400 `fields.height_cm`.
- Sending `kcal_target` in PATCH does not change it.
- user B never sees user A's profile (each gets their own).

---

## T-12: Consents (api)

**Goal:** Store when a user agreed to the processing of health data (GDPR Art. 9) and allow withdrawal.

**Files to read:** `api/core/models.py`, `api/profiles/urls.py` (from T-11), `api/profiles/views.py`

**Files to create/change:**
- change `api/profiles/models.py` (add `Consent`), `serializers.py`, `views.py`, `urls.py`, `admin.py`
- create `api/profiles/migrations/0002_consent.py`
- create `api/profiles/tests/test_consents.py`

**Model `Consent(OwnedModel)`**: `type` choices `health_data, terms, privacy, analytics`;
`version` `CharField(max_length=20)`; `given_at` `DateTimeField(default=timezone.now)`;
`withdrawn_at` `DateTimeField(null=True, blank=True)`.

**Endpoints**
- `GET /api/v1/me/consents/` → list of the user's consents, newest first (URL name `me-consents`).
- `POST /api/v1/me/consents/` `{"type": "health_data", "version": "2026-10"}` → 201.
- `POST /api/v1/me/consents/<type>/withdraw/` → sets `withdrawn_at` on all active consents of
  that type → 200 `{"withdrawn": <count>}` (URL name `me-consent-withdraw`).
- A consent is never deleted (proof). No PATCH, no DELETE.

**Tests:** 401 without token; create 201; list only own; withdraw sets `withdrawn_at`;
unknown type → 400; user B cannot withdraw user A's consents (count 0 for B).

---

## T-13: App – login, register, token handling (app)

**Goal:** Users can register and log in in the app; tokens are stored securely and refreshed automatically.

**Files to read:** `QWEN.md`, `app/lib/core/api/api_client.dart`, `app/lib/app/router.dart`,
`app/lib/l10n/app_strings.dart`, `app/lib/l10n/translations.dart`, `app/test/core/api_client_test.dart`,
`app/test/app/app_test.dart`, `docs/tickets/sprint-1.md` (T-10 for the API format)

**Files to create/change:**
- create `app/lib/core/auth/token_storage.dart`
- create `app/lib/core/auth/auth_controller.dart`
- change `app/lib/core/api/api_client.dart`
- create `app/lib/features/auth/presentation/login_screen.dart`
- create `app/lib/features/auth/presentation/register_screen.dart`
- change `app/lib/app/router.dart`
- change `app/lib/l10n/app_strings.dart`, `app/lib/l10n/translations.dart`
- create `app/test/core/auth_controller_test.dart`, `app/test/features/auth/login_screen_test.dart`
- change `app/test/app/app_test.dart` (tests must still pass; override auth as logged in)

**Specification**
- `TokenStorage` abstract class with `Future<String?> readAccess()`, `readRefresh()`,
  `Future<void> save({required String access, required String refresh})`, `Future<void> clear()`.
  Implementations: `SecureTokenStorage` (uses `flutter_secure_storage`) and `MemoryTokenStorage` (tests).
  `tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage())`.
- `ApiClient` new methods: `register(email, password)`, `login(email, password)`
  (`POST /api/v1/auth/login/` body `{"email","password"}` → `{"access","refresh"}`),
  `refresh(refreshToken)`, `logout(refreshToken)`.
- Dio `InterceptorsWrapper` in `dioProvider`: adds `Authorization: Bearer <access>` when a token
  exists; on 401 tries ONE refresh, saves new tokens, repeats the request; if refresh fails →
  clears tokens and sets auth state to logged out.
- `AuthController extends Notifier<AuthState>`; `AuthState` = `unknown`, `loggedOut`, `loggedIn`.
  On start reads tokens → `loggedIn` or `loggedOut`. Methods `login`, `register`, `logout`.
- Router: `redirect` → if `loggedOut` and not on `/login` or `/register` → `/login`;
  if `loggedIn` and on `/login` → `/`. Use `refreshListenable` or rebuild via provider.
- Screens: email field, password field (obscured), button, link to the other screen,
  error text from `ApiError.message` or field errors. Keys: `login-email`, `login-password`,
  `login-submit`, `register-email`, `register-password`, `register-submit`.
- New texts in all 5 languages: login, register, email, password, noAccount, haveAccount,
  logout, genericError.

**Tests:** AuthController with `MemoryTokenStorage` and a fake `ApiClient` (login success →
loggedIn + tokens saved; logout → tokens cleared); login screen widget test (enter text, tap
submit, fake controller called; error text shown on `ApiError`).

---

## T-14: App – consent and onboarding (app)

**Goal:** After registration the user agrees to health-data processing and enters body data;
the app shows the calorie target with the formula.

**Files to read:** `QWEN.md`, `app/lib/core/nutrition/nutrition.dart`, `app/lib/core/api/api_client.dart`,
`app/lib/app/router.dart`, `app/lib/l10n/*`, `docs/tickets/sprint-1.md` (T-11, T-12)

**Files to create/change:**
- create `app/lib/features/onboarding/domain/profile.dart` (class `Profile` with `fromJson`/`toJson`)
- create `app/lib/features/onboarding/data/profile_repository.dart`
  (`getProfile()`, `updateProfile(Map)`, `giveConsent(type, version)`) using new `ApiClient` methods
- create `app/lib/features/onboarding/presentation/consent_screen.dart`
- create `app/lib/features/onboarding/presentation/onboarding_screen.dart`
- change `app/lib/core/api/api_client.dart`, `app/lib/app/router.dart`, `app/lib/l10n/*`
- create tests in `app/test/features/onboarding/`

**Specification**
- Consent screen: short text (health data is stored to show your nutrition; you can withdraw any
  time in settings), checkbox, button disabled until checked → `POST /me/consents/`
  `{"type":"health_data","version":"2026-10"}`.
- Onboarding: one page per question with progress indicator: goal, sex, birth year, height (cm),
  weight (kg), activity level. Then a result page: kcal target (from server response) and the
  sentence "Calculated with Mifflin-St Jeor × activity factor …", plus macros in g.
  Show the local value from `dailyCalorieTarget` while saving; after the PATCH show the server value.
- Router: logged in and no consent or profile incomplete → `/onboarding/consent` or `/onboarding`.
- No text in widgets without translation keys. Inputs validate the same ranges as T-11.

**Tests:** consent button disabled until checked; onboarding happy path with fake repository
ends on result page showing the target; invalid height shows error text; Arabic layout test (RTL).
