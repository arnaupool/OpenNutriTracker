import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/presentation/goal_explanation.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/utils/calc/macro_dynamic_calc.dart';
import 'package:opennutritracker/core/utils/calc/tdee_calc.dart';
import 'package:opennutritracker/core/utils/calc/tdee_dynamic_calc.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_interpolation_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_trend_calc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';

enum _ChartRange {
  oneMonth(30),
  threeMonths(90),
  sixMonths(180),
  oneYear(365),
  allTime(null);

  /// Null means "no fixed window" — the chart derives its start date from
  /// the earliest logged entry instead (see `_WeightChart`).
  final int? days;
  const _ChartRange(this.days);
}

/// Mirrors [TdeeDynamicCalc.dynamicBlendWeight]'s three phases:
/// [insufficient] (below the noise floor, static only), [calibrating]
/// (blending, matching MacroFactor's own documented "gradually
/// improving" estimates over the first weeks rather than a hard
/// static→dynamic snap), and [active] (fully mature, no more blend-in
/// left).
/// [paused] (FM-13): the estimate is held at its last value because
/// fewer than 4 of the last 7 days have food logged.
enum _EstimatorState { insufficient, calibrating, active, paused }

/// Fase Motor's real dashboard (FD-01, reworked by FM-09): now that
/// [GetKcalGoalUsecase]/[GetMacroGoalUsecase] actually govern the app's
/// live goal (FM-06/FM-07), this page explains *why* today's number is
/// what it is — trend weight vs. scale weight, the estimator's status,
/// the observed TDEE, and (when a target weight is set) distance to goal
/// and the correction being applied — rather than a static-vs-dynamic
/// comparison that's now redundant.
class StrategyPage extends StatefulWidget {
  final GetWeightLogUsecase? getWeightLogUsecase;
  final GetUserUsecase? getUserUsecase;
  final GetTrackedDayUsecase? getTrackedDayUsecase;
  final ConfigRepository? configRepository;
  final GetKcalGoalUsecase? getKcalGoalUsecase;
  final GetMacroGoalUsecase? getMacroGoalUsecase;

  const StrategyPage({
    super.key,
    this.getWeightLogUsecase,
    this.getUserUsecase,
    this.getTrackedDayUsecase,
    this.configRepository,
    this.getKcalGoalUsecase,
    this.getMacroGoalUsecase,
  });

  @override
  State<StrategyPage> createState() => _StrategyPageState();
}

class _StrategyPageState extends State<StrategyPage> {

  late final GetWeightLogUsecase _weightUsecase =
      widget.getWeightLogUsecase ?? locator<GetWeightLogUsecase>();
  late final GetUserUsecase _userUsecase =
      widget.getUserUsecase ?? locator<GetUserUsecase>();
  late final GetTrackedDayUsecase _trackedDayUsecase =
      widget.getTrackedDayUsecase ?? locator<GetTrackedDayUsecase>();
  late final ConfigRepository _configRepository =
      widget.configRepository ?? locator<ConfigRepository>();
  late final GetKcalGoalUsecase _kcalGoalUsecase =
      widget.getKcalGoalUsecase ?? locator<GetKcalGoalUsecase>();
  late final GetMacroGoalUsecase _macroGoalUsecase =
      widget.getMacroGoalUsecase ?? locator<GetMacroGoalUsecase>();

  bool _loading = true;
  bool _usesImperialUnits = false;
  List<WeightLogEntity> _weightEntries = const [];
  UserEntity? _user;
  Map<DateTime, double> _dailyIntakeKcal = const {};
  _ChartRange _range = _ChartRange.oneMonth;

  double? _todayTargetKcal;
  double? _proteinG;
  double? _fatG;
  double? _carbG;

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
    // From the first weigh-in on, so the carried-forward estimate (FM-13)
    // can still reach back to the last well-logged week after a long gap.
    final lookbackStart = entries.isEmpty
        ? todayAtMidnight
        : DateTime(
            entries.first.date.year,
            entries.first.date.month,
            entries.first.date.day,
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

    // The literal live number Home/Diary show today, not a page-local
    // recomputation — this is what "Today's Target" and the macro
    // distribution actually feed off, so this page never drifts out of
    // sync with what's actually governing the app.
    final todayTargetKcal = await _kcalGoalUsecase.getKcalGoal(
      userEntity: user,
    );
    final proteinG = await _macroGoalUsecase.getProteinsGoal(todayTargetKcal);
    final fatG = await _macroGoalUsecase.getFatsGoal(todayTargetKcal);
    final carbG = await _macroGoalUsecase.getCarbsGoal(todayTargetKcal);

    if (!mounted) return;
    setState(() {
      _usesImperialUnits = config.usesImperialUnits;
      _weightEntries = entries;
      _user = user;
      _dailyIntakeKcal = intakeMap;
      _todayTargetKcal = todayTargetKcal;
      _proteinG = proteinG;
      _fatG = fatG;
      _carbG = carbG;
      _loading = false;
    });
  }

  /// Mirrors the branches [GetKcalGoalUsecase._computeDynamicCoreGoal]
  /// takes once the dynamic estimator is active, translated into a
  /// sentence explaining which one applied. Returns null when the
  /// estimator isn't active yet — [_EstimatorStatusCard] already covers
  /// that case, so there's nothing to add here.
  String? _buildExplanation(
    BuildContext context,
    UserEntity user,
    double trendWeightKg,
  ) => goalExplanation(S.of(context), user, trendWeightKg);

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

    final estimate = TdeeDynamicCalc.estimateTdeeCarriedForward(
      trendSeries: trend,
      dailyIntakeKcal: _dailyIntakeKcal,
      today: DateTime.now(),
    );
    final tdeeDynamic = estimate?.tdee;
    final tdeeStatic = _user != null
        ? TDEECalc.getTDEEKcalIOM2005(_user!)
        : null;
    final trendWeightKg = trend.last.trendWeightKg;
    // Mirrors GetKcalGoalUsecase._computeCoreGoal's own gating exactly —
    // trend.length >= minTrendPointsForDynamic, not just "estimateTdee
    // returned a number" (which only needs 2 points) — so this card never
    // claims the estimator is live before it's actually influencing
    // today's real goal, and "calibrating" reflects the same gradual
    // blend Home is applying, not a separate approximation of it.
    final isActive =
        estimate != null &&
        estimate.trend.length >= TdeeDynamicCalc.minTrendPointsForDynamic;
    final blendWeight = isActive
        ? TdeeDynamicCalc.dynamicBlendWeight(estimate.trend.length)
        : 0.0;
    final estimatorState = !isActive
        ? _EstimatorState.insufficient
        : estimate.isPaused
        ? _EstimatorState.paused
        : blendWeight >= 1.0
        ? _EstimatorState.active
        : _EstimatorState.calibrating;
    final displayTdee = tdeeDynamic ?? tdeeStatic;
    final explanation = isActive && _user != null
        ? _buildExplanation(context, _user!, trendWeightKg)
        : null;

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
        _EstimatorStatusCard(state: estimatorState),
        const SizedBox(height: 16),
        _TodayGoalCard(
          targetKcal: _todayTargetKcal,
          estimatedTdeeKcal: displayTdee,
          trendWeightKg: trendWeightKg,
          explanation: explanation,
          usesImperialUnits: _usesImperialUnits,
        ),
        const SizedBox(height: 16),
        _MacroDistributionCard(proteinG: _proteinG, fatG: _fatG, carbG: _carbG),
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
      case _ChartRange.oneYear:
        return s.strategyRangeOneYear;
      case _ChartRange.allTime:
        return s.strategyRangeAllTime;
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
  final int? rangeDays;
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
    // A null rangeDays means "all time" — start at the earliest point we
    // actually have instead of a fixed lookback, so a five-year weigh-in
    // history isn't truncated by a hardcoded window.
    final fixedRangeDays = rangeDays;
    final DateTime windowStart;
    if (fixedRangeDays != null) {
      windowStart = todayAtMidnight.subtract(Duration(days: fixedRangeDays));
    } else {
      final allDates = [
        ...scaleEntries.where((p) => !p.isInterpolated).map((p) => p.date),
        ...trend.map((p) => p.date),
      ];
      windowStart = allDates.isEmpty
          ? todayAtMidnight
          : allDates.reduce((a, b) => a.isBefore(b) ? a : b);
    }
    final effectiveRangeDays =
        fixedRangeDays ??
        todayAtMidnight
            .difference(windowStart)
            .inDays
            .clamp(1, 1 << 30)
            .toInt();

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
    // Beyond ~13 months a bare "Jan 5" label is ambiguous across years, so
    // switch to a month+year label once the visible span crosses that.
    final dateFormat = effectiveRangeDays > 400
        ? DateFormat.yMMM(localeTag)
        : DateFormat.MMMd(localeTag);
    final labelInterval = (effectiveRangeDays / 4).ceilToDouble();

    return Semantics(
      identifier: 'strategy-weight-chart',
      child: SizedBox(
        height: _chartHeight,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: effectiveRangeDays.toDouble(),
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
  final _EstimatorState state;

  const _EstimatorStatusCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);

    final Color dotColor;
    final String label;
    final String description;
    switch (state) {
      case _EstimatorState.insufficient:
        dotColor = theme.colorScheme.outline;
        label = s.strategyEstimatorStatusInsufficientLabel;
        description = s.strategyEstimatorStatusInsufficientDescription;
      case _EstimatorState.calibrating:
        dotColor = theme.colorScheme.tertiary;
        label = s.strategyEstimatorStatusCalibratingLabel;
        description = s.strategyEstimatorStatusCalibratingDescription;
      case _EstimatorState.active:
        dotColor = theme.colorScheme.primary;
        label = s.strategyEstimatorStatusActiveLabel;
        description = s.strategyEstimatorStatusActiveDescription;
      case _EstimatorState.paused:
        dotColor = theme.colorScheme.secondary;
        label = s.strategyEstimatorStatusPausedLabel;
        description = s.strategyEstimatorStatusPausedDescription;
    }

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
                    Text(label, style: theme.textTheme.titleMedium),
                    Text(
                      description,
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

class _TodayGoalCard extends StatelessWidget {
  final double? targetKcal;
  final double? estimatedTdeeKcal;
  final double? trendWeightKg;
  final String? explanation;
  final bool usesImperialUnits;

  const _TodayGoalCard({
    required this.targetKcal,
    required this.estimatedTdeeKcal,
    required this.trendWeightKg,
    required this.explanation,
    required this.usesImperialUnits,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final weightUnit = usesImperialUnits ? s.lbsLabel : s.kgLabel;
    final displayTrendWeight = trendWeightKg == null
        ? null
        : (usesImperialUnits
              ? UnitCalc.kgToLbs(trendWeightKg!)
              : trendWeightKg!);

    return Semantics(
      identifier: 'strategy-today-goal',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.strategyTodayTargetLabel,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                targetKcal == null
                    ? '—'
                    : '${targetKcal!.round()} ${s.kcalLabel}',
                style: theme.textTheme.headlineMedium,
              ),
              if (explanation != null) ...[
                const SizedBox(height: 8),
                Text(
                  explanation!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.local_fire_department_outlined,
                      label: s.strategyEstimatedTdeeLabel,
                      value: estimatedTdeeKcal == null
                          ? '—'
                          : '${estimatedTdeeKcal!.round()} ${s.kcalLabel}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.trending_down_outlined,
                      label: s.strategyTrendWeightLabel,
                      value: displayTrendWeight == null
                          ? '—'
                          : '${displayTrendWeight.toStringAsFixed(1)} $weightUnit',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

/// The MacroFactor-style "distribution of calories by macronutrient" bar
/// chart FM-09 was asked to bring in: today's real target (matching
/// [_TodayGoalCard]) broken into protein/fat/carb, each bar's height
/// proportional to the kcal it contributes rather than its gram count, so
/// fat (9 kcal/g) doesn't visually shrink next to carbs and protein (4
/// kcal/g each) at equal gram amounts.
class _MacroDistributionCard extends StatelessWidget {
  final double? proteinG;
  final double? fatG;
  final double? carbG;

  const _MacroDistributionCard({
    required this.proteinG,
    required this.fatG,
    required this.carbG,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);

    final protein = proteinG;
    final fat = fatG;
    final carb = carbG;
    if (protein == null || fat == null || carb == null) {
      return const SizedBox.shrink();
    }

    final proteinKcal = protein * MacroDynamicCalc.kcalPerGramProtein;
    final fatKcal = fat * MacroDynamicCalc.kcalPerGramFat;
    final carbKcal = carb * MacroDynamicCalc.kcalPerGramCarb;
    final maxKcal = [
      proteinKcal,
      fatKcal,
      carbKcal,
    ].reduce((a, b) => a > b ? a : b);

    return Semantics(
      identifier: 'strategy-macro-distribution',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.strategyMacroDistributionTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _MacroBar(
                      label: s.proteinLabel,
                      grams: protein,
                      kcal: proteinKcal,
                      maxKcal: maxKcal,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MacroBar(
                      label: s.fatLabel,
                      grams: fat,
                      kcal: fatKcal,
                      maxKcal: maxKcal,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MacroBar(
                      label: s.carbsLabel,
                      grams: carb,
                      kcal: carbKcal,
                      maxKcal: maxKcal,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  static const double _maxBarHeight = 120;
  static const double _minBarHeight = 8;

  final String label;
  final double grams;
  final double kcal;
  final double maxKcal;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.grams,
    required this.kcal,
    required this.maxKcal,
    required this.color,
  });

  // The shared nutrient labels (proteinLabel, fatLabel, carbsLabel) are
  // lowercase because most of their other call sites read them inline
  // mid-sentence ("106 / 316 g carbs"); this chart's own label reads
  // better title-cased.
  static String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barHeight = maxKcal <= 0
        ? _minBarHeight
        : ((kcal / maxKcal) * _maxBarHeight).clamp(
            _minBarHeight,
            _maxBarHeight,
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${grams.round()}g', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 4),
        Text(_capitalize(label), style: theme.textTheme.labelSmall),
      ],
    );
  }
}
