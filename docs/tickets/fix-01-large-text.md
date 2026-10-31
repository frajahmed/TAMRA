# FIX-01 – Layout breaks with 200 % text (app)

**Branch:** `fix/FIX-01-large-text`
**Found by:** GitHub CI run 40962703395 on commit `f8b1750` (workflow "App", job "test").
API CI is green. Analyze and doc comments are green. Only `flutter test` is red.

## Goal

The test `all tabs fit on a small phone with 200 % text (de / ar / fr)` in
`app/test/accessibility/accessibility_test.dart` must pass. It pumps the app on a 360 × 740 phone
with text scale 2.0 and visits all tabs. Any overflow fails the test. The test is correct and
must NOT be changed – fix the screens.

## Step 0 – workflow files (separate first commit)

These new files are already in the folder but not yet committed. Commit them first, unchanged,
as `chore: Codex workflow – AGENTS.md and FIX-01 ticket`:
`AGENTS.md`, `docs/tickets/fix-01-large-text.md`,
`QWEN-UEBERGABE.md`.

## Errors from CI (4 places)

| # | File and line | Error |
| --- | --- | --- |
| 1 | `app/lib/core/widgets/calorie_arc.dart:46` | `Column` inside the fixed `SizedBox(220 × 170)` overflows by 54 px at the bottom |
| 2 | `app/lib/features/stats/presentation/stats_screen.dart:31` | `AppBar.bottom` has a fixed `PreferredSize` height of 56; the `SegmentedButton` is taller with large text (overflow 56 px) |
| 3 | `app/lib/features/activity/presentation/activity_screen.dart:77` | `Row` in the summary card overflows by 15 px on the right (steps text is not flexible) |
| 4 | `app/lib/features/settings/presentation/profile_screen.dart:160` | `ListTile` with a `DropdownButton` as `trailing`: "Trailing widget consumes the entire tile width" (language setting) |

## How to fix (suggested, keep it simple)

1. **Calorie arc:** keep the arc size. Wrap the centre `Column` in
   `FittedBox(fit: BoxFit.scaleDown)` so the number and label shrink to fit inside the arc.
   The `Semantics` label stays, so screen readers still read the full value.
2. **Statistics:** move the `SegmentedButton` (key `stats-range`) out of `AppBar.bottom` into the
   top of the body (first child of the scroll view, same padding). The key must stay the same.
3. **Activity card:** make the steps part flexible, e.g. wrap the steps `Text` in `Flexible`
   with `overflow: TextOverflow.ellipsis` is NOT enough for accessibility – instead put the steps
   (icon + text) on their own line under the minutes when space is short. Simplest: replace the
   `Row` with a `Wrap` (spacing 8, run spacing 4) whose first child is the kcal/minutes column.
   Keys `activity-burned` and `activity-steps` stay.
4. **Language setting:** do not use `trailing` for the dropdown. Show the label as `title` and the
   `DropdownButton` (key `language`, `isExpanded: true`) as `subtitle`, or use a full-width row
   below the title. The key must stay the same.

Do not change colours, texts or behaviour. No new strings needed.

## Files to read

`AGENTS.md`, `QWEN.md` §4, `app/test/accessibility/accessibility_test.dart`,
`app/test/helpers/fakes.dart`, the four files in the table.

## Files to create/change

- `app/lib/core/widgets/calorie_arc.dart`
- `app/lib/features/stats/presentation/stats_screen.dart`
- `app/lib/features/activity/presentation/activity_screen.dart`
- `app/lib/features/settings/presentation/profile_screen.dart`
- Existing tests of these screens only if a test looked up a widget by its position in the
  `AppBar` or as `trailing` (keys stay, so normally no test change is needed).

## Acceptance

- `flutter test` fully green, including all three 200 % tests (de, ar, fr).
- `flutter analyze` green, doc-comment check green.
- No change to `app/test/accessibility/accessibility_test.dart`.
- Commit message for the fix: `fix(app): layouts fit with 200 % text (FIX-01)`.

---

## Review 1 (Claude, 31.10.2026) – 2 small changes, same branch

The four layout fixes are correct and match the ticket. Two follow-ups, both caused by the
ticket's own suggestions:

1. **Statistics: range switch disappears while loading and on error.** `statsProvider` watches
   `statsRangeProvider`, so tapping "4 weeks" reloads it and `stats.when` shows the spinner –
   the `SegmentedButton` is inside the data list and vanishes for that moment. On an error the
   user cannot switch back at all.
   Fix in `app/lib/features/stats/presentation/stats_screen.dart`: body becomes
   `Column(children: [Padding(EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0), <range button>),
   Expanded(child: stats.when(...))])`. Remove the button from `_StatsContent` again
   (and the `onRangeSelected` parameter). Key `stats-range` stays.
   Test (new, in `app/test/features/stats/stats_test.dart`): with a `FakeStatsRepository` that throws,
   `find.byKey(Key('stats-retry'))` and `find.byKey(Key('stats-range'))` are both found.
   If the fake cannot throw yet, add an optional `Object? error` to `FakeStatsRepository` in
   `app/test/helpers/fakes.dart`.
2. **Duplicate file:** `QWEN-UEBERGABE.md` in the repo root is identical to
   `docs/QWEN-UEBERGABE.md`. Delete the root copy (`git rm QWEN-UEBERGABE.md`).

Files to change: `stats_screen.dart`, `app/test/features/stats/stats_test.dart`, `app/test/helpers/fakes.dart`
(only if needed), `QWEN-UEBERGABE.md` (delete), this ticket file (commit it as it is).
Commit: `fix(app): range switch stays visible while statistics load (FIX-01)`.
The 200 % accessibility tests must stay green.

---

## Review 2 (Claude, 31.10.2026) – CI found 3 more failures, same branch

Review 1 (`97734aa`) is correct. GitHub CI on `3127948` showed three more failures that the
first overflows had hidden. Do NOT pull or rebase: the bot commit `8852d11` on GitHub is only
formatting and will be replaced by the upload (Ahmed uses `1b-hochladen-ueberschreiben.bat`).

1. **Tap target of the navigation dock is too small** (`androidTapTargetGuideline`):
   tab "Diary" is 65.5 × 42 px, minimum is 48 × 48.
   File `app/lib/core/widgets/nav_dock.dart`, function `tab()`: wrap the `Column` in
   `ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: ...)` and give the
   `Column` `mainAxisAlignment: MainAxisAlignment.center`. Keep `mainAxisSize: MainAxisSize.min`.
2. **Outdated test** `app/test/features/stats/stats_test.dart`, test
   "tabs switch between diary, statistics, activity and profile": it still expects the old
   placeholder key `activity-coming`, which was removed in T-52. Expect `activity-add`
   (the "Add sport" button) instead. My mistake from T-52, not yours.
3. **Large text, German only:** "A RenderFlex overflowed by 15 pixels on the right" in
   `all tabs fit on a small phone with 200 % text (de)`. French and Arabic pass. The CI message
   does not name the widget because the test swallows the error with `tester.takeException()`.
   In `app/test/accessibility/accessibility_test.dart`, in the 200 % test (the loop over de, ar, fr), delete the line
   `expect(tester.takeException(), isNull);`. Flutter then fails the test by itself and prints
   the full error including "The relevant error-causing widget was: … file:line". This is the
   only allowed change to that file. Do not guess a layout fix for this point; Claude will
   name the exact widget after the next CI run.
4. **Autofix workflow:** commit the new `.github/workflows/autofix.yml` exactly as it is in the
   folder (Claude wrote it; it now formats only after a merge to `main`).
5. **Commit author:** this repo now has `user.name "Ahmed"` and `user.email` set in
   `.git/config`. Commit with that identity. Do not set `--author`, `-c user.*` or
   `GIT_AUTHOR_*` yourself.

Files to change: `app/lib/core/widgets/nav_dock.dart`, `app/test/features/stats/stats_test.dart`,
`app/test/accessibility/accessibility_test.dart` (one line), `.github/workflows/autofix.yml`
(commit only), `AGENTS.md` (commit only, Claude updated §1), this ticket file (commit only).
Commit: `fix(app): nav dock tap targets, outdated test, clearer overflow report (FIX-01)`.

---

## Review 3 (Claude, 31.10.2026) – last failure, same branch

CI on `cc1407c`: 169 tests pass, 1 fails. Review 2 is correct (tap targets and the outdated
test are fixed). The failing test now names the widget:

`all tabs fit on a small phone with 200 % text (de)` – "A RenderFlex overflowed by 15 pixels
on the right", widget `Row` at `app/lib/features/activity/presentation/activity_screen.dart:97`
(icon + `stepsValue` text inside the `Wrap`). The card is 296 px wide; icon (24) + gap (4) +
"0 Schritte" at 200 % does not fit. German only, because "Schritte" is the longest word.

Fix: in that `Row`, wrap the steps `Text` (key `activity-steps`) in `Flexible(child: ...)` so it
can break onto a second line. Nothing else.

Files to change: `app/lib/features/activity/presentation/activity_screen.dart`, this ticket
file (commit only).
Commit: `fix(app): steps text wraps with large text (FIX-01)`.
Upload with the normal `1-github-hochladen.bat` (no bot commits any more).
