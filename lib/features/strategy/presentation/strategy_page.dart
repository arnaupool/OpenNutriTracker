import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/utils/calc/tdee_calc.dart';
import 'package:opennutritracker/core/utils/calc/tdee_dynamic_calc.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_interpolation_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_trend_calc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/profile/presentation/widgets/set_weekly_weight_goal_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';

enum _ChartRange {
  oneMonth(30),
  threeMonths(90),
  sixMonths(180);

  final int days;
  const _ChartRange(this.days);
}

/// Fase Motor's real dashboard (FD-01): scale weight vs. trend weight,
/// dynamic (Fase Motor) vs. static (IOM 2005) TDEE side by side, and the
/// desired vs. observed weekly rate — the same comparison MacroFactor's
/// own Expenditure screen and XMihura's reference build show.
///
/// This is a read-only surface: it computes and displays what Fase Motor's
/// engine outputs alongside what the app's existing static engine already
/// produces (today's tracked-day calorie goal). It does not yet replace
/// that goal-setting flow — swapping the app's *actual* daily target over
/// to the dynamic engine is a separate integration decision, out of scope
/// here.
class StrategyPage extends StatefulWidget {
  final GetWeightLogUsecase? getWeightLogUsecase;
  final GetUserUsecase? getUserUsecase;
  final GetTrackedDayUsecase? getTrackedDayUsecase;
  final ConfigRepository? configRepository;
  final AddUserUsecase? addUserUsecase;

  const StrategyPage({
    super.key,
    this.getWeightLogUsecase,
    this.getUserUsecase,
    this.getTrackedDayUsecase,
    this.configRepository,
    this.addUserUsecase,
  });

  @override
  State<StrategyPage> createState() => _StrategyPageState();
}

class _StrategyPageState extends State<StrategyPage> {
  // Buffer above TdeeDynamicCalc's default 21-day window so a full window
  // is available even if today hasn't been tracked yet.
  static const int _intakeLookbackDays = 25;

  late final GetWeightLogUsecase _weightUsecase =
      widget.getWeightLogUsecase ?? locator<GetWeightLogUsecase>();
  late final GetUserUsecase _userUsecase =
      widget.getUserUsecase ?? locator<GetUserUsecase>();
  late final GetTrackedDayUsecase _trackedDayUsecase =
      widget.getTrackedDayUsecase ?? locator<GetTrackedDayUsecase>();
  late final ConfigRepository _configRepository =
      widget.configRepository ?? locator<ConfigRepository>();
  late final AddUserUsecase _addUserUsecase =
      widget.addUserUsecase ?? locator<AddUserUsecase>();

  bool _loading = true;
  bool _usesImperialUnits = false;
  List<WeightLogEntity> _weightEntries = const [];
  UserEntity? _user;
  Map<DateTime, double> _dailyIntakeKcal = const {};
  _ChartRange _range = _ChartRange.oneMonth;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await _configRepository.getConfig();
    final entries = await _weightUsecase.getAllEntries()
      ..sort((a, b) => a.date.compareTo(b.date));
    final user = await _userUsecase.getUserData();

    final today = DateTime.now();
    final todayAtMidnight = DateTime(today.year, today.month, today.day);
    final lookbackStart = todayAtMidnight.subtract(
      const Duration(days: _intakeLookbackDays),
    );
    // TrackedDayDBO.day isn't always normalized to midnight, so bounding
    // the range at exactly today's midnight would silently drop today's
    // entry whenever it carries a real time-of-day component. Push the
    // upper bound to the last instant of today instead.
    final endOfToday = todayAtMidnight
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    final trackedDays = await _trackedDayUsecase.getTrackedDaysByRange(
      lookbackStart,
      endOfToday,
    );
    final intakeMap = {
      for (final d in trackedDays)
        DateTime(d.day.year, d.day.month, d.day.day): d.caloriesTracked,
    };

    TrackedDayEntity? todayTracked;
    for (final d in trackedDays) {
      final day = DateTime(d.day.year, d.day.month, d.day.day);
      if (day == todayAtMidnight) {
        todayTracked = d;
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _usesImperialUnits = config.usesImperialUnits;
      _weightEntries = entries;
      _user = user;
      _dailyIntakeKcal = intakeMap;
      _todayTracked = todayTracked;
      _loading = false;
    });
  }

  TrackedDayEntity? _todayTracked;

  Future<void> _showSetWeeklyWeightGoalDialog() async {
    final user = _user;
    if (user == null) return;
    final result = await showDialog<WeeklyWeightGoalResult>(
      context: context,
      builder: (context) => SetWeeklyWeightGoalDialog(
        currentGoalKg: user.weeklyWeightGoalKg,
        usesImperialUnits: _usesImperialUnits,
      ),
    );
    switch (result) {
      case null:
      case WeeklyWeightGoalCancelled():
        return;
      case WeeklyWeightGoalCleared():
        user.weeklyWeightGoalKg = null;
      case WeeklyWeightGoalSet(:final kgPerWeek):
        user.weeklyWeightGoalKg = kgPerWeek;
    }
    await _addUserUsecase.addUser(user);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filled = WeightInterpolationCalc.fillGaps(_weightEntries);
    final trend = WeightTrendCalc.computeTrend(filled);

    if (trend.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            S.of(context).strategyEmptyState,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final tdeeDynamic = TdeeDynamicCalc.estimateTdee(
      trendSeries: trend,
      dailyIntakeKcal: _dailyIntakeKcal,
    );
    final observedWeeklyRateKg = TdeeDynamicCalc.weeklyChangeRateKg(trend);
    final tdeeStatic = _user != null
        ? TDEECalc.getTDEEKcalIOM2005(_user!)
        : null;
    final trendWeightKg = trend.last.trendWeightKg;
    final desiredWeeklyRateKg = _user?.weeklyWeightGoalKg;
    final isActive = tdeeDynamic != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _RangeChips(
          selected: _range,
          onSelected: (r) => setState(() => _range = r),
        ),
        const SizedBox(height: 12),
        _WeightChart(
          trend: trend,
          scaleEntries: filled,
          rangeDays: _range.days,
          usesImperialUnits: _usesImperialUnits,
        ),
        const SizedBox(height: 20),
        _EstimatorStatusCard(isActive: isActive),
        const SizedBox(height: 16),
        _MetricsGrid(
          estimatedTdeeKcal: tdeeDynamic,
          staticTdeeKcal: tdeeStatic,
          currentTargetKcal: _todayTracked?.calorieGoal,
          trendWeightKg: trendWeightKg,
          usesImperialUnits: _usesImperialUnits,
        ),
        const SizedBox(height: 16),
        _WeeklyRateCard(
          desiredKgPerWeek: desiredWeeklyRateKg,
          observedKgPerWeek: observedWeeklyRateKg,
          referenceWeightKg: trendWeightKg,
          usesImperialUnits: _usesImperialUnits,
          onEditDesired: _showSetWeeklyWeightGoalDialog,
        ),
      ],
    );
  }
}

class _RangeChips extends StatelessWidget {
  final _ChartRange selected;
  final ValueChanged<_ChartRange> onSelected;

  const _RangeChips({required this.selected, required this.onSelected});

  String _label(BuildContext context, _ChartRange range) {
    final s = S.of(context);
    switch (range) {
      case _ChartRange.oneMonth:
        return s.strategyRangeOneMonth;
      case _ChartRange.threeMonths:
        return s.strategyRangeThreeMonths;
      case _ChartRange.sixMonths:
        return s.strategyRangeSixMonths;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'strategy-range-chips',
      child: Wrap(
        spacing: 8,
        children: [
          for (final range in _ChartRange.values)
            ChoiceChip(
              label: Text(_label(context, range)),
              selected: selected == range,
              onSelected: (_) => onSelected(range),
            ),
        ],
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  static const double _chartHeight = 200;

  final List<WeightTrendPoint> trend;
  final List<InterpolatedWeightPoint> scaleEntries;
  final int rangeDays;
  final bool usesImperialUnits;

  const _WeightChart({
    required this.trend,
    required this.scaleEntries,
    required this.rangeDays,
    required this.usesImperialUnits,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trendColor = theme.colorScheme.primary;
    final scaleColor = theme.colorScheme.onSurfaceVariant;

    final today = DateTime.now();
    final todayAtMidnight = DateTime(today.year, today.month, today.day);
    final windowStart = todayAtMidnight.subtract(Duration(days: rangeDays));

    double displayWeight(double kg) =>
        usesImperialUnits ? UnitCalc.kgToLbs(kg) : kg;

    final scaleSpots = <FlSpot>[
      for (final p in scaleEntries)
        if (!p.isInterpolated &&
            !p.date.isBefore(windowStart) &&
            !p.date.isAfter(todayAtMidnight))
          FlSpot(
            p.date.difference(windowStart).inDays.toDouble(),
            displayWeight(p.weightKg),
          ),
    ];
    final trendSpots = <FlSpot>[
      for (final p in trend)
        if (!p.date.isBefore(windowStart) && !p.date.isAfter(todayAtMidnight))
          FlSpot(
            p.date.difference(windowStart).inDays.toDouble(),
            displayWeight(p.trendWeightKg),
          ),
    ];

    if (trendSpots.length < 2) {
      return const SizedBox.shrink();
    }

    final allY = [...scaleSpots.map((s) => s.y), ...trendSpots.map((s) => s.y)];
    final minY = allY.reduce((a, b) => a < b ? a : b);
    final maxY = allY.reduce((a, b) => a > b ? a : b);
    final yPadding = ((maxY - minY) * 0.15).clamp(0.5, 5.0);

    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.MMMd(localeTag);
    final labelInterval = (rangeDays / 4).ceilToDouble();

    return Semantics(
      identifier: 'strategy-weight-chart',
      child: SizedBox(
        height: _chartHeight,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: rangeDays.toDouble(),
            minY: minY - yPadding,
            maxY: maxY + yPadding,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => Text(
                    value.toStringAsFixed(0),
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: labelInterval,
                  getTitlesWidget: (value, meta) {
                    final day = windowStart.add(Duration(days: value.toInt()));
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        dateFormat.format(day),
                        style: theme.textTheme.labelSmall,
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: scaleSpots,
                isCurved: false,
                color: Colors.transparent,
                barWidth: 0,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                        radius: 2.5,
                        color: scaleColor,
                        strokeWidth: 0,
                      ),
                ),
              ),
              LineChartBarData(
                spots: trendSpots,
                isCurved: true,
                preventCurveOverShooting: true,
                color: trendColor,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstimatorStatusCard extends StatelessWidget {
  final bool isActive;

  const _EstimatorStatusCard({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final dotColor = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;

    return Semantics(
      identifier: 'strategy-estimator-status',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive
                          ? s.strategyEstimatorStatusActiveLabel
                          : s.strategyEstimatorStatusInsufficientLabel,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      isActive
                          ? s.strategyEstimatorStatusActiveDescription
                          : s.strategyEstimatorStatusInsufficientDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final double? estimatedTdeeKcal;
  final double? staticTdeeKcal;
  final double? currentTargetKcal;
  final double? trendWeightKg;
  final bool usesImperialUnits;

  const _MetricsGrid({
    required this.estimatedTdeeKcal,
    required this.staticTdeeKcal,
    required this.currentTargetKcal,
    required this.trendWeightKg,
    required this.usesImperialUnits,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final weightUnit = usesImperialUnits ? s.lbsLabel : s.kgLabel;
    final displayTrendWeight = trendWeightKg == null
        ? null
        : (usesImperialUnits
              ? UnitCalc.kgToLbs(trendWeightKg!)
              : trendWeightKg!);

    return Semantics(
      identifier: 'strategy-metrics-grid',
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.7,
        children: [
          _MetricTile(
            icon: Icons.local_fire_department_outlined,
            label: s.strategyEstimatedTdeeLabel,
            value: estimatedTdeeKcal == null
                ? '—'
                : '${estimatedTdeeKcal!.round()} ${s.kcalLabel}',
          ),
          _MetricTile(
            icon: Icons.flag_outlined,
            label: s.strategyCurrentTargetLabel,
            value: currentTargetKcal == null
                ? '—'
                : '${currentTargetKcal!.round()} ${s.kcalLabel}',
          ),
          _MetricTile(
            icon: Icons.trending_down_outlined,
            label: s.strategyTrendWeightLabel,
            value: displayTrendWeight == null
                ? '—'
                : '${displayTrendWeight.toStringAsFixed(1)} $weightUnit',
          ),
          _MetricTile(
            icon: Icons.calculate_outlined,
            label: s.strategyStaticTdeeLabel,
            value: staticTdeeKcal == null
                ? '—'
                : '${staticTdeeKcal!.round()} ${s.kcalLabel}',
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleLarge),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyRateCard extends StatelessWidget {
  final double? desiredKgPerWeek;
  final double? observedKgPerWeek;
  final double? referenceWeightKg;
  final bool usesImperialUnits;
  final VoidCallback onEditDesired;

  const _WeeklyRateCard({
    required this.desiredKgPerWeek,
    required this.observedKgPerWeek,
    required this.referenceWeightKg,
    required this.usesImperialUnits,
    required this.onEditDesired,
  });

  String? _formatRate(double? kgPerWeek, BuildContext context) {
    if (kgPerWeek == null) return null;
    final s = S.of(context);
    final unit = usesImperialUnits ? s.lbsLabel : s.kgLabel;
    final displayValue = usesImperialUnits
        ? UnitCalc.kgToLbs(kgPerWeek)
        : kgPerWeek;
    final pctPart = referenceWeightKg == null || referenceWeightKg == 0
        ? ''
        : ' (${((kgPerWeek / referenceWeightKg!) * 100).toStringAsFixed(2)}%/wk)';
    final sign = displayValue > 0 ? '+' : '';
    return '$sign${displayValue.toStringAsFixed(2)} $unit/wk$pctPart';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final desiredText = _formatRate(desiredKgPerWeek, context) ?? '—';
    final observedText = _formatRate(observedKgPerWeek, context) ?? '—';

    return Semantics(
      identifier: 'strategy-weekly-rate',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.strategyWeeklyRateTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Semantics(
                identifier: 'strategy-weekly-rate-edit',
                child: InkWell(
                  onTap: onEditDesired,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.strategyDesiredRateLabel,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(desiredText, style: theme.textTheme.bodyMedium),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.strategyObservedRateLabel,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(observedText, style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
