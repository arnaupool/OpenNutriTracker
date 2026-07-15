# Fase Motor: manual testing against real MacroFactor

FM-06/FM-07 wired the dynamic engine (EWMA trend weight → rolling-window TDEE → protein-first macros) into the app's actual live calorie goal (`GetKcalGoalUsecase`/`GetMacroGoalUsecase`, used by Home and Diary), replacing the static IOM 2005 formula whenever there's enough weight-log history. This doc has two parts: how to exercise that path manually in the app, and a concrete test scenario with exact expected numbers (computed via the app's own calc classes, not hand arithmetic) so you can cross-check against real MacroFactor.

## Why trend weight is the reliable cross-check, not the kcal number

`WeightTrendCalc`'s EWMA (alpha = 0.1) was reverse-engineered against real MacroFactor behavior (see `ykawanabe/mf-sync`), so **trend weight should match MacroFactor closely for identical input data**. The dynamic TDEE and final kcal goal are this app's own best-effort reproduction of MacroFactor's method — MacroFactor's internals aren't public, so those numbers are *plausible*, not *verified 1:1*. Treat trend weight as the strong signal and the kcal/macro numbers as "should be in the same neighborhood."

## How to test it live in the app

The dynamic path only activates once there are **at least 7 trend points** (`GetKcalGoalUsecase._minTrendPointsForDynamic`) — with fewer, Home silently falls back to the static IOM 2005 goal, which looks like nothing happened rather than an error.

1. **Backdate weight entries.** Profile → weight history → add entry → use the date picker to log one weight per day for the past 10 days (today included). You need real daily entries, not just today's — the trend/TDEE math needs a real series.
2. **Log food for those same past days.** Diary → use the calendar to jump to each of those same 10 days and log meals totaling roughly the same kcal each day (doesn't need to be exact, just present — the engine needs *some* logged intake overlapping the weight-log window to compute TDEE; see `TdeeDynamicCalc._intakeLookbackDays = 25`).
3. **Check Home.** Once both series exist for ≥7 overlapping trend points, Home's kcal number should shift from the static formula's output to the dynamic one. If your weight logs show a real trend (not flat), the number will differ noticeably from before.
4. **Optional — set a target weight.** Profile → goal weight, at least 0.7 kg away from your current trend weight (the `DynamicMaintenanceCalc` maintenance band). This switches the correction from the flat weight-loss-goal offset to the goal-weight-distance correction described below.
5. **Optional — the "adaptive check-in" you described from MacroFactor** (tightens budget if losing too slowly, loosens if too fast) isn't separate logic here — it falls out for free from recomputing TDEE fresh over the rolling window on every call. Keep logging a few more days at a fixed kcal target and watch the number adjust itself as the window slides.

## Test scenario: exact expected values

All numbers below came from actually running the app's `WeightInterpolationCalc` → `WeightTrendCalc` → `TdeeDynamicCalc` → `DynamicMaintenanceCalc` → `MacroDynamicCalc` chain (via a throwaway `flutter test`, not hand math), anchored to **today = 2026-07-15**. If you run this on a different day, shift every date below by the same offset — the values themselves won't change since they only depend on relative day-spacing.

### Profile inputs

| Field | Value |
| --- | --- |
| Height | 178 cm |
| Target weight (Scenario C only) | 78.0 kg |
| Protein target | 1.8 g/kg (this app's default) |

### Weight log to enter (10 days, step change)

| Date | Weight (kg) |
| --- | --- |
| 2026-07-06 | 86.0 |
| 2026-07-07 | 84.0 |
| 2026-07-08 | 84.0 |
| 2026-07-09 | 84.0 |
| 2026-07-10 | 84.0 |
| 2026-07-11 | 84.0 |
| 2026-07-12 | 84.0 |
| 2026-07-13 | 84.0 |
| 2026-07-14 | 84.0 |
| 2026-07-15 | 84.0 |

### Diary intake to log

**2200 kcal every day**, 2026-07-06 through 2026-07-15 (macro split within that 2200 doesn't matter — only the kcal total feeds the engine).

### Expected trend weight (compare directly against MacroFactor)

Enter the same 10 data points into MacroFactor and its trend line should track this closely, day by day:

| Date | Raw | Trend weight |
| --- | --- | --- |
| 2026-07-06 | 86.0 | 86.0000 |
| 2026-07-07 | 84.0 | 85.8000 |
| 2026-07-08 | 84.0 | 85.6200 |
| 2026-07-09 | 84.0 | 85.4580 |
| 2026-07-10 | 84.0 | 85.3122 |
| 2026-07-11 | 84.0 | 85.1810 |
| 2026-07-12 | 84.0 | 85.0629 |
| 2026-07-13 | 84.0 | 84.9566 |
| 2026-07-14 | 84.0 | 84.8609 |
| 2026-07-15 | 84.0 | **84.7748** |

### Expected dynamic TDEE

**3250.39 kcal/day** — this is this app's estimate of true maintenance, computed from the rolling window: you ate 2200 kcal/day flat while your trend weight fell from 85.80 → 84.77 kg (a 9-day-old first trend point to today), implying a real deficit that only a higher true TDEE explains. This is the number to compare against MacroFactor's own TDEE/expenditure estimate for the same input — expect it to be in the same ballpark, not necessarily identical.

### Expected final kcal goal, by scenario

| Scenario | Goal setting | Expected kcal goal | Why |
| --- | --- | --- | --- |
| A — Maintain | Goal = "Maintain weight" | **3250.39** | Dynamic TDEE passed straight through, no adjustment. |
| B — Lose, no target weight | Goal = "Lose weight", no target weight set | **2750.39** | Falls back to the flat weekly-rate-based adjustment on top of dynamic TDEE (TDEE − 500, this app's default lose-weight offset) — the "bridge" path used until you set a real target. |
| C — Lose, target weight = 78 kg | Goal = "Lose weight", target weight 78.0 kg | **3110.22** | Trend weight (84.77 kg) is more than the 0.7 kg maintenance band away from the 78 kg goal, so `DynamicMaintenanceCalc` applies a correction below raw TDEE, pulling toward goal — this is the "Option B" auto-correction model instead of a manually picked rate. |

### Expected macros

Protein-first split (`MacroDynamicCalc`): 1.8 g/kg base + 0.1 g/kg weight-loss bonus when the goal is "Lose weight", fat floor `((height_cm − 150) × 0.5) + 30`, remainder split 50/50 fat/carb.

| Scenario | Protein | Fat | Carb |
| --- | --- | --- | --- |
| A — Maintain (3250.39 kcal, no loss bonus) | 151.2 g | 147.0 g | 330.7 g |
| B — Lose, no target (2750.39 kcal) | 159.6 g | 117.3 g | 264.0 g |
| C — Lose, target 78 kg (3110.22 kcal) | 159.6 g | 137.3 g | 309.0 g |

Note macros read `user.weightKG` from your **profile**, not the latest weigh-in or trend weight — keep the profile weight field roughly in sync with your actual weight (e.g. update it to 84 kg alongside the weight log above) or the protein/fat targets will be off.

## Caveat

The trend-weight table is the part worth trusting as a precise cross-check — it's a direct reimplementation of a reverse-engineered MacroFactor algorithm. The TDEE and kcal-goal numbers are this app's own interpretation of MacroFactor's method (rolling-window energy balance, ±0.7 kg maintenance band, 0.15 %/week correction) and haven't been verified against MacroFactor's actual (undocumented, closed-source) internals — if MacroFactor's number differs by a few hundred kcal, that's expected, not necessarily a bug here.
