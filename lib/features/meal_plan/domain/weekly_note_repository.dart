import 'package:flutter/foundation.dart';
import 'package:opennutritracker/features/meal_plan/data/weekly_note_data_source.dart';
import 'package:opennutritracker/features/meal_plan/data/weekly_note_dbo.dart';

/// The ISO 8601 week of [date] as `2026-W45` (weeks start on Monday and the
/// week belongs to the year of its Thursday).
String isoWeekKey(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
  final week = 1 + thursday.difference(DateTime.utc(thursday.year, 1, 1)).inDays ~/ 7;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

final _checklistLine = RegExp(r'^(\s*- \[)([ xX])(\]\s?)(.*)$');

/// A line of a note, read as a checklist item when it starts with `- [ ]` or
/// `- [x]`.
class NoteLine {
  final String raw;
  final bool isChecklist;
  final bool checked;

  /// The text after the box (the whole line for a plain line).
  final String text;

  const NoteLine(this.raw, {this.isChecklist = false, this.checked = false, required this.text});

  factory NoteLine.parse(String raw) {
    final match = _checklistLine.firstMatch(raw);
    if (match == null) return NoteLine(raw, text: raw);
    return NoteLine(raw, isChecklist: true, checked: match.group(2) != ' ', text: match.group(4)!);
  }
}

List<NoteLine> parseNote(String text) => text.split('\n').map(NoteLine.parse).toList();

/// [text] with the checkbox on line [index] flipped; unchanged when that line
/// is not a checklist item.
String toggleChecklistLine(String text, int index) {
  final lines = text.split('\n');
  if (index < 0 || index >= lines.length) return text;
  final match = _checklistLine.firstMatch(lines[index]);
  if (match == null) return text;
  final nowChecked = match.group(2) == ' ';
  lines[index] = '${match.group(1)}${nowChecked ? 'x' : ' '}${match.group(3)}${match.group(4)}';
  return lines.join('\n');
}

class WeeklyNoteRepository {
  final WeeklyNoteDataSource _dataSource;

  WeeklyNoteRepository(this._dataSource);

  /// Notifies when any note changes (local edits and synced ones).
  Listenable listenable() => _dataSource.listenable();

  String textOf(String weekKey) => _dataSource.get(weekKey)?.text ?? '';

  /// Saves the note of [weekKey]; a blank note is deleted.
  Future<void> save(String weekKey, String text, {DateTime? now}) {
    if (text.trim().isEmpty) return _dataSource.delete(weekKey);
    return _dataSource.save(WeeklyNoteDBO(weekKey: weekKey, text: text, modifiedAt: now ?? DateTime.now()));
  }

  List<Map<String, dynamic>> exportJson() => _dataSource.getAll().map((n) => n.toJson()).toList();

  /// Merges exported notes: a record replaces the local note of its week only
  /// when it is newer. Returns how many were written.
  Future<int> importJson(List<Map<String, dynamic>> records) async {
    var imported = 0;
    for (final json in records) {
      final incoming = WeeklyNoteDBO.fromJson(json);
      final local = _dataSource.get(incoming.weekKey);
      if (local != null && !local.modifiedAt.isBefore(incoming.modifiedAt)) continue;
      await _dataSource.save(incoming);
      imported++;
    }
    return imported;
  }
}
