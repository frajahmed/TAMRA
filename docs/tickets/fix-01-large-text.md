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
