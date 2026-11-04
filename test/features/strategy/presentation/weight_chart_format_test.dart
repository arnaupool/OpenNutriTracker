import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/strategy/presentation/weight_chart_format.dart';

void main() {
  group('formatChartWeight', () {
    test('rounds to two decimals with the locale separator', () {
      expect(formatChartWeight(103.1858866892, 'es'), '103,19');
      expect(formatChartWeight(103.1858866892, 'en'), '103.19');
      expect(formatChartWeight(103.1, 'es'), '103,10');
    });

    test('honours a custom number of decimals', () {
      expect(formatChartWeight(103.46, 'es', decimals: 1), '103,5');
      expect(formatChartWeight(103.4, 'es', decimals: 0), '103');
    });
  });

  group('WeightAxisScale', () {
    List<double> ticks(WeightAxisScale s) => [for (var v = s.minY; v <= s.maxY + 1e-9; v += s.interval) v];

    test('ticks stay distinct once formatted, for narrow and wide ranges', () {
      for (final range in [(103.2, 103.9), (103.0, 106.5), (80.0, 95.0), (60.0, 140.0), (70.0, 70.0)]) {
        final scale = WeightAxisScale.compute(range.$1, range.$2);
        final labels = ticks(scale).map((v) => formatChartWeight(v, 'en', decimals: scale.decimals)).toList();
        expect(labels.toSet().length, labels.length, reason: '$range -> $labels');
        expect(scale.minY, lessThanOrEqualTo(range.$1));
        expect(scale.maxY, greaterThanOrEqualTo(range.$2));
        expect(labels.length, lessThanOrEqualTo(8), reason: '$range -> $labels');
      }
    });

    test('a narrow range uses one decimal, a wide one whole numbers', () {
      expect(WeightAxisScale.compute(103.2, 103.9).decimals, 1);
      expect(WeightAxisScale.compute(80.0, 95.0).decimals, 0);
    });
  });
}
