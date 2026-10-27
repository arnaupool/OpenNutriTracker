import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/features/diet_plan/data/diet_plan_dbo.dart';

/// The single diet plan, stored under [DietPlanDBO.boxKey].
class DietPlanDataSource {
  final Box<DietPlanDBO> _box;

  DietPlanDataSource(this._box);

  DietPlanDBO? get() => _box.get(DietPlanDBO.boxKey);

  Future<void> save(DietPlanDBO plan) => _box.put(DietPlanDBO.boxKey, plan);

  /// Notifies on every change to the box (local edits and synced ones).
  ValueListenable<Box<DietPlanDBO>> listenable() => _box.listenable();
}
