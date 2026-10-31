# Sprint 6 – Motivation and new features

Read `AGENTS.md` (and through it `QWEN.md` §2–§7) before every ticket.
Order: T-63a → T-63b → T-65 → T-61 → T-62 → T-60. One ticket = one branch = one pull request.

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
