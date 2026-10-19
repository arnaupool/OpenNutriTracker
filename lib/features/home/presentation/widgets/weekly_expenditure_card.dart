import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/utils/calc/tdee_dynamic_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_interpolation_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_trend_calc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/core/utils/calc/calendar_day_calc.dart';

/// A MacroFactor-style "last 7 days" summary: the dynamic expenditure
/// estimate over a short window, and the resulting energy balance against
/// what was actually eaten over the same window. Purely informational —
/// the live calorie goal itself still comes from GetKcalGoalUsecase's own
/// (21-day-windowed, statically-blended) estimate; this card surfaces the
/// more reactive, week-focused picture MacroFactor's own dashboard shows
/// alongside its stable goal number.
///
/// Fetches its own data directly (mirroring StrategyPage's precedent for
/// this kind of calc-heavy display) rather than routing through HomeBloc,
/// since HomeBloc's LoadItemsEvent doesn't otherwise need weight-log or
/// tracked-day-range access for anything else it computes.
class WeeklyExpenditureCard extends StatefulWidget {
  final GetWeightLogUsecase? getWeightLogUsecase;
  final GetTrackedDayUsecase? getTrackedDayUsecase;

  const WeeklyExpenditureCard({
    super.key,
    this.getWeightLogUsecase,
    this.getTrackedDayUsecase,
  });

  @override
  State<WeeklyExpenditureCard> createState() => _WeeklyExpenditureCardState();
}

class _WeeklyExpenditureCardState extends State<WeeklyExpenditureCard> {
  static const int _windowDays = 7;
  // Buffer above _windowDays so a full week of real intake is available
  // even if today hasn't been tracked yet — same reasoning as
  // GetKcalGoalUsecase/StrategyPage's own lookback buffer, just sized to
  // this card's shorter window instead of TdeeDynamicCalc.defaultWindowDays.
  static const int _lookbackDays = 10;

  late final GetWeightLogUsecase _weightUsecase =
      widget.getWeightLogUsecase ?? locator<GetWeightLogUsecase>();
  late final GetTrackedDayUsecase _trackedDayUsecase =
      widget.getTrackedDayUsecase ?? locator<GetTrackedDayUsecase>();

  bool _loading = true;
  double? _expenditureKcal;
  double? _energyBalanceKcal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _weightUsecase.getAllEntries();
    final filled = WeightInterpolationCalc.fillGaps(entries);
    final trend = WeightTrendCalc.computeTrend(filled);

    final today = DateTime.now();
    final todayAtMidnight = DateTime(today.year, today.month, today.day);
    final lookbackStart = CalendarDayCalc.addDays(
      todayAtMidnight,
      -_lookbackDays,
    );
    // TrackedDayDBO.day isn't always normalized to midnight (see
    // StrategyPage._load) — push the upper bound to the last instant of
    // today so a real time-of-day component on today's entry isn't
    // silently dropped.
    final endOfToday = CalendarDayCalc.addDays(
      todayAtMidnight,
      1,
    ).subtract(const Duration(milliseconds: 1));
    final trackedDays = await _trackedDayUsecase.getTrackedDaysByRange(
      lookbackStart,
      endOfToday,
    );
    final dailyIntakeKcal = {
      for (final d in trackedDays)
        DateTime(d.day.year, d.day.month, d.day.day): d.caloriesTracked,
    };

    // Matches Strategy's own floor for when the dynamic estimate is trusted
    // at all — below it, a raw estimate exists but is too noisy to show as
    // a real number, so this card stays in its "not enough data" state
    // instead of showing something Strategy itself wouldn't yet.
    final hasEnoughTrend =
        trend.length >= TdeeDynamicCalc.minTrendPointsForDynamic;
    final expenditure = hasEnoughTrend
        ? TdeeDynamicCalc.estimateTdeeSmoothed(
            trendSeries: trend,
            dailyIntakeKcal: dailyIntakeKcal,
            windowDays: _windowDays,
          )
        : null;

    double? energyBalance;
    if (expenditure != null) {
      final windowStart = CalendarDayCalc.addDays(
        todayAtMidnight,
        -(_windowDays - 1),
      );
      final recentIntakes = dailyIntakeKcal.entries
          .where(
            (e) =>
                !e.key.isBefore(windowStart) && !e.key.isAfter(todayAtMidnight),
          )
          .map((e) => e.value)
          .toList();
      if (recentIntakes.isNotEmpty) {
        final avgIntake =
            recentIntakes.reduce((a, b) => a + b) / recentIntakes.length;
        energyBalance = avgIntake - expenditure;
      }
    }

    if (!mounted) return;
    setState(() {
      _expenditureKcal = expenditure;
      _energyBalanceKcal = energyBalance;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final s = S.of(context);
    final expenditure = _expenditureKcal;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.homeExpenditureCardTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (expenditure == null)
              Text(
                s.homeExpenditureInsufficientData,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    identifier: 'home-expenditure-value',
                    child: _MetricColumn(
                      label: s.homeExpenditureLabel,
                      value: EnergyDisplay.formatWithUnit(context, expenditure),
                    ),
                  ),
                  if (_energyBalanceKcal != null)
                    Semantics(
                      identifier: 'home-energy-balance-value',
                      child: _MetricColumn(
                        label: s.homeEnergyBalanceLabel,
                        value: _formatSigned(context, _energyBalanceKcal!),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatSigned(BuildContext context, double kcal) {
    final sign = kcal > 0 ? '+' : (kcal < 0 ? '-' : '');
    return '$sign${EnergyDisplay.formatWithUnit(context, kcal.abs())}';
  }
}

class _MetricColumn extends StatelessWidget {
  final String label;
  final String value;

  const _MetricColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
