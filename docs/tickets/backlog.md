# Backlog (phase 2–3)

Not scheduled yet. Each item becomes a ticket in a sprint file when it is planned.

## T-60: AI photo scan of a meal [Claude]
- User takes a photo; the server detects the foods, estimates the grams and shows a confirmation
  sheet (items, grams, kcal, macros) with one "log meal" button. Every item can be corrected or
  replaced by a search result before logging.
- Detection: vision model through the API (provider in the EU or with an EU data processing
  agreement); results are mapped to foods in our database (search API), so nutrients come from
  Open Food Facts / TAMRA data, not from the model.
- Privacy: separate opt-in consent ("photo analysis"), the photo is processed and deleted right
  away (not stored, not used for training), never sent to analytics or Sentry.
- Honesty: estimates are labelled as estimates; no medical claims.
- Limits: free version a few scans per day, PRO more (cost per scan).
- Rate limit scope `photo_scan` on the API.

## T-61: Fasting timer
Interval fasting plans (16:8, 18:6, 5:2), timer in the diary arc (switch budget ↔ fasting),
reminders. Free in TAMRA.

## T-62: Recipes, diet filters and shopping list
Recipes with nutrients per portion, filters (vegan, vegetarian, high protein, low carb, keto,
halal), add a recipe to the diary, shopping list from planned meals.

## T-63: Streaks and badges
Days in a row with at least one entry, badges for consistency (7, 30, 100 days); never rewards
for eating less or for very low calories.

## T-64: Direct cloud connections
Strava, Garmin Health API, Fitbit Web API, Polar AccessLink (see sprint 5).
