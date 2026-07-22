import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/body_measurement_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_body_measurement_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Compact Home rendition of `body_measurements_screen.dart`'s own
/// "latest entry" + waist-to-height/waist-to-hip ratio logic — same
/// [GetBodyMeasurementUsecase], same ratio formulas, no data-layer
/// changes, just a smaller surface.
class BodyMetricsSummaryCard extends StatefulWidget {
  final GetBodyMeasurementUsecase? getBodyMeasurementUsecase;
  final GetUserUsecase? getUserUsecase;
  final ConfigRepository? configRepository;

  const BodyMetricsSummaryCard({
    super.key,
    this.getBodyMeasurementUsecase,
    this.getUserUsecase,
    this.configRepository,
  });

  @override
  State<BodyMetricsSummaryCard> createState() =>
      _BodyMetricsSummaryCardState();
}

class _BodyMetricsSummaryCardState extends State<BodyMetricsSummaryCard> {
  late final GetBodyMeasurementUsecase _bodyMeasurementUsecase =
      widget.getBodyMeasurementUsecase ??
      locator<GetBodyMeasurementUsecase>();
  late final GetUserUsecase _userUsecase =
      widget.getUserUsecase ?? locator<GetUserUsecase>();
  late final ConfigRepository _configRepository =
      widget.configRepository ?? locator<ConfigRepository>();

  bool _loading = true;
  bool _usesImperialUnits = false;
  BodyMeasurementEntity? _latest;
  double? _userHeightCm;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _bodyMeasurementUsecase.getAllEntries()
      ..sort((a, b) => b.date.compareTo(a.date));
    final user = await _userUsecase.getUserData();
    final config = await _configRepository.getConfig();

    if (!mounted) return;
    setState(() {
      _latest = entries.isNotEmpty ? entries.first : null;
      _userHeightCm = user.heightCM;
      _usesImperialUnits = config.usesImperialUnits;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final s = S.of(context);
    final theme = Theme.of(context);
    final latest = _latest;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.homeBodyMetricsCardTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (latest == null)
              Text(
                s.homeBodyMetricsInsufficientData,
                style: theme.textTheme.bodySmall,
              )
            else
              Semantics(
                identifier: 'home-body-metrics-value',
                child: _buildSummary(context, latest),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, BodyMeasurementEntity latest) {
    final s = S.of(context);
    final waist = latest.waistCm;
    final hips = latest.hipsCm;
    final height = _userHeightCm;

    final waistToHeight = (waist != null && height != null && height > 0)
        ? waist / height
        : null;
    final waistToHip = (waist != null && hips != null && hips > 0)
        ? waist / hips
        : null;
    final waistUnit = _usesImperialUnits ? s.inLabel : s.cmLabel;
    final displayWaist = waist == null
        ? null
        : (_usesImperialUnits ? UnitCalc.cmToInches(waist) : waist);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _MetricColumn(
          label: s.bodyMeasurementsWaistLabel,
          value: displayWaist == null
              ? '—'
              : '${displayWaist.toStringAsFixed(1)} $waistUnit',
        ),
        _MetricColumn(
          label: s.bodyMeasurementsWaistToHeightRatioLabel,
          value: waistToHeight?.toStringAsFixed(2) ?? '—',
        ),
        _MetricColumn(
          label: s.bodyMeasurementsWaistToHipRatioLabel,
          value: waistToHip?.toStringAsFixed(2) ?? '—',
        ),
      ],
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String label;
  final String value;

  const _MetricColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.titleMedium),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
