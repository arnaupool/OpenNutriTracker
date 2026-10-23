import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_entry_dbo.dart';

/// Planned meals keyed by entry id.
class MealPlanDataSource {
  final Box<MealPlanEntryDBO> _box;

  MealPlanDataSource(this._box);

  Future<void> save(MealPlanEntryDBO entry) => _box.put(entry.id, entry);

  Future<void> delete(String id) => _box.delete(id);

  /// Entries whose day falls within [from]..[to], both inclusive.
  List<MealPlanEntryDBO> entriesBetween(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    return _box.values.where((e) {
      final day = DateTime(e.day.year, e.day.month, e.day.day);
      return !day.isBefore(start) && !day.isAfter(end);
    }).toList();
  }
}
