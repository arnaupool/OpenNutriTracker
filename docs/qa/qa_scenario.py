"""QA scenario generator and independent reference model for the dynamic engine.

Usage:  python -I docs/qa/qa_scenario.py OUT_ZIP END_DATE(YYYY-MM-DD) [DAYS] [TRUE_TDEE] [INTAKE] [START_KG] [EMIT_FROM]

EMIT_FROM (YYYY-MM-DD) limits the zip to days on or after it, to extend an
already-imported history; the printed reference always covers all DAYS.

Writes an import zip (Settings > Import) with DAYS days of clean history ending
on END_DATE: one weigh-in and one quick-add intake per day. Weight follows the
energy balance of TRUE_TDEE vs INTAKE (7716.17 kcal/kg, the 3500 kcal/lb rule)
plus a fixed +-0.4 kg noise pattern, so the "right answer" for expenditure is
known. Then prints what the documented algorithm should show, computed here
from the written-down rules (AUDIT.md / code comments), not by calling Dart.
"""
import json
import sys
import uuid
import zipfile
from datetime import date, timedelta

KCAL_PER_KG = 3500 * 2.20462
ALPHA = 0.1
WINDOW = 21
LOOKBACK = 25
NOISE = [0.3, -0.2, 0.4, -0.4, 0.1, 0.0, -0.3, 0.2, -0.1, 0.4, -0.2, 0.1, -0.4, 0.3]


def history(end, days, true_tdee, intake, start_kg):
    first = end - timedelta(days=days - 1)
    daily_loss = (true_tdee - intake) / KCAL_PER_KG
    weights = {first + timedelta(days=i): round(start_kg - daily_loss * i + NOISE[i % len(NOISE)], 1)
               for i in range(days)}
    intakes = {first + timedelta(days=i): float(intake) for i in range(days)}
    return weights, intakes


def trend_of(weights):
    days = sorted(weights)
    series = []
    for a, b in zip(days, days[1:]):
        gap = (b - a).days
        for k in range(gap):
            series.append((a + timedelta(days=k), weights[a] + (weights[b] - weights[a]) * k / gap))
    series.append((days[-1], weights[days[-1]]))
    out, t = [], None
    for d, w in series:
        t = w if t is None else t + ALPHA * (w - t)
        out.append((d, t))
    return out


def raw_tdee(trend, intake):
    if len(trend) < 2:
        return None
    win = trend[-WINDOW:] if len(trend) > WINDOW else trend
    span = (win[-1][0] - win[0][0]).days
    if span == 0:
        return None
    stored = (win[-1][1] - win[0][1]) * KCAL_PER_KG / span
    vals = [intake[d] for d, _ in win if d in intake]
    if not vals:
        return None
    return sum(vals) / len(vals) - stored


def smoothed_tdee(trend, intake):
    s = None
    for i in range(1, len(trend) + 1):
        r = raw_tdee(trend[:i], intake)
        if r is None:
            continue
        s = r if s is None else s + ALPHA * (r - s)
    return s


def main():
    out_zip = sys.argv[1]
    end = date.fromisoformat(sys.argv[2])
    days = int(sys.argv[3]) if len(sys.argv) > 3 else 35
    true_tdee = float(sys.argv[4]) if len(sys.argv) > 4 else 3000
    intake_kcal = float(sys.argv[5]) if len(sys.argv) > 5 else 2400
    start_kg = float(sys.argv[6]) if len(sys.argv) > 6 else 90.0

    emit_from = date.fromisoformat(sys.argv[7]) if len(sys.argv) > 7 else None
    weights, intakes = history(end, days, true_tdee, intake_kcal, start_kg)
    emit = (lambda d: True) if emit_from is None else (lambda d: d >= emit_from)
    meal = lambda kcal: {
        "code": None, "name": "QA scenario day", "brands": None, "thumbnailImageUrl": None,
        "mainImageUrl": None, "url": None, "mealQuantity": "100", "mealUnit": "g",
        "servingQuantity": None, "servingUnit": None, "servingSize": None, "source": "custom",
        "nutriments": {"energyKcal100": kcal, "carbohydrates100": kcal * 0.5 / 4,
                       "fat100": kcal * 0.25 / 9, "proteins100": kcal * 0.25 / 4,
                       "sugars100": None, "saturatedFat100": None, "fiber100": None},
    }
    intake_json = [{"id": str(uuid.uuid4()), "unit": "g", "amount": 100.0, "type": "lunch",
                    "meal": meal(k), "dateTime": f"{d.isoformat()}T12:00:00.000"} for d, k in intakes.items() if emit(d)]
    tracked_json = [{"day": f"{d.isoformat()}T00:00:00.000", "calorieGoal": 2500.0, "caloriesTracked": k,
                     "carbsTracked": k * 0.5 / 4, "fatTracked": k * 0.25 / 9, "proteinTracked": k * 0.25 / 4}
                    for d, k in intakes.items() if emit(d)]
    weight_json = [{"date": f"{d.isoformat()}T00:00:00.000", "weightKg": w, "note": None} for d, w in weights.items() if emit(d)]
    with zipfile.ZipFile(out_zip, "w") as z:
        z.writestr("user_activity.json", "[]")
        z.writestr("user_intake.json", json.dumps(intake_json))
        z.writestr("user_tracked_day.json", json.dumps(tracked_json))
        z.writestr("weight_log.json", json.dumps(weight_json))

    trend = trend_of(weights)
    lookback = {d: k for d, k in intakes.items() if (end - d).days <= LOOKBACK}
    tdee = smoothed_tdee(trend, lookback)
    n = len(trend)
    blend = min(1.0, max(0.0, (n - 7) / (21 - 7)))
    rate_kcal = 0.005 * trend[-1][1] * KCAL_PER_KG / 7
    print(f"days={days} end={end} true_tdee={true_tdee:.0f} intake={intake_kcal:.0f}")
    print(f"last_weigh_in={weights[end]} trend_weight={trend[-1][1]:.2f} trend_points={n} blend={blend:.3f}")
    print(f"smoothed_tdee={tdee:.1f} (error vs true {tdee - true_tdee:+.1f} kcal)")
    print(f"raw_tdee_today={raw_tdee(trend, lookback):.1f}")
    print(f"rate_0.5pct_kcal={rate_kcal:.1f} -> dynamic lose goal={tdee - rate_kcal:.1f}")
    if len(trend) >= 20:
        print(f"weekly_change_kg={(trend[-1][1] - trend[-20][1]) / 19 * 7:.3f} (window 20 points)")


if __name__ == "__main__":
    main()
