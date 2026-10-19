import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/utils/calc/tdee_dynamic_calc.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_interpolation_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_trend_calc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';

class WeightTrendSummaryCard extends StatefulWidget {
  final GetWeightLogUsecase? getWeightLogUsecase;
  final ConfigRepository? configRepository;

  const WeightTrendSummaryCard({
    super.key,
    this.getWeightLogUsecase,
    this.configRepository,
  });

  @override
  State<WeightTrendSummaryCard> createState() =>
      _WeightTrendSummaryCardState();
}

class _WeightTrendSummaryCardState extends State<WeightTrendSummaryCard> {
  /// Below this, a rate is treated as noise rather than a real trend
  /// direction — avoids flip-flopping the trending icon on near-zero
  /// week-to-week movement.
  static const double _flatThresholdKg = 0.05;

  late final GetWeightLogUsecase _weightUsecase =
      widget.getWeightLogUsecase ?? locator<GetWeightLogUsecase>();
  late final ConfigRepository _configRepository =
      widget.configRepository ?? locator<ConfigRepository>();

  bool _loading = true;
  bool _usesImperialUnits = false;
  double? _trendWeightKg;
  double? _weeklyChangeRateKg;
  bool _hasRecentWeighIns = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await _configRepository.getConfig();
    final entries = await _weightUsecase.getAllEntries();
    final filled = WeightInterpolationCalc.fillGaps(entries);
    final trend = WeightTrendCalc.computeTrend(filled);

    final hasEnoughTrend =
        trend.length >= TdeeDynamicCalc.minTrendPointsForDynamic;
    // FD-13 (AUDIT.md B6): MacroFactor's change rate is "based on changes
    // in your trend weight over the past 20 days"
    // (https://help.macrofactorapp.com/en/articles/19-change-rate), so only
    // trend points inside that window, counted back from today, count.
    final now = DateTime.now();
    final windowStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: TdeeDynamicCalc.changeRateWindowDays));
    final recent = trend.where((p) => !p.date.isBefore(windowStart)).toList();
    final hasRecentWeighIns = recent.length >= 2;

    if (!mounted) return;
    setState(() {
      _usesImperialUnits = config.usesImperialUnits;
      _trendWeightKg = hasEnoughTrend ? trend.last.trendWeightKg : null;
      _hasRecentWeighIns = hasRecentWeighIns;
      _weeklyChangeRateKg = hasEnoughTrend && hasRecentWeighIns
          ? TdeeDynamicCalc.weeklyChangeRateKg(recent)
          : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final s = S.of(context);
    final theme = Theme.of(context);
    final trendWeightKg = _trendWeightKg;

    if (trendWeightKg == null) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.homeWeightTrendLabel, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Text(
                s.homeExpenditureInsufficientData,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    final weightUnit = _usesImperialUnits ? s.lbsLabel : s.kgLabel;
    final displayTrendWeight = _usesImperialUnits
        ? UnitCalc.kgToLbs(trendWeightKg)
        : trendWeightKg;
    final rateKg = _weeklyChangeRateKg;
    final displayRate = rateKg == null
        ? null
        : (_usesImperialUnits ? UnitCalc.kgToLbs(rateKg) : rateKg);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              identifier: 'home-weight-trend-value',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${displayTrendWeight.toStringAsFixed(1)} $weightUnit',
                    style: theme.textTheme.headlineSmall,
                  ),
                  Text(
                    s.homeWeightTrendLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              identifier: 'home-weight-trend-rate',
              child: Row(
                children: [
                  if (!_hasRecentWeighIns)
                    const SizedBox.shrink()
                  else if (rateKg != null && rateKg.abs() >= _flatThresholdKg)
                    Icon(
                      rateKg > 0
                          ? Icons.trending_up_outlined
                          : Icons.trending_down_outlined,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.7,
                      ),
                    )
                  else
                    Icon(
                      Icons.trending_flat_outlined,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    !_hasRecentWeighIns
                        ? s.homeWeightTrendNoRecentData
                        : displayRate == null ||
                              rateKg!.abs() < _flatThresholdKg
                        ? s.homeWeightTrendStable
                        : s.homeWeightTrendRate(
                            '${displayRate > 0 ? '+' : ''}${displayRate.toStringAsFixed(1)} $weightUnit',
                          ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
