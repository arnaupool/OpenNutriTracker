import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
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
  // Buffer above TdeeDynamicCalc's default 21-day window, matching
  // StrategyPage's own reasoning: a full window is available even if
  // today hasn't been tracked yet.
  static const int _intakeLookbackDays = 25;

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
    final lookbackStart = todayAtMidnight.subtract(
      const Duration(days: _intakeLookbackDays),
    );
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

    final hasEnoughTrend =
        trend.length >= TdeeDynamicCalc.minTrendPointsForDynamic;
    final tdeeDynamic = hasEnoughTrend
        ? TdeeDynamicCalc.estimateTdeeSmoothed(
            trendSeries: trend,
            dailyIntakeKcal: dailyIntakeKcal,
          )
        : null;
    final isActive = hasEnoughTrend && tdeeDynamic != null;

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
  ) {
    final s = S.of(context);
    if (user.goal == UserWeightGoalEntity.maintainWeight) {
      return s.strategyExplanationMaintaining;
    }

    final targetWeightKg = user.targetWeightKg;
    if (targetWeightKg == null) {
      final baseAdjustment = CalorieGoalCalc.getKcalGoalAdjustment(
        user.goal,
        weeklyWeightGoalKg: user.weeklyWeightGoalKg,
      );
      final sign = baseAdjustment > 0 ? '+' : '';
      return s.strategyExplanationNoTargetWeight(
        '$sign${baseAdjustment.round()}',
      );
    }

    final diffKg = trendWeightKg - targetWeightKg;
    if (diffKg.abs() <= DynamicMaintenanceCalc.maintenanceBandKg) {
      return s.strategyExplanationWithinBand;
    }

    final correctionKcalPerDay =
        (DynamicMaintenanceCalc.correctionRatePerWeek *
            trendWeightKg *
            DynamicMaintenanceCalc.kcalPerKgBodyMass) /
        7;
    return s.strategyExplanationCorrecting(
      diffKg.abs().toStringAsFixed(1),
      correctionKcalPerDay.round().toString(),
    );
  }

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
