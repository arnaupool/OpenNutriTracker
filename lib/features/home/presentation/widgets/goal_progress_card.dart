import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/goal_explanation.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/utils/calc/dynamic_maintenance_calc.dart';
import 'package:opennutritracker/core/utils/calc/tdee_dynamic_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_interpolation_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_trend_calc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Compact Home rendition of `StrategyPage`'s own goal-correction
/// explanation (distance to target weight + current correction rate) —
/// same [DynamicMaintenanceCalc]/[CalorieGoalCalc] logic, no new
/// calculation, just a smaller surface.
class GoalProgressCard extends StatefulWidget {
  final GetWeightLogUsecase? getWeightLogUsecase;
  final GetUserUsecase? getUserUsecase;
  final GetTrackedDayUsecase? getTrackedDayUsecase;

  const GoalProgressCard({
    super.key,
    this.getWeightLogUsecase,
    this.getUserUsecase,
    this.getTrackedDayUsecase,
  });

  @override
  State<GoalProgressCard> createState() => _GoalProgressCardState();
}

class _GoalProgressCardState extends State<GoalProgressCard> {
  late final GetWeightLogUsecase _weightUsecase =
      widget.getWeightLogUsecase ?? locator<GetWeightLogUsecase>();
  late final GetUserUsecase _userUsecase =
      widget.getUserUsecase ?? locator<GetUserUsecase>();
  late final GetTrackedDayUsecase _trackedDayUsecase =
      widget.getTrackedDayUsecase ?? locator<GetTrackedDayUsecase>();

  bool _loading = true;
  String? _explanation;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _weightUsecase.getAllEntries();
    final user = await _userUsecase.getUserData();
    final filled = WeightInterpolationCalc.fillGaps(entries);
    final trend = WeightTrendCalc.computeTrend(filled);

    final today = DateTime.now();
    final todayAtMidnight = DateTime(today.year, today.month, today.day);
    // From the first trend day on, matching GetKcalGoalUsecase's
    // carried-forward estimate (FM-13).
    final lookbackStart = trend.isEmpty ? todayAtMidnight : trend.first.date;
    final endOfToday = todayAtMidnight
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    final trackedDays = await _trackedDayUsecase.getTrackedDaysByRange(
      lookbackStart,
      endOfToday,
    );
    final dailyIntakeKcal = {
      for (final d in trackedDays)
        DateTime(d.day.year, d.day.month, d.day.day): d.caloriesTracked,
    };

    final estimate = TdeeDynamicCalc.estimateTdeeCarriedForward(
      trendSeries: trend,
      dailyIntakeKcal: dailyIntakeKcal,
      today: today,
    );
    final isActive =
        estimate != null &&
        estimate.trend.length >= TdeeDynamicCalc.minTrendPointsForDynamic;

    if (!mounted) return;
    setState(() {
      _explanation = isActive
          ? _buildExplanation(context, user, trend.last.trendWeightKg)
          : null;
      _loading = false;
    });
  }

  /// Mirrors `StrategyPage._buildExplanation` exactly — same
  /// [DynamicMaintenanceCalc]/[CalorieGoalCalc] calls, same l10n strings.
  String? _buildExplanation(
    BuildContext context,
    UserEntity user,
    double trendWeightKg,
  ) => goalExplanation(S.of(context), user, trendWeightKg);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final s = S.of(context);
    final theme = Theme.of(context);
    final explanation = _explanation;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.homeGoalProgressCardTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Semantics(
              identifier: 'home-goal-progress-value',
              child: Text(
                explanation ?? s.homeGoalProgressInsufficientData,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
