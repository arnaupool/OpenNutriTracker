import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/sync/sync_engine.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';

/// Recomputes the eaten kcal and macros of every day a pull touched, from
/// the intakes themselves. TrackedDay totals are running sums each device
/// keeps incrementally, so two devices logging the same day would otherwise
/// overwrite each other's totals; the intakes are the source of truth.
class SyncDayTotals {
  final Box<IntakeDBO> _intakeBox;
  final TrackedDayDataSource _trackedDays;
  final ConfigDataSource _config;

  SyncDayTotals(this._intakeBox, this._trackedDays, this._config);

  Future<Set<DateTime>> reconcile(List<SyncAppliedChange> applied, String intakeBoxName, String trackedDayBoxName) async {
    final config = await _config.getConfig();
    final offset = (config.dayStartOffsetHours ?? 0) * 60 + (config.dayStartOffsetMinutes ?? 0);
    final days = <DateTime>{};
    for (final change in applied) {
      for (final value in [change.before, change.after]) {
        if (change.box == intakeBoxName && value is IntakeDBO) {
          days.add(DayBoundaryCalc.logicalDayOfMinutes(value.dateTime, offset));
        } else if (change.box == trackedDayBoxName && value is TrackedDayDBO) {
          days.add(DateTime(value.day.year, value.day.month, value.day.day));
        }
      }
    }
    for (final day in days) {
      var kcal = 0.0, carbs = 0.0, fat = 0.0, protein = 0.0;
      for (final dbo in _intakeBox.values) {
        final logical = DayBoundaryCalc.logicalDayOfMinutes(dbo.dateTime, offset);
        if (logical.year != day.year || logical.month != day.month || logical.day != day.day) continue;
        final intake = IntakeEntity.fromIntakeDBO(dbo);
        kcal += intake.totalKcal;
        carbs += intake.totalCarbsGram;
        fat += intake.totalFatsGram;
        protein += intake.totalProteinsGram;
      }
      await _trackedDays.reconcileCaloriesAndMacrosTracked(day, kcal, carbs, fat, protein);
    }
    return days;
  }
}
