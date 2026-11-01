# Sprint 6 – Motivation and new features

Read `AGENTS.md` (and through it `QWEN.md` §2–§7) before every ticket.
Order: T-63a → T-63b → CHORE-01 → T-65a → T-65b → T-61 → T-62 → T-60. One ticket = one branch = one pull request.

---

## T-63a: Streak and badges (api)

**Branch:** `feat/T-63a-streak-api`

**Goal:** the app can show "5 days in a row" and three badges (7, 30, 100 days). Consistency is
rewarded, never eating less: a day counts as soon as it has **at least one diary entry**,
whatever the calories (fixed decision D4).

**Files to read:** `api/stats/views.py`, `api/stats/services.py`, `api/stats/serializers.py`,
`api/stats/urls.py`, `api/stats/tests/test_balance.py` (test pattern), `api/diary/models.py`,
`api/diary/views.py` (`required_date`, `DATE_PARAM`), `api/core/models.py` (soft delete).

**Files to create/change:**
- `api/stats/streaks.py` (new) – pure logic, no request objects
- `api/stats/serializers.py`, `api/stats/views.py`, `api/stats/urls.py`
- `api/stats/tests/test_streak.py` (new)
- `docs/openapi.yaml` (regenerated, see below)
- `docs/tickets/sprint-6.md` and `docs/tickets/README.md` (Claude wrote them; commit them unchanged)

**Endpoint:** `GET /api/v1/stats/streak/?date=YYYY-MM-DD` (`date` = the user's local today,
required, `required_date`). Logged in only (default permission). Answer 200:
```json
{
  "date": "2026-11-02",
  "current_days": 5,
  "longest_days": 12,
  "logged_today": false,
  "badges": [
    {"days": 7, "earned": true, "earned_on": "2026-10-15"},
    {"days": 30, "earned": false, "earned_on": null},
    {"days": 100, "earned": false, "earned_on": null}
  ]
}
```

**Rules (put them in the docstrings of `streaks.py`):**
- Logged day = a date with at least one diary entry of this user that is not soft-deleted
  (`DiaryEntry.objects`, which already hides deleted ones). Entries after `date` are ignored.
  Water, weight and sport do not count (keep it simple; may change later).
- `current_days`: consecutive logged days ending at `date`. If `date` itself has no entry yet,
  the run ending at `date - 1 day` counts (today is not over, the streak is not broken yet).
  Otherwise 0.
- `longest_days`: the longest run of consecutive logged days up to `date` (≥ `current_days`).
- `logged_today`: `date` has at least one entry.
- Badges `BADGE_DAYS = (7, 30, 100)`: `earned` when `longest_days >= days`; `earned_on` = the
  date on which a run first reached that length (the 7th day of the first 7-day run), else null.
- One query: `values_list("date", flat=True).distinct().order_by("date")` filtered by user and
  `date__lte`. Then compute in Python in `streaks.py`
  (`def compute_streak(days: list[date], today: date) -> StreakResult`, a frozen dataclass).

**Serializer:** `StreakBadgeSerializer` (days, earned, earned_on) and `StreakSerializer`.
View `StatsStreakView(APIView)` with `@extend_schema(parameters=[DATE_PARAM], responses=StreakSerializer)`,
URL name `stats-streak`.

**Tests (`test_streak.py`, `APITestCase` + unit tests for `compute_streak`):**
1. No entries → 0 / 0 / `logged_today` false / all badges not earned.
2. Entries yesterday and the 2 days before, none today → `current_days` 3, `logged_today` false.
3. Entry today plus yesterday → 2, `logged_today` true.
4. A gap of one day breaks the run; `longest_days` keeps the older, longer run.
5. Two entries on the same day count as one day.
6. Soft-deleted entry does not count (`entry.soft_delete()`).
7. Entries of another user do not count.
8. Entries after `date` are ignored.
9. 7-day badge: `earned_on` is the 7th day of the first 7-day run; 30-day badge with 30 days.
10. Missing or wrong `date` → 400; not logged in → 401.

**OpenAPI:** regenerate in Docker and copy over the contract:
`cd api && docker compose run --rm api python manage.py spectacular --file /app/openapi.tmp.yaml`
then move `api/openapi.tmp.yaml` to `docs/openapi.yaml` (replace).

**Checks:** API tests, `ruff check .`, `ruff format --check .`,
`python manage.py makemigrations --check --dry-run` (no migration expected) – see `AGENTS.md` §3.
**Commit:** `feat(api): streak and badges endpoint (T-63a)`.

---

## T-63b: Streak and badges (app)

**Branch:** `feat/T-63b-streak-app` (start after T-63a is merged).

**Files to read:** `AGENTS.md`, `app/lib/core/api/api_client.dart` (`statsSummary` as pattern),
`app/lib/features/stats/data/stats_repository.dart`, `app/lib/features/stats/domain/stats.dart`,
`app/lib/features/stats/presentation/stats_screen.dart`,
`app/lib/features/diary/presentation/diary_screen.dart`, `app/lib/core/json.dart`,
`app/lib/l10n/translations.dart`, `app/lib/l10n/app_strings.dart`,
`app/test/helpers/fakes.dart`, `app/test/features/stats/stats_test.dart`.

**Files to create/change:**
- `app/lib/core/api/api_client.dart` – `Future<Map<String, dynamic>> statsStreak(String date)`
- `app/lib/features/stats/domain/streak.dart` (new) – `Streak` and `StreakBadge` with `fromJson`
- `app/lib/features/stats/data/stats_repository.dart` – `Future<Streak> streak(DateTime today)` and
  `streakProvider`
- `app/lib/features/stats/presentation/streak_chip.dart` (new) – `StreakChip`
- `app/lib/features/stats/presentation/badges_card.dart` (new) – `BadgesCard`
- `app/lib/features/diary/presentation/diary_screen.dart` – show `StreakChip` below the calorie arc
  (only when the selected day is today)
- `app/lib/features/stats/presentation/stats_screen.dart` – `BadgesCard` as the last card
- `app/lib/l10n/translations.dart`, `app/lib/l10n/app_strings.dart`
- `app/test/helpers/fakes.dart` (`FakeStatsRepository.streakResult`, optional `streakError`)
- `app/test/features/stats/streak_test.dart` (new)

**Provider:** `streakProvider = FutureProvider.autoDispose<Streak>` that first watches the diary of
the selected day (`await ref.watch(diaryDayProvider(ref.watch(selectedDayProvider)).future)`)
so it reloads whenever the diary reloads after add, delete or copy, then calls
`streak(dateOnly(DateTime.now()))`. No other screen needs to invalidate it.

**StreakChip (diary):**
- Loading or error (e.g. offline): show nothing (`SizedBox.shrink()`), never an error text.
- `current_days == 0`: neutral text `streakStart`.
- `current_days > 0`: icon `Icons.local_fire_department` in `colors.brand`, text `streakDays`
  (`streakOneDay` for 1); if `logged_today` is false add a second line `streakKeepGoing`.
- Below, small and in `textSecondary`: `streakLongest` when `longest_days > current_days`.
- Key `streak-chip`; Semantics label = the visible text. No red, no "lost" or "failed" wording.

**BadgesCard (statistics):** title `badgesTitle`, three items in a `Wrap` (7, 30, 100). Earned:
icon `Icons.emoji_events` in `colors.brand`, `badgeDays`, `badgeEarnedOn` with the date via
`MaterialLocalizations.formatMediumDate`. Not earned: `Icons.emoji_events_outlined` in
`textSecondary`, `badgeDays`, `badgeOpen` with `days - current_days` days. Keys `badge-7`,
`badge-30`, `badge-100`. Must fit with 200 % text (use `Wrap`, no fixed heights).

**Texts (add exactly these to all five languages):**

| Key | en | de | fr | it | ar |
| --- | --- | --- | --- | --- | --- |
| streakDays | {days} days in a row | {days} Tage in Folge | {days} jours d’affilée | {days} giorni di fila | أيام متتالية: {days} |
| streakOneDay | 1 day – a good start | 1 Tag – ein guter Anfang | 1 jour – un bon début | 1 giorno – un buon inizio | يوم واحد – بداية جيدة |
| streakStart | Log something today to start a streak | Trag heute etwas ein und starte eine Serie | Note quelque chose aujourd’hui pour lancer une série | Registra qualcosa oggi per iniziare una serie | سجّل شيئًا اليوم لتبدأ سلسلة |
| streakKeepGoing | Log today to keep it going | Trag heute etwas ein, um weiterzumachen | Note quelque chose aujourd’hui pour continuer | Registra qualcosa oggi per continuare | سجّل شيئًا اليوم لتستمر |
| streakLongest | Best: {days} days | Rekord: {days} Tage | Record : {days} jours | Record: {days} giorni | الأفضل: {days} |
| badgesTitle | Badges | Abzeichen | Badges | Badge | الشارات |
| badgeDays | {days} days | {days} Tage | {days} jours | {days} giorni | {days} يومًا |
| badgeEarnedOn | Earned {date} | Erreicht am {date} | Obtenu le {date} | Ottenuto il {date} | حصلت عليها في {date} |
| badgeOpen | {days} days to go | Noch {days} Tage | Encore {days} jours | Ancora {days} giorni | باقي {days} يومًا |

**Tests (`streak_test.dart`, with fakes, no network):**
1. `Streak.fromJson` reads the API example from T-63a.
2. Diary shows `streak-chip` with "5 days in a row" (en) for `current_days: 5`.
3. `logged_today: false` shows the keep-going line; `true` hides it.
4. `current_days: 0` shows `streakStart`.
5. Repository error → no chip and no error text.
6. Chip is hidden when another day than today is selected.
7. Statistics shows `badge-7` earned with a date and `badge-30` with "23 days to go"
   (`current_days: 7`).
8. Arabic renders without exceptions (right-to-left).
The existing 200 % test in `app/test/accessibility/accessibility_test.dart` must stay green
(it visits diary and statistics).

**Commit:** `feat(app): streak chip and badges (T-63b)`.

### Review 1 for T-63b (Claude, 01.11.2026) – PR #3, 1 change, same branch

CI is green. Everything in the ticket is implemented as written (API call, model, provider,
chip states, badges, keys, all 45 texts, tests 1–8). One concrete deviation:

1. **Chip position in the diary.** `StreakChip` sits between `CalorieArc` and the
   `calorie-formula` text, so it separates the arc from its formula (decision D3: the formula is
   always visible directly under the arc). Move the
   `if (DateUtils.isSameDay(day.date, DateTime.now())) const StreakChip(),` block in
   `app/lib/features/diary/presentation/diary_screen.dart` to directly **after** the
   `calorie-formula` `Text` (before `const SizedBox(height: 16)`). Nothing else changes.

Accepted scope deviation: commit `347241a` adds braces to single-line `if` statements in
`health_card.dart`, `offline_diary_repository.dart`, `custom_food_screen.dart` and
`profile_screen.dart`. They are outside the ticket, but needed: the autoformat commit on `main`
split those lines and `flutter analyze` then reported `curly_braces_in_flow_control_structures`.
Claude fixes the cause in the Autofix workflow separately.

Files to change: `diary_screen.dart`, this ticket file (commit only).
Commit: `fix(app): streak chip below the calorie formula (T-63b)`.

---

## CHORE-01: Autofix must not break `main` (ci)

**Branch:** `chore/CHORE-01-autofix-analyze` (start from the newest `main`, after PR #3 is merged).

Claude already changed `.github/workflows/autofix.yml` in the folder: after `dart format` it runs
`flutter analyze`, and if that fails it throws the app formatting away instead of pushing a
`main` that does not pass analyze. Reason: the autoformat commit `4143116` split one-line `if`
statements and `flutter analyze` failed on them (fixed by hand in T-63b).

Do: commit `.github/workflows/autofix.yml`, `docs/tickets/sprint-6.md` and `docs/tickets/README.md` exactly as they are. No other
change. Commit: `ci: autofix keeps flutter analyze green (CHORE-01)`.

---

## T-65a: Feature flags (api)

**Branch:** `feat/T-65a-flags-api`

**Goal:** switch new features (fasting, photo scan, recipes) on and off without an app release,
first for single test accounts, later for everyone. Flags are not secret; they never contain
health data.

**Files to read:** `api/core/urls.py`, `api/core/views.py`, `api/core/models.py`,
`api/config/settings/base.py` (`env_list`), `api/profiles/admin.py` (admin pattern),
`api/stats/tests/test_streak.py` (test pattern).

**Files to create/change:**
- `api/config/settings/base.py` – `FEATURE_FLAGS` and `FEATURE_FLAGS_ON`
- `api/core/flags.py` (new) – `def flags_for(user) -> dict[str, bool]`
- `api/core/models.py` – model `FlagOverride`; migration `api/core/migrations/000X_flagoverride.py`
- `api/core/admin.py` (new or extend) – register `FlagOverride`
- `api/core/views.py`, `api/core/urls.py` – `FlagsView`, URL `flags/`, name `flags`
- `api/core/tests/test_flags.py` (new), `docs/openapi.yaml` (regenerate as in T-63a)

**Rules:**
- Known flags and their default (all off) in settings:
  `FEATURE_FLAGS = {"fasting": False, "photo_scan": False, "recipes": False}`.
- Global switch-on per server via environment: `FEATURE_FLAGS_ON = env_list("FEATURE_FLAGS_ON")`,
  e.g. `FEATURE_FLAGS_ON=fasting,recipes`. Unknown names there are ignored.
- Per-user override for testing: `FlagOverride(TimeStampedModel)` with `user` (FK, cascade),
  `name` (CharField, choices = the keys of `FEATURE_FLAGS`), `enabled` (bool);
  `UniqueConstraint(fields=["user", "name"])`. Set in Django admin only (no API to change it).
- Result order: default → global environment → user override (the override wins).
- `flags_for` returns every known flag, never unknown names.
- `GET /api/v1/flags/` (logged in) → `{"flags": {"fasting": false, "photo_scan": false, "recipes": false}}`.
  Serializer `FlagsSerializer` with `flags = serializers.DictField(child=serializers.BooleanField())`.
- Account deletion: the cascade removes overrides; check that `accounts/data.py` export does not
  need them (flags are configuration, not personal data – do not add them to the export).

**Tests:** all off by default; `FEATURE_FLAGS_ON` turns one on (`override_settings`); an unknown
name in `FEATURE_FLAGS_ON` is ignored; a user override `enabled=True` turns one on only for that
user; an override `enabled=False` beats the global switch; answer has exactly the known keys;
401 when not logged in.

**Checks:** as in T-63a, plus `makemigrations --check` must pass after your migration.
**Commit:** `feat(api): feature flags with per-user override (T-65a)`.

---

## T-65b: Feature flags (app)

**Branch:** `feat/T-65b-flags-app` (after T-65a is merged).

**Files to read:** `AGENTS.md`, `app/lib/core/api/api_client.dart`,
`app/lib/core/offline/local_store.dart`, `app/lib/core/auth/auth_controller.dart`,
`app/lib/features/debug/presentation/debug_screen.dart`, `app/test/helpers/fakes.dart`.

**Files to create/change:**
- `app/lib/core/api/api_client.dart` – `Future<Map<String, dynamic>> flags()`
- `app/lib/core/flags/flags.dart` (new) – `FeatureFlags` (immutable, `bool isOn(String name)`,
  `fromJson`), `FlagsRepository`, `flagsProvider`, constants `Flag.fasting`, `Flag.photoScan`
  (`'photo_scan'`), `Flag.recipes`
- `app/lib/features/debug/presentation/debug_screen.dart` – list of all flags with on/off
- `app/test/helpers/fakes.dart` – `FakeFlagsRepository`
- `app/test/core/flags_test.dart` (new)

**Rules:**
- `flagsProvider = FutureProvider<FeatureFlags>`: loads `/api/v1/flags/` after login. The last
  answer is saved in the `LocalStore` under key `feature_flags`; offline the saved answer is used;
  without any saved answer every flag is off (`FeatureFlags.allOff`).
- Unknown flag names from the server are kept but never break anything; a missing name is off.
- Logout and account deletion delete the saved flags (same place where the diary cache is
  cleared, see `auth_controller.dart`).
- No user-facing texts in this ticket (debug screen only shows the raw flag names).

**Tests:** `fromJson`; missing name is off; network error with a saved answer uses it; network
error without one gives all off; logout clears the saved flags; debug screen lists the flags.
**Commit:** `feat(app): feature flags with offline cache (T-65b)`.
