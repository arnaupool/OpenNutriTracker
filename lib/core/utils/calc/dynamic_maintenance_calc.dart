class DynamicMaintenanceCalc {
  /// Band around the goal weight, in kg, inside which MacroFactor
  /// recommends pure maintenance rather than any correction. MacroFactor
  /// documents this as ±1.5 lb, which is ±0.7 kg.
  static const double maintenanceBandKg = 0.7;

  /// Weekly correction rate MacroFactor documents for trend weight
  /// outside the maintenance band: 0.15% of body weight per week.
  static const double correctionRatePerWeek = 0.0015;

  /// Same energy-density constant [TdeeDynamicCalc] uses to convert a
  /// weekly kg change into kcal — the classic ~3500 kcal/lb, in kg.
  static const double kcalPerKgBodyMass = 3500 * 2.20462;

  /// Recommends a daily calorie target from [trendWeightKg] vs.
  /// [goalWeightKg] and the current dynamic [tdeeKcal]:
  ///
  /// - Inside ±[maintenanceBandKg] of goal (boundary inclusive) — pure
  ///   maintenance, i.e. the recommendation equals [tdeeKcal].
  /// - Outside the band — a deficit (trend above goal) or surplus (trend
  ///   below goal) calibrated to correct back to goal at
  ///   [correctionRatePerWeek] of the current trend weight per week.
  ///
  /// This is the "soft landing" MacroFactor describes after a weight-loss
  /// attempt — small excursions around goal don't trigger any change, and
  /// larger ones get a gentle nudge back rather than a full driven
  /// deficit/surplus.
  /// Floating-point tolerance for the boundary comparison — far smaller
  /// than any real kg precision, it only absorbs representation noise
  /// from literal subtraction (e.g. `75.7 - 75.0` not landing on exactly
  /// `0.7`) so an input exactly at the documented boundary is treated
  /// consistently as still inside the band.
  static const double _epsilon = 1e-6;

  static double recommendedKcal({
    required double trendWeightKg,
    required double goalWeightKg,
    required double tdeeKcal,
  }) {
    final diffKg = trendWeightKg - goalWeightKg;
    if (diffKg.abs() <= maintenanceBandKg + _epsilon) {
      return tdeeKcal;
    }

    final correctionKcalPerWeek =
        correctionRatePerWeek * trendWeightKg * kcalPerKgBodyMass;
    final correctionKcalPerDay = correctionKcalPerWeek / 7;

    // Above goal -> deficit (subtract); below goal -> surplus (add).
    return diffKg > 0
        ? tdeeKcal - correctionKcalPerDay
        : tdeeKcal + correctionKcalPerDay;
  }
}
