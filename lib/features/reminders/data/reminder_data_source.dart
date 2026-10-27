import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:opennutritracker/features/reminders/data/reminder_dbo.dart';

/// The reminders (keyed by id) and the single settings record.
class ReminderDataSource {
  final Box<ReminderDBO> _reminders;
  final Box<ReminderSettingsDBO> _settings;

  ReminderDataSource(this._reminders, this._settings);

  /// Reminders ordered by time, then by id so the order is stable.
  List<ReminderDBO> reminders() {
    final list = _reminders.values.toList();
    list.sort((a, b) {
      final byTime = a.time.compareTo(b.time);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return list;
  }

  ReminderDBO? reminder(String id) => _reminders.get(id);

  Future<void> save(ReminderDBO reminder) => _reminders.put(reminder.id, reminder);

  Future<void> saveAll(Iterable<ReminderDBO> reminders) => _reminders.putAll({for (final r in reminders) r.id: r});

  Future<void> delete(String id) => _reminders.delete(id);

  ReminderSettingsDBO settings() => _settings.get(ReminderSettingsDBO.boxKey) ?? ReminderSettingsDBO();

  bool get hasSettings => _settings.containsKey(ReminderSettingsDBO.boxKey);

  Future<void> saveSettings(ReminderSettingsDBO settings) => _settings.put(ReminderSettingsDBO.boxKey, settings);

  /// Notifies on every change to either box (local edits and synced ones).
  Listenable get listenable => Listenable.merge([_reminders.listenable(), _settings.listenable()]);

  /// Change streams of both boxes, for the service that mirrors them to the backend.
  Stream<BoxEvent> get changes => _reminders.watch().merge(_settings.watch());
}
