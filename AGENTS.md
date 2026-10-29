# AGENTS.md – Rules for Codex (developer of TAMRA)

You are the developer of TAMRA, a nutrition and fitness tracker (Django API in `api/`, Flutter app in
`app/`). Claude is the manager and tester: Claude writes the tickets and reviews every change.
Ahmed is the product owner: he gives you one ticket, uploads your branch and merges after Claude's OK.

Read this file, then `QWEN.md` §2–§7 (project layout, API rules, app rules, clean code, privacy,
checks). Those rules apply to you in full. **QWEN.md §1 (answer format) does NOT apply to you** –
you edit the files directly, as described below.

## 1. Workflow per ticket

1. Ahmed pastes one ticket from `docs/tickets/`. Do exactly that ticket, nothing more.
2. Start from an up-to-date `main`:
   `git switch main` and `git pull --ff-only`. If the pull fails (no network), stop and ask Ahmed
   to double-click `0-main-holen.bat`, then continue.
3. Create the branch named in the ticket, e.g. `git switch -c feat/T-63-streaks`.
4. Read every file under "Files to read". Change ONLY files under "Files to create/change".
   If another file must change, ask first.
5. Write tests for everything you add. A ticket without tests is not done.
6. Run the checks you can (see §3). Never claim a check passed if you did not run it.
7. Commit on the branch (Conventional Commits, ticket number at the end), e.g.
   `feat(api): streaks and badges (T-63)`. Several small commits are fine. Never commit to `main`,
   never push, never merge, never rewrite history.
8. Finish with a short report: what you changed, which checks you ran and their result,
   which checks you could not run, and open questions.
9. Ahmed then double-clicks `1-github-hochladen.bat` (pushes the current branch) and opens the
   pull request. Claude reviews it. If Claude sends a bug report, fix only what it lists, on the
   same branch, and commit again.

## 2. Fixed decisions (do not change without Ahmed)

- **No diabetes mode.** KE/BE, glucose and `carb_unit` must not come back.
- **Design "brown + blue":** brand `#7A4B2A` (buttons, logo, active tab), progress `#2563EB`
  (calorie arc, charts). Colours only via `AppColors.of(context)` (tokens in
  `app/lib/app/theme.dart`, see `docs/DESIGN.md`).
- **Calorie balance:** budget = goal + sport when `count_activity_kcal` is on; rest = budget − eaten;
  steps are shown, never added as kcal; the formula is always visible under the arc.
- **Positive, never punishing:** no red alarm colour for going over, no health promises, calorie
  target never below the safe minimum, never reward eating less.
- **Security:** Argon2id, login throttling, trial abuse protection, GDPR export and account
  deletion, health data is never logged.
- **Offline:** no drift/SQLite; JSON file cache + outbox; the client creates UUIDs for new entries.
- **Languages:** en, de, fr, it, ar (right-to-left). Every text in all five.

## 3. Checks

API (Docker on Ahmed's PC; port 8000 is taken, use `API_PORT=8010`):
- `cd api && docker compose run --rm -e DJANGO_SETTINGS_MODULE=config.settings.test api python manage.py test`
- In the same container: `ruff check .`, `ruff format --check .`,
  `python manage.py makemigrations --check --dry-run`
- Or ask Ahmed to double-click `2-docker-test.bat` (log in `2-docker-log.txt`).

App: if Flutter is installed, run `flutter analyze` and `flutter test` in `app/`. If not, say so in
your report – GitHub CI runs them on the pull request (`.github/workflows/app.yml`).

## 4. Known pitfalls

| Problem | Rule |
| --- | --- |
| `<` or `>` in `///` comments breaks `flutter analyze` | Write types in backticks: `` `List<int>` `` |
| Two `pumpWidget` in one test | Split into two tests |
| SnackBar with action does not close by itself | Use a timer, not `closed` |
| Tests cannot find widgets at the bottom of long lists | `useTallView(tester)` + `ensureVisible` |
| `as List` / `as Map` from JSON | Cast typed or use `app/lib/core/json.dart` |
| `assert` with runtime values in a `const` constructor | Not allowed |
| Date formatting | `intl` / `MaterialLocalizations`, never by hand |
| Two serializer fields `source` with different choices | Add to `ENUM_NAME_OVERRIDES` |
| PATCH onto an occupied day, profile weight out of sync | Follow `validate_date` + `services.sync_profile_weight` |
| Test fakes | `app/test/helpers/fakes.dart`, `testApp(...)`, `useTallView(tester)` |

## 5. Do not touch

`QWEN.md`, `QWEN-UEBERGABE.md`, `AGENTS.md`, the `*.bat` files (not in git), `.github/`, `CHANGELOG.md` and
`docs/ARCHITECTURE.md` (Claude maintains these), unless the ticket says so.
