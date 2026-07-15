# Fase Motor: manual testing against real MacroFactor

FM-06/FM-07 wired the dynamic engine (EWMA trend weight → rolling-window TDEE → protein-first macros) into the app's actual live calorie goal (`GetKcalGoalUsecase`/`GetMacroGoalUsecase`, used by Home and Diary), replacing the static IOM 2005 formula whenever there's enough weight-log history. FM-11 added a damping layer and a gradual static→dynamic blend on top of that (see "Why the estimate is damped and blended in gradually" below) after a month-long manual simulation surfaced a much larger swing than MacroFactor documents for itself. This doc has two parts: how to exercise the live path manually in the app, and a concrete test scenario with exact expected numbers (computed via the app's own calc classes, not hand arithmetic) so you can cross-check against real MacroFactor.

## Why trend weight is the reliable cross-check, not the kcal number

`WeightTrendCalc`'s EWMA (alpha = 0.1) was reverse-engineered against real MacroFactor behavior (see `ykawanabe/mf-sync`), so **trend weight should match MacroFactor closely for identical input data**. The dynamic TDEE and final kcal goal are this app's own best-effort reproduction of MacroFactor's method — MacroFactor's internals aren't public, so those numbers are *plausible*, not *verified 1:1*. Treat trend weight as the strong signal and the kcal/macro numbers as "should be in the same neighborhood."

## Why the estimate is damped and blended in gradually

A month-long manual simulation (30 days, constant intake, steady real weight loss) showed the live goal climbing ~700 kcal (27%) over the month with the original implementation — a single fresh `TdeeDynamicCalc.estimateTdee()` read every time, snapping from 0% to 100% dynamic influence the instant trend history crossed 7 points. Checking that against MacroFactor's own published numbers ([algorithm-accuracy](https://macrofactor.com/algorithm-accuracy/), [help center](https://help.macrofactorapp.com/en/articles/26-how-should-i-interpret-changes-to-my-energy-expenditure)) showed their early-estimate error tops out around 590 kcal, and they document an *"additional intelligent smoothing layer...to avoid over-corrections if expenditure is fluctuating"* plus estimates *"gradually improving...for basically the entirety of the initial 30-day period"* rather than snapping.

Two changes in `TdeeDynamicCalc`/`GetKcalGoalUsecase` bring this closer to that documented behavior:

- **`TdeeDynamicCalc.estimateTdeeSmoothed`** — EWMA-smooths the day-by-day sequence of raw single-window TDEE reads (same alpha as trend weight, `0.1`), instead of the live goal reacting instantly to whatever the freshest read happens to be.
- **Gradual static→dynamic blend** — `GetKcalGoalUsecase` now linearly ramps from 0% dynamic at `TdeeDynamicCalc.minTrendPointsForDynamic` (7 trend points) to 100% dynamic at `TdeeDynamicCalc.fullyMatureTrendPoints` (21 points, matching the rolling window itself), instead of an instant switch. Strategy's estimator-status card shows this as a third **Calibrating** state (between *Insufficient data* and *Active*).

Neither MacroFactor's exact smoothing constant nor their blend-in curve is published — both remain best-effort approximations, same caveat as the rest of this engine.

### Empirical re-verification: re-running the same 30-day scenario after the fix

The scenario above wasn't hand-simulated — it was run live on a real Android emulator with the system clock genuinely advanced day by day (`adb shell date`), a fresh onboarding (Lose Weight, target 80 kg), 5 preseed days, then 30 live days each logging one weight entry (constant 0.15 kg/day loss) and 2300 kcal of food, with a checkpoint screenshot of Home + Strategy taken on a subset of days. The same script was re-run unmodified after the fix landed, for a direct before/after comparison.

**Before (original implementation, no damping/blend):** the goal snapped from the static formula straight to the pure dynamic estimate the instant trend history crossed the 7-point threshold — an abrupt single-call jump of roughly +470 kcal — then continued to climb over the month from ~2644 kcal to ~3363 kcal (**+719 kcal, +27%**), driven by a fresh unsmoothed `estimateTdee()` read on every call.

**After (`estimateTdeeSmoothed` + gradual blend):**

| Day | Goal (kcal) | Smoothed TDEE | Trend weight | Estimator state |
| --- | --- | --- | --- | --- |
| 1 | 2174 | 2608 | 84.7 kg | Calibrating (blend = 0%, exact) |
| 3 | 2215 | 2626 | 84.6 kg | Calibrating |
| 5 | 2265 | 2652 | 84.4 kg | Calibrating |
| 7 | 2326 | 2684 | 84.2 kg | Calibrating |
| 10 | 2441 | 2739 | 83.8 kg | Calibrating |
| 13 | 2585 | 2795 | 83.4 kg | Calibrating |
| 16 | 2731 | 2868 | 83.1 kg | **Active** (crossed 21 trend points) |
| 18 | 2802 | 2939 | 82.8 kg | Active |
| 20 | 2869 | 3005 | 82.5 kg | Active |
| 21 | 2902 | 3038 | 82.4 kg | Active |
| 22 | 2933 | 3069 | 82.2 kg | Active |
| 24 | 2994 | 3130 | 81.9 kg | Active |
| 27 | 3084 | 3219 | 81.5 kg | Active |
| 30 | 3166 | 3300 | 81.1 kg | Active |

What changed and what didn't:

- **The instant jump is gone.** At the exact point the old system snapped (7 trend points), the new blend weight is 0% by construction — day 1 above sits at the pure static goal (2174 kcal), not a discontinuous leap. The steepest day-to-day pace anywhere in the run is ~30–49 kcal/day (days 10–16, where both the blend ramp and the rising dynamic TDEE are moving together), never a single-call cliff.
- **The Calibrating → Active transition matches the design exactly.** It flips at day 16 of the live loop, which is trend point 22 (6 points from onboarding + preseed, +16 from the loop) — one past `fullyMatureTrendPoints` (21), as intended.
- **The total range over the month is still large (2174 → 3166 kcal, ~992 kcal)** — larger, in fact, than the old run's start-to-end delta. This is not a regression: the scenario is a deliberate stress test (relentless real weight loss on fixed intake for 30 straight days), so 30 days of real data legitimately keeps revealing that the user's true TDEE is higher than the static formula assumed. The fix changes the *path* (smooth vs. an instant snap), not the *destination* — which is the behavior MacroFactor itself documents (gradual correction over the initial 30-day window, not a capped total swing).
- The pre-fix run's exact day-by-day numbers weren't preserved as a table (only the start/end values above), since the checkpoint screenshots were overwritten by the post-fix re-run using the same filenames.

`flutter analyze`: 0 issues. `flutter test`: 822/822 passing, including the new `estimateTdeeSmoothed` and `dynamicBlendWeight` unit tests and a dedicated blend-ramp integration test in `dynamic_kcal_goal_wiring_test.dart`.

## How to test it live in the app

The dynamic path starts blending in once there are **at least 7 trend points** (`TdeeDynamicCalc.minTrendPointsForDynamic`) and is **fully blended in** at 21 (`TdeeDynamicCalc.fullyMatureTrendPoints`) — below 7, Home stays on the static IOM 2005 goal; between 7 and 21, expect the goal to keep drifting toward the dynamic estimate day by day (Strategy shows "Calibrating" during this window); at 21+, Home reflects the fully dynamic (smoothed) estimate.

1. **Backdate weight entries.** Profile → weight history → add entry → use the date picker to log one weight per day for the past several days (today included). You need real daily entries, not just today's — the trend/TDEE math needs a real series, and more days (up to 21) means less static blend-in.
2. **Log food for those same past days.** Diary → use the calendar to jump to each of those same days and log meals totaling roughly the same kcal each day (doesn't need to be exact, just present — the engine needs *some* logged intake overlapping the weight-log window to compute TDEE; see `TdeeDynamicCalc._intakeLookbackDays = 25`).
3. **Check Home and Strategy.** Once there are ≥7 overlapping trend points, Home's kcal number should start drifting from the static formula's output toward the dynamic one, and Strategy's estimator card should read "Calibrating." Keep adding days and watch it settle further; at 21+ real trend points it reads "Active" and Home reflects the fully dynamic number.
4. **Optional — set a target weight.** Profile → goal weight, at least 0.7 kg away from your current trend weight (the `DynamicMaintenanceCalc` maintenance band). This switches the correction from the flat weight-loss-goal offset to the goal-weight-distance correction described below.
5. **Optional — the "adaptive check-in" you described from MacroFactor** (tightens budget if losing too slowly, loosens if too fast) isn't separate logic here — it falls out for free from recomputing TDEE fresh over the rolling window on every call, now smoothed rather than read raw. Keep logging a few more days at a fixed kcal target and watch the number adjust itself as the window slides.

## Test scenario: exact expected values

All numbers below came from actually running the app's `WeightInterpolationCalc` → `WeightTrendCalc` → `TdeeDynamicCalc` → `DynamicMaintenanceCalc` → `MacroDynamicCalc` chain (via a throwaway `flutter test`, not hand math), anchored to **today = 2026-07-15**. If you run this on a different day, shift every date below by the same offset — the values themselves won't change since they only depend on relative day-spacing.

This scenario deliberately seeds only **10 trend points** — inside the "Calibrating" blend window (7–21), not fully mature — because that's the case most worth cross-checking precisely: it's where the static formula and the dynamic estimate visibly disagree and blend, rather than one flatly winning.

### Profile inputs

The static formula (the other half of the blend at 10 trend points) needs the full profile, not just height/weight — unlike the pre-FM-11 scenario where only the fully-dynamic number mattered.

| Field | Value |
| --- | --- |
| Birthday | 1990-01-01 |
| Gender | Male |
| Height | 178 cm |
| Activity level | Low Active |
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

Enter the same 10 data points into MacroFactor and its trend line should track this closely, day by day — this part is unaffected by FM-11's changes, since only the expenditure layer was damped, not the trend weight itself:

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

### Expected smoothed dynamic TDEE and blend weight

- **Smoothed dynamic TDEE: 3554.73 kcal/day** — `TdeeDynamicCalc.estimateTdeeSmoothed`'s output: the EWMA-smoothed sequence of raw single-window reads across all 10 days, not a single fresh computation on the last day alone. This is the number to compare against MacroFactor's own TDEE/expenditure estimate for the same input — expect it to be in the same ballpark, not necessarily identical.
- **Blend weight: 21.4%** (`(10 − 7) / (21 − 7)`) — with only 10 real trend points, Strategy reads "Calibrating," and the live goal below is still mostly the static formula.

### Expected final kcal goal, by scenario

Each is `static + blendWeight × (dynamic − static)`, so the number sits between the two, not equal to either.

| Scenario | Goal setting | Static component | Dynamic component | Blended goal (live) |
| --- | --- | --- | --- | --- |
| A — Maintain | Goal = "Maintain weight" | 2745.36 | 3554.73 (smoothed TDEE, passed straight through) | **2918.79** |
| B — Lose, no target weight | Goal = "Lose weight", no target weight set | 2245.36 | 3054.73 (smoothed TDEE − 500, the "bridge" until a target is set) | **2418.79** |
| C — Lose, target weight = 78 kg | Goal = "Lose weight", target weight 78.0 kg | 2245.36 | 3414.56 (`DynamicMaintenanceCalc`, correcting from the 84.77 kg trend toward the 78 kg goal — outside the 0.7 kg band) | **2495.90** |

Log a few more days (toward 21 total) and re-check — the blended goal should keep drifting toward the dynamic component as the blend weight climbs toward 100%.

### Expected macros

Protein-first split (`MacroDynamicCalc`): 1.8 g/kg base + 0.1 g/kg weight-loss bonus when the goal is "Lose weight", fat floor `((height_cm − 150) × 0.5) + 30`, remainder split 50/50 fat/carb — computed from each scenario's **blended** kcal goal above, matching what `GetMacroGoalUsecase` actually feeds it.

| Scenario | Protein | Fat | Carb |
| --- | --- | --- | --- |
| A — Maintain (2918.79 kcal, no loss bonus) | 151.2 g | 128.6 g | 289.2 g |
| B — Lose, no target (2418.79 kcal) | 159.6 g | 98.9 g | 222.5 g |
| C — Lose, target 78 kg (2495.90 kcal) | 159.6 g | 103.2 g | 232.2 g |

Note macros read `user.weightKG` from your **profile**, not the latest weigh-in or trend weight — keep the profile weight field roughly in sync with your actual weight (e.g. update it to 84 kg alongside the weight log above) or the protein/fat targets will be off.

## Caveat

The trend-weight table is the part worth trusting as a precise cross-check — it's a direct reimplementation of a reverse-engineered MacroFactor algorithm. The TDEE, blend, and kcal-goal numbers are this app's own interpretation of MacroFactor's documented *behavior* (rolling-window energy balance, an extra smoothing layer, a gradual calibration ramp, ±0.7 kg maintenance band, 0.15%/week correction) — MacroFactor's actual smoothing constants and blend curve are undocumented/proprietary, so these are best-effort approximations, not verified 1:1. If MacroFactor's number differs by a few hundred kcal, that's expected, not necessarily a bug here.
