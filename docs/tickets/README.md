# Tickets

Work strictly in this order. One ticket = one branch = one pull request.
Tickets marked **[Claude]** are done by Claude, not by Qwen.

| Sprint | Ticket | Title | Area | Status |
| --- | --- | --- | --- | --- |
| 0 | – | Foundation (repo, API, app, CI) | all | done (Claude) |
| 1 | T-10 | Register endpoint | api | done (Claude) |
| 1 | T-11 | Profile endpoint and calorie target | api | done (Claude) |
| 1 | T-12 | Consents (health data) | api | done (Claude) |
| 1 | T-13 | App: login, register, token handling | app | done (Claude) |
| 1 | T-14 | App: consent and onboarding | app | done (Claude) |
| 2 | T-20 | Food model | api | done (Claude, reviewed Qwen draft) |
| 2 | T-21 | Open Food Facts mapping and import | api | done (Claude, reviewed Qwen draft) |
| 2 | T-22 | Food search, barcode lookup, custom food | api | done (Claude, reviewed Qwen draft) |
| 2 | T-23 | App: food search | app | done (Claude) |
| 2 | T-24 | App: barcode scanner | app | done (Claude) |
| 3 | T-30 | Diary entries and day summary | api | done (Claude) |
| 3 | T-31 | App: diary screen and add entry | app | done (Claude) |
| 3 | T-32 | Copy meal or day | api + app | done (Claude) |
| 3 | T-33 | Offline storage and sync **[Claude]** | api + app | open |
| 4 | T-40 | Weight and water logs | api | done (Qwen, reviewed and fixed by Claude) |
| 4 | T-41 | App: weight and water | app | done (Claude) |
| 4 | T-42 | Statistics (7 days) | api + app | done (Claude) |
| 4 | T-43 | Settings, data export, delete account | api + app | done (Claude) |
| 4 | T-44 | Accessibility, RTL and store texts **[Claude]** | app | open |
| 5 | T-50 | Activity model, CRUD and import | api | open |
| 5 | T-51 | Calorie balance and history | api | open |
| 5 | T-52 | App: activities and manual sport entry | app | open |
| 5 | T-53 | App: connect Apple Health and Health Connect **[Claude]** | app | open |
| 5 | T-54 | App: balance dashboard and history | app | open |

Design system and screen plan: `docs/DESIGN.md`. Ideas for later: `docs/tickets/backlog.md`
(AI photo scan T-60, fasting T-61, recipes T-62, streaks T-63, cloud connections T-64).

Later (phase 3): direct Strava, Garmin, Fitbit and Polar connections (server-side).
Later (phase 2): fasting, reminders, recipes, subscription (RevenueCat),
Apple/Google sign-in, Sentry in the app, store release pipeline,
two-factor login, leaked-password check (see docs/SECURITY.md).
Dropped: diabetes mode (decision 2026-10-25).
