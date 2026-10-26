# TAMRA – Design system and screen plan

Source: design concept "Health & Fitness App Design Concept" (Ahmed, 26.10.2026) adapted to TAMRA.
Code: colour tokens in `app/lib/app/theme.dart` (`AppColors`, `AppTheme`). Every screen uses these
tokens, never raw colour values.

## Principles
1. **Frictionless logging** – barcode now, AI photo scan later, quick add (+) on every meal.
2. **Positive, never punishing** – rings and bars fill up; going over the target is shown in the
   normal colour with a neutral text, never red alarm colours or shaming words.
3. **Clean cards** – white/charcoal cards, radius 20, thin border; soft shadow only in light mode.
4. **Light and dark mode** – the app follows the phone setting; both use the same tokens.
5. **Right-to-left** – every layout works mirrored for Arabic (`EdgeInsetsDirectional`, `start`/`end`).
6. **The formula is visible** – calorie numbers always show how they are made (`target + sport – eaten`).

## Colour tokens (`AppColors`)
| Token | Light | Dark | Used for |
| --- | --- | --- | --- |
| background | #F4F6F9 | #0F1117 | page behind the cards |
| surface | #FFFFFF | #1A1D26 | cards, sheets, navigation dock |
| border | #E5E7EB | #2D313E | card border, dividers |
| textPrimary | #111827 | #F9FAFB | main text |
| textSecondary | #6B7280 | #9CA3AF | labels, hints |
| **brand** (date brown) | #7A4B2A | #C08A5B | primary buttons, logo, selected tab |
| **progress** (blue) | #2563EB | #3B82F6 | calorie arc, charts, goal lines |
| carbs | #F97316 | #FB923C | carbohydrates everywhere |
| fat | #84CC16 | #A3E635 | fat everywhere |
| protein | #3B82F6 | #60A5FA | protein everywhere |

Decision 26.10.2026: brown stays the brand colour (identity, buttons), blue is the progress colour.
Dark mode: no pure black for cards, borders instead of heavy shadows, slightly brighter accents.
Contrast: text tokens meet WCAG AA on background and surface (checked in T-44).

## Components (build once in `app/lib/core/widgets/`, reuse everywhere)
| Component | Description | First used in |
| --- | --- | --- |
| `DateStrip` | week strip M–S, today marked, swipe to the previous/next week | T-31 |
| `CalorieArc` | arc gauge: eaten vs. budget, "remaining" in the centre, formula below; switch to fasting status later | T-31, T-54 |
| `MacroBar` | thin bar per macro with grams and percent of the target | T-31 |
| `MealCard` | breakfast/lunch/dinner/snack with kcal and a quick-add (+) button | T-31 |
| `WaterCard` | glasses of 250 ml, tap adds, long-press removes | T-41 |
| `NavDock` | floating bottom navigation (rounded, slightly translucent) with a centre scan button | T-41 |
| `StatCard` | small card with label, value and trend (e.g. current vs. target weight) | T-42 |
| `TrendChart` | line/bar chart with week/month/year switch | T-42, T-54 |

## Navigation (floating dock)
`Diary` · `Statistics` · **(centre) Scan** · `Activity` · `Profile`

The centre button opens a sheet: barcode scan (now), AI photo scan (phase 2), quick add, search.

## Screens
| Tab | Content | Tickets |
| --- | --- | --- |
| Diary (home) | greeting, `DateStrip`, `CalorieArc` (budget, later fasting), `MacroBar`s, `WaterCard`, four `MealCard`s | T-31, T-41, T-54 |
| Scan (centre) | barcode scanner; later AI photo scan with detected items and a confirmation sheet | T-24 done, T-60 |
| Statistics | weight target vs. current (`StatCard`s), kcal bars vs. budget, macro breakdown, 7 days / 4 weeks / 12 months | T-42, T-54 |
| Activity | sync status badges (Apple Health, Health Connect, Garmin, …), today's workouts, active kcal chart | T-52, T-53 |
| Profile | goals, units, language, connected apps, data export, delete account | T-43 |

## Later (phase 2–3)
- **AI photo scan (T-60 [Claude])** – see `docs/tickets/backlog.md`.
- **Fasting timer** in the hero arc (toggle budget ↔ fasting).
- **Recipes with diet filters** (vegan, high protein, low carb, keto) and a shopping list.
- **Streaks and badges** – rewards for consistency (days logged), never for eating less.
- **Motion** – small animation when a ring is completed; respects "reduce motion".

## Prototype
Screens are designed in Figma with variables for both themes, using the tokens above.
Inspiration: YAZIO, Lifesum, Cal AI flows (Mobbin), "AI meal tracker UI" (Dribbble).
