import 'package:opennutritracker/features/diet_plan/data/diet_plan_dbo.dart';

typedef WeightPoint = ({DateTime date, double weightKg});

/// Pure date and progress maths for [DietPlanDBO]. All dates are calendar
/// days in local time: differences go through UTC midnights so a DST change
/// never makes a day 23 or 25 hours long.
class DietPlanCalc {
  /// Kilograms to lose, as the onboarding and plan screens offer them.
  static const double minLossKg = 0.5;
  static const double maxLossKg = 50;
  static const double lossStepKg = 0.5;

  /// Offered paces in kg per week.
  static const List<double> paceOptions = [0.25, 0.5, 0.75];
  static const double defaultPaceKgPerWeek = 0.5;

  /// Days without a lower 7-day average after which a plan counts as stalled.
  static const int stallDays = 21;
  static const int averageWindowDays = 7;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  /// Whole calendar days from [from] to [to] (negative when [to] is earlier).
  static int daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  /// Days needed to lose [kg] at [paceKgPerWeek]: ceil(kg / pace * 7). The
  /// tiny epsilon keeps float noise (4.5 / 0.75 * 7 = 42.00000000000001)
  /// from adding a day.
  static int durationDays(double kg, double paceKgPerWeek) {
    if (kg <= 0 || paceKgPerWeek <= 0) return 0;
    return (kg / paceKgPerWeek * 7 - 1e-9).ceil();
  }

  /// End date of an automatic plan, before pauses.
  static DateTime autoEnd(DateTime start, double kg, double paceKgPerWeek) =>
      addDays(start, durationDays(kg, paceKgPerWeek));

  /// Days the plan has spent paused up to [today] (an open pause counts
  /// until today).
  static int pausedDays(List<DietPlanPause> pauses, DateTime today) {
    var total = 0;
    for (final p in pauses) {
      final days = daysBetween(p.from, p.to ?? today);
      if (days > 0) total += days;
    }
    return total;
  }

  /// The end date including paused days: pausing for 7 days moves it 7 days
  /// later.
  static DateTime effectiveEnd(DietPlanDBO plan, DateTime today) =>
      addDays(plan.endDate, pausedDays(plan.pauses, today));

  /// Calendar days from [today] to the effective end (0 on the last day,
  /// negative once it has passed).
  static int daysLeft(DietPlanDBO plan, DateTime today) => daysBetween(today, effectiveEnd(plan, today));

  /// Days the plan lasts when never paused.
  static int totalDays(DietPlanDBO plan) => daysBetween(plan.startDate, plan.endDate);

  /// Share of the plan's active days already elapsed, 0..1.
  static double progress(DietPlanDBO plan, DateTime today) {
    final total = totalDays(plan);
    if (total <= 0) return 1;
    final elapsed = daysBetween(plan.startDate, today) - pausedDays(plan.pauses, today);
    return (elapsed / total).clamp(0.0, 1.0);
  }

  static bool isPaused(DietPlanDBO plan) =>
      plan.status == DietPlanStatus.paused || (plan.pauses.isNotEmpty && plan.pauses.last.to == null);

  /// Finished: marked so, or [today] is past the effective end.
  static bool isFinished(DietPlanDBO plan, DateTime today) =>
      plan.status == DietPlanStatus.finished || (!isPaused(plan) && daysLeft(plan, today) < 0);

  static DietPlanStatus statusAt(DietPlanDBO plan, DateTime today) {
    if (plan.status == DietPlanStatus.finished) return DietPlanStatus.finished;
    if (isPaused(plan)) return DietPlanStatus.paused;
    return daysLeft(plan, today) < 0 ? DietPlanStatus.finished : DietPlanStatus.active;
  }

  /// Opens a pause today. No-op when already paused or finished.
  static DietPlanDBO pause(DietPlanDBO plan, DateTime today) {
    if (isPaused(plan) || plan.status == DietPlanStatus.finished) return plan;
    return plan.copyWith(
      status: DietPlanStatus.paused,
      pauses: [
        ...plan.pauses,
        DietPlanPause(from: dateOnly(today)),
      ],
    );
  }

  /// Closes the open pause today. No-op when not paused.
  static DietPlanDBO resume(DietPlanDBO plan, DateTime today) {
    if (!isPaused(plan)) return plan;
    final pauses = [...plan.pauses];
    if (pauses.isNotEmpty && pauses.last.to == null) {
      pauses[pauses.length - 1] = pauses.last.copyWith(to: dateOnly(today));
    }
    return plan.copyWith(status: DietPlanStatus.active, pauses: pauses);
  }

  /// [plan] with the end date recomputed from kg and pace when it is
  /// automatic; manual plans are returned unchanged.
  static DietPlanDBO recomputeAuto(DietPlanDBO plan) {
    final kg = plan.targetLossKg;
    final pace = plan.paceKgPerWeek;
    if (plan.mode != DietPlanMode.auto || kg == null || pace == null) return plan;
    return plan.copyWith(endDate: autoEnd(plan.startDate, kg, pace));
  }

  /// [plan] changed so its effective end (pauses included) is [end].
  static DietPlanDBO withEffectiveEnd(DietPlanDBO plan, DateTime end, DateTime today) =>
      plan.copyWith(endDate: addDays(dateOnly(end), -pausedDays(plan.pauses, today)));

  /// Mean of the weigh-ins in the [days] days ending on [endDay] (inclusive),
  /// or null when there are none.
  static double? windowAverage(Iterable<WeightPoint> points, DateTime endDay, {int days = averageWindowDays}) {
    final end = dateOnly(endDay);
    final start = addDays(end, -(days - 1));
    var sum = 0.0;
    var count = 0;
    for (final p in points) {
      final d = dateOnly(p.date);
      if (d.isBefore(start) || d.isAfter(end)) continue;
      sum += p.weightKg;
      count++;
    }
    return count == 0 ? null : sum / count;
  }

  /// The 7-day average reached the loss the plan aims for.
  static bool goalReached(DietPlanDBO plan, double? weekAverageKg) {
    final loss = plan.targetLossKg;
    if (loss == null || weekAverageKg == null) return false;
    return weekAverageKg <= plan.startWeightKg - loss + 1e-9;
  }

  /// Kilograms lost so far by the 7-day average (negative when heavier).
  static double? lostKg(DietPlanDBO plan, double? weekAverageKg) =>
      weekAverageKg == null ? null : plan.startWeightKg - weekAverageKg;

  /// Stalled: the plan is at least [stallDays] old and the 7-day average is
  /// not lower than the one from [stallDays] days ago.
  static bool isStalled(DietPlanDBO plan, DateTime today, Iterable<WeightPoint> points) {
    if (daysBetween(plan.startDate, today) < stallDays) return false;
    final now = windowAverage(points, today);
    final before = windowAverage(points, addDays(today, -stallDays));
    if (now == null || before == null) return false;
    return now >= before;
  }
}
