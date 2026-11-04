import 'dart:math' as math;

import 'package:intl/intl.dart';

/// Y axis of the Strategy weight chart: bounds snapped to a "nice" step so
/// the ticks never repeat once rounded (103.4, 103.9, ... instead of
/// 104, 104, 103).
class WeightAxisScale {
  final double minY;
  final double maxY;
  final double interval;

  /// Decimals the tick labels need to tell consecutive ticks apart.
  final int decimals;

  const WeightAxisScale({required this.minY, required this.maxY, required this.interval, required this.decimals});

  static const _niceSteps = [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];

  /// [minValue]/[maxValue] are the lowest and highest plotted weights.
  factory WeightAxisScale.compute(double minValue, double maxValue) {
    final padding = ((maxValue - minValue) * 0.15).clamp(0.5, 5.0);
    final low = minValue - padding;
    final high = maxValue + padding;
    final rawStep = (high - low) / 4;
    final step = _niceSteps.firstWhere((s) => s >= rawStep, orElse: () => _niceSteps.last);
    return WeightAxisScale(
      minY: (low / step).floorToDouble() * step,
      maxY: (high / step).ceilToDouble() * step,
      interval: step,
      decimals: step % 1 == 0 ? 0 : 1,
    );
  }
}

/// Number format shared by the chart's axis ticks and tooltip, following the
/// locale (es: 103,19).
String formatChartWeight(double value, String localeTag, {int decimals = 2}) {
  final format = NumberFormat.decimalPatternDigits(locale: localeTag, decimalDigits: decimals);
  // Avoids "-0" and keeps the rounding the same as the displayed digits.
  final factor = math.pow(10, decimals);
  return format.format((value * factor).round() / factor);
}
