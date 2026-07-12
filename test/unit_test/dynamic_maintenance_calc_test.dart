import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/calc/dynamic_maintenance_calc.dart';

void main() {
  test('exactly at goal weight recommends pure maintenance', () {
    final result = DynamicMaintenanceCalc.recommendedKcal(
      trendWeightKg: 75.0,
      goalWeightKg: 75.0,
      tdeeKcal: 2500,
    );
    expect(result, 2500.0);
  });

  test('exactly at the +0.7kg boundary still recommends pure maintenance '
      '(inclusive)', () {
    final result = DynamicMaintenanceCalc.recommendedKcal(
      trendWeightKg: 75.7,
      goalWeightKg: 75.0,
      tdeeKcal: 2500,
    );
    expect(result, 2500.0);
  });

  test('exactly at the -0.7kg boundary still recommends pure maintenance '
      '(inclusive)', () {
    final result = DynamicMaintenanceCalc.recommendedKcal(
      trendWeightKg: 74.3,
      goalWeightKg: 75.0,
      tdeeKcal: 2500,
    );
    expect(result, 2500.0);
  });

  test('above the band recommends a small deficit calibrated to 0.15%/week '
      '(matches the plan\'s ~2375 kcal worked example in magnitude)', () {
    final result = DynamicMaintenanceCalc.recommendedKcal(
      trendWeightKg: 76.0, // 1kg above goal, outside the 0.7kg band
      goalWeightKg: 75.0,
      tdeeKcal: 2500,
    );

    // 0.15% of 76kg = 0.114 kg/week -> * 7716.17 kcal/kg / 7 days
    const expectedDeficitPerDay = 0.0015 * 76.0 * (3500 * 2.20462) / 7;
    expect(result, closeTo(2500 - expectedDeficitPerDay, 0.01));
    expect(result, closeTo(2374.3, 0.5));
    expect(result, lessThan(2500));
  });

  test('below the band recommends a small surplus, symmetric to the '
      'deficit case', () {
    final result = DynamicMaintenanceCalc.recommendedKcal(
      trendWeightKg: 74.0, // 1kg below goal, outside the 0.7kg band
      goalWeightKg: 75.0,
      tdeeKcal: 2500,
    );

    const expectedSurplusPerDay = 0.0015 * 74.0 * (3500 * 2.20462) / 7;
    expect(result, closeTo(2500 + expectedSurplusPerDay, 0.01));
    expect(result, greaterThan(2500));
  });

  test('the correction is a fixed rate the moment you cross the boundary, '
      'not proportional to how far outside it you are — this is a step '
      'function, not a gradient, because the plan specifies "0.15% of '
      'body weight per week" as a flat target rate, not an error-scaled '
      'one', () {
    final justPastBoundary = DynamicMaintenanceCalc.recommendedKcal(
      trendWeightKg: 75.71,
      goalWeightKg: 75.0,
      tdeeKcal: 2500,
    );
    final wellPastBoundary = DynamicMaintenanceCalc.recommendedKcal(
      trendWeightKg: 76.0,
      goalWeightKg: 75.0,
      tdeeKcal: 2500,
    );

    // Both trigger essentially the same correction magnitude (the tiny
    // difference is only from the rate scaling with trendWeightKg itself,
    // not with the distance from goal).
    expect(justPastBoundary, closeTo(wellPastBoundary, 1.0));
    expect(justPastBoundary, lessThan(2500));
  });

  test(
    'the correction direction always pulls back toward goal, never away',
    () {
      final aboveResult = DynamicMaintenanceCalc.recommendedKcal(
        trendWeightKg: 80.0,
        goalWeightKg: 75.0,
        tdeeKcal: 2500,
      );
      final belowResult = DynamicMaintenanceCalc.recommendedKcal(
        trendWeightKg: 70.0,
        goalWeightKg: 75.0,
        tdeeKcal: 2500,
      );

      expect(aboveResult, lessThan(2500)); // eat less to come back down
      expect(belowResult, greaterThan(2500)); // eat more to come back up
    },
  );
}
