# QWEN.md – Rules for the coding agent

You write code for TAMRA, a nutrition tracker app (Flutter app + Django API).
The foundation (Sprint 0) is finished and tested. Your job is ONLY to implement
one ticket at a time from `docs/tickets/`. Claude (architect) reviews your work.

## 1. How to answer a ticket

1. Read the ticket completely. Read every file listed under "Files to read".
2. Change ONLY the files listed under "Files to create/change". If you think another
   file must change, write it under "Questions" instead of changing it.
3. Output format (mandatory):
   - For every file: one heading with the full path, then the COMPLETE file content
     in one code block. Never output partial files, diffs or "..." placeholders.
     ```
     ### api/foods/models.py
     ```python
     <complete file>
     ```
     ```
   - At the end: "Commit message:" (Conventional Commits, e.g. `feat(api): add food model (T-20)`),
     "How to test:", "Questions:".
4. File names are paths like `api/foods/models.py`. Never create files with names like
   "Create new file", "new file" or "untitled".
5. Write tests for every ticket. A ticket without tests is not done.
6. Never invent results. If you are unsure whether code works, say so under "Questions".

## 2. Project layout (do not change)

```
api/                         Django 5 + Django REST Framework
  config/settings/           base.py, dev.py, test.py, prod.py
  config/urls.py             all /api/v1/ routes are included here
  core/                      BaseModel (TimeStampedModel, OwnedModel), IsOwner, errors, health
  accounts/                  User model (email login, UUID), auth URLs
  <app>/                     one Django app per domain: foods/, diary/, tracking/, ...
    models.py serializers.py views.py urls.py admin.py
    tests/test_*.py
app/                         Flutter
  lib/app/                   app.dart, router.dart, theme.dart, locale_provider.dart
  lib/core/                  config.dart, api/api_client.dart, nutrition/nutrition.dart
  lib/features/<feature>/
    data/                    repositories that call ApiClient
    domain/                  plain Dart models and logic
    presentation/            screens and widgets
  lib/l10n/                  app_strings.dart (getters), translations.dart (texts)
  test/                      mirrors lib/
docs/                        ARCHITECTURE.md, openapi.yaml, tickets/
```

## 3. API rules (Django)

- Every model with user data inherits `core.models.OwnedModel`
  (gives `id` UUID, `user`, `created_at`, `updated_at`, `deleted_at`, `soft_delete()`).
  Shared data (e.g. foods) inherits `core.models.TimeStampedModel`.
- Views: DRF generic views or ViewSets. Querysets ALWAYS filtered to `request.user`
  for user data: `Model.objects.filter(user=self.request.user)`.
- `perform_create` sets `user=self.request.user`. The client never sends `user`.
- Detail views use `permission_classes = [IsAuthenticated, IsOwner]` (from `core.permissions`).
- DELETE on user data = `instance.soft_delete()`, not a real delete.
- URLs: each app has `urls.py`; include it in `config/urls.py` under `api/v1/`.
- Errors come automatically in the format `{"code", "message", "fields"}`. Do not build your own.
- Add the new app to `INSTALLED_APPS` in `config/settings/base.py`.
- Every new model needs a migration file in `<app>/migrations/` (write it like Django's
  `makemigrations` output) and a registration in `admin.py`.
- Tests: `rest_framework.test.APITestCase`. Test 200/201/204/400/401/403/404 where relevant,
  and ALWAYS that user A cannot see or change data of user B (expect 404).
- Code style: ruff (line length 100), type hints on functions.
- Every public class, method and function gets a docstring (checked by ruff D101–D103 in CI).
- Never log or print health data (weight, food, kcal, body measurements, activity) or tokens.

## 4. App rules (Flutter)

- State: `flutter_riverpod` 2.x (`Provider`, `FutureProvider`, `NotifierProvider`).
  No code generation (no build_runner, no freezed, no riverpod_generator).
- Navigation: `go_router`. Add routes in `lib/app/router.dart` and paths in `AppRoutes`.
- HTTP: only through `ApiClient` in `lib/core/api/api_client.dart`. Add one method per endpoint.
  Errors are `ApiError` (code, message, fields, statusCode).
- Texts: NEVER write user-facing text in widgets. Add the key to ALL FIVE languages in
  `lib/l10n/translations.dart` (en, de, fr, it, ar) and a getter in `lib/l10n/app_strings.dart`.
  If you cannot translate, copy English and add `// TODO-TRANSLATE`.
- Right-to-left: use `EdgeInsetsDirectional`, `AlignmentDirectional`, `start`/`end`.
  Never `EdgeInsets.only(left: ...)` or `Alignment.centerLeft`.
- Units: store metric and kcal; convert only for display with `Units` from
  `lib/core/nutrition/nutrition.dart`. Nutrition math only via that file.
- Every public class, function, method and provider gets a `///` doc comment
  (checked in CI by `.github/scripts/check_dart_docs.py`).
- Colours only via `AppColors.of(context)` / the theme (tokens in `lib/app/theme.dart`,
  see `docs/DESIGN.md`), never `Color(0x...)` or `Colors.red` in a screen.
- Widgets: small, `const` where possible, `super.key`. Give important widgets a `Key('...')`
  so tests can find them.
- Tests: `flutter_test`. Unit tests for logic, widget tests for every screen
  (override providers with `ProviderScope(overrides: [...])`, no real network).

## 5. Clean code (object-oriented, commented)

- One class = one job: models hold data and rules about themselves, serializers validate,
  views only connect request → logic → response, services/repositories hold the rest.
- Share behaviour through base classes and interfaces (`OwnedModel`, `IsOwner`, `BarcodeSource`),
  not by copying code. Depend on interfaces so tests can swap in fakes.
- Doc comments say WHAT a class/function does and WHY (rules, limits, side effects),
  never repeat the code line by line. Comments inside functions only where the reason is not obvious.
- Names in English, full words (`weight_kg`, not `wkg`); units in the name (`_kg`, `_ml`, `_g`).
- No dead code, no commented-out code, no `print`.

## 6. Medical and privacy boundary

- No health claims in texts ("cures", "treats", "guaranteed weight loss").
- Calorie targets never below the safe minimum in `dailyCalorieTarget`.
- No secrets in code. Use environment variables / `--dart-define`.

## 7. Checks (run by GitHub automatically on every pull request)

API: `ruff check .`, `ruff format --check .`, `python manage.py makemigrations --check`,
`coverage run manage.py test` (≥ 80 %), OpenAPI validation.
App: `dart format --set-exit-if-changed lib test`, doc-comment check, `flutter analyze`, `flutter test`.
If a check fails, the owner sends you the log. Fix only what the log says.
