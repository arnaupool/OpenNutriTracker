import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/features/meal_plan/data/weekly_note_dbo.dart';

/// Weekly plan notes keyed by week (`2026-W45`).
class WeeklyNoteDataSource {
  final Box<WeeklyNoteDBO> _box;

  WeeklyNoteDataSource(this._box);

  List<WeeklyNoteDBO> getAll() => _box.values.toList();

  WeeklyNoteDBO? get(String weekKey) => _box.get(weekKey);

  Future<void> save(WeeklyNoteDBO note) => _box.put(note.weekKey, note);

  Future<void> delete(String weekKey) => _box.delete(weekKey);

  /// Notifies on every change to the box (local edits and synced ones).
  Listenable listenable() => _box.listenable();
}
