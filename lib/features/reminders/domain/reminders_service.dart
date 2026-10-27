import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/features/reminders/data/reminder_data_source.dart';
import 'package:opennutritracker/features/reminders/data/reminder_dbo.dart';
import 'package:opennutritracker/features/reminders/data/reminder_platform.dart';
import 'package:opennutritracker/features/reminders/data/reminders_api.dart';
import 'package:opennutritracker/features/reminders/domain/reminder_rules.dart';
import 'package:uuid/uuid.dart';

enum ReminderSyncStatus { idle, syncing, error }

/// Outcome of trying to turn web push on.
enum PushSetupResult { active, unsupported, denied, failed }

/// Keeps the reminders list and settings, and mirrors them to the reminders
/// backend (debounced) whenever either box changes, locally or by sync.
class RemindersService {
  static final _log = Logger('RemindersService');

  final ReminderDataSource _data;
  final RemindersApi _api;
  final ReminderPlatform _platform;
  final Duration _debounce;
  final DateTime Function() _now;
  final String Function() _newId;

  /// Whether the last sync reached the backend.
  final ValueNotifier<ReminderSyncStatus> status = ValueNotifier(ReminderSyncStatus.idle);

  /// Whether the server holds a push subscription for this device.
  final ValueNotifier<bool> pushActive = ValueNotifier(false);

  StreamSubscription<dynamic>? _watcher;
  Timer? _timer;
  Future<void> _running = Future.value();
  bool _stopped = false;

  RemindersService(
    this._data,
    this._api,
    this._platform, {
    Duration debounce = const Duration(seconds: 2),
    DateTime Function()? now,
    String Function()? newId,
  }) : _debounce = debounce,
       _now = now ?? DateTime.now,
       _newId = newId ?? (() => const Uuid().v4());

  ReminderDataSource get data => _data;

  ReminderPlatform get platform => _platform;

  List<ReminderDBO> get reminders => _data.reminders();

  ReminderSettingsDBO get settings => _data.settings();

  /// Starts mirroring changes to the backend. Reminders that already exist
  /// are sent once (the device may be new to the backend or on a new time zone).
  Future<void> start() async {
    _stopped = false;
    _watcher ??= _data.changes.listen((_) => _scheduleSync());
    if (reminders.isNotEmpty) {
      await _refreshTimezone();
      _scheduleSync();
    }
  }

  Future<void> stop() async {
    _stopped = true;
    _timer?.cancel();
    await _watcher?.cancel();
    _watcher = null;
  }

  /// Creates the five built-in reminders the first time, and the settings
  /// with the device time zone.
  Future<void> ensureDefaults() async {
    if (!_data.hasSettings) {
      await _data.saveSettings(ReminderSettingsDBO(timezone: await _platform.detectTimezone() ?? 'UTC'));
    } else {
      await _refreshTimezone();
    }
    if (_data.reminders().isNotEmpty) return;
    await _data.saveAll(ReminderRules.defaults(_defaultChannel()));
  }

  ReminderChannel _defaultChannel() {
    final s = _data.settings();
    return ReminderRules.defaultChannel(
      telegramLinked: s.telegramLinked,
      emailVerified: s.emailVerified,
      pushSupported: _platform.pushSupport == PushSupport.supported,
    );
  }

  Future<void> _refreshTimezone() async {
    final detected = await _platform.detectTimezone();
    final s = _data.settings();
    if (detected != null && detected != s.timezone) await _data.saveSettings(s.copyWith(timezone: detected));
  }

  // ---------------------------------------------------------------- edits

  Future<void> setEnabled(String id, bool enabled) async {
    final r = _data.reminder(id);
    if (r != null && r.enabled != enabled) await _data.save(r.copyWith(enabled: enabled));
  }

  Future<void> update(ReminderDBO reminder) async {
    if (!ReminderRules.isValid(reminder)) throw ArgumentError.value(reminder.id, 'reminder', 'invalid reminder');
    await _data.save(reminder);
  }

  /// A new custom reminder, or null when the limit is reached or the name is invalid.
  Future<ReminderDBO?> addCustom(String name) async {
    if (!ReminderRules.canAdd(_data.reminders().length) || !ReminderRules.isValidLabel(name)) return null;
    final reminder = ReminderDBO(
      id: _newId(),
      type: ReminderType.custom,
      label: ReminderRules.clampLabel(name),
      time: '12:00',
      days: ReminderRules.allDays,
      channel: _defaultChannel(),
    );
    await _data.save(reminder);
    return reminder;
  }

  /// Copy of [id] named [name]; null when over the limit or [id] is unknown.
  Future<ReminderDBO?> duplicate(String id, String name) async {
    final source = _data.reminder(id);
    if (source == null || !ReminderRules.canAdd(_data.reminders().length)) return null;
    final copy = ReminderRules.duplicate(source, _newId(), name);
    await _data.save(copy);
    return copy;
  }

  /// Renames a custom reminder; false when [name] is invalid or it is built in.
  Future<bool> rename(String id, String name) async {
    final r = _data.reminder(id);
    if (r == null || !ReminderRules.canRename(r) || !ReminderRules.isValidLabel(name)) return false;
    await _data.save(r.copyWith(label: ReminderRules.clampLabel(name)));
    return true;
  }

  /// Deletes a custom reminder; the built-in ones cannot be deleted.
  Future<bool> delete(String id) async {
    final r = _data.reminder(id);
    if (r == null || !ReminderRules.canDelete(r)) return false;
    await _data.delete(id);
    return true;
  }

  Future<void> saveSettings(ReminderSettingsDBO settings) => _data.saveSettings(settings);

  // ----------------------------------------------------------------- sync

  void _scheduleSync() {
    if (_stopped) return;
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(syncNow()));
  }

  /// Sends the full list and settings now and adopts what the server answers.
  /// Returns the answer, or null when the backend could not be reached.
  Future<ReminderSyncResponse?> syncNow({bool telegramLink = false}) {
    _timer?.cancel();
    final completer = Completer<ReminderSyncResponse?>();
    _running = _running.then((_) async {
      completer.complete(await _syncOnce(telegramLink: telegramLink));
    });
    return completer.future;
  }

  Future<ReminderSyncResponse?> _syncOnce({bool telegramLink = false}) async {
    status.value = ReminderSyncStatus.syncing;
    final sent = _data.reminders();
    final s = _data.settings();
    try {
      final response = await _api.sync({
        'timezone': s.timezone,
        'quietStart': s.quietStart,
        'quietEnd': s.quietEnd,
        'reminders': [for (final r in sent) r.toJson()],
        if (telegramLink) 'telegramLink': true,
      });
      await _adopt(response, sent);
      status.value = ReminderSyncStatus.idle;
      return response;
    } catch (e) {
      _log.warning('reminders sync failed: $e');
      status.value = ReminderSyncStatus.error;
      return null;
    }
  }

  /// Reads the server state without changing anything there.
  Future<ReminderSyncResponse?> refreshStatus() async {
    try {
      final response = await _api.sync({});
      await _adopt(response, null);
      return response;
    } catch (e) {
      _log.warning('reminders status failed: $e');
      return null;
    }
  }

  /// Takes the channel the server holds for each reminder (it moves push to
  /// email after repeated failures) and the state of the channels.
  Future<void> _adopt(ReminderSyncResponse response, List<ReminderDBO>? sent) async {
    pushActive.value = response.pushActive;
    if (sent != null) {
      for (final was in sent) {
        final server = response.channels[was.id];
        final now = _data.reminder(was.id);
        // Skip when the user changed the channel while the request was in flight.
        if (server == null || now == null || server == was.channel || now.channel != was.channel) continue;
        await _data.save(now.copyWith(channel: server));
      }
    }
    final s = _data.settings();
    final email = response.emailVerified ? (response.emailAddress ?? s.email) : s.email;
    if (s.telegramLinked != response.telegramLinked || s.emailVerified != response.emailVerified || s.email != email) {
      await _data.saveSettings(
        s.copyWith(telegramLinked: response.telegramLinked, emailVerified: response.emailVerified, email: email),
      );
    }
  }

  // ------------------------------------------------------------- channels

  /// Link URL for the Telegram bot, or null when the backend could not be reached.
  Future<String?> requestTelegramLink() async => (await syncNow(telegramLink: true))?.telegramLinkUrl;

  /// Polls until the Telegram link is done; false after [timeout] or when [cancelled] says stop.
  Future<bool> waitForTelegram({
    Duration interval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 3),
    bool Function()? cancelled,
  }) async {
    final deadline = _now().add(timeout);
    while (_now().isBefore(deadline)) {
      if (cancelled?.call() ?? false) return false;
      await Future<void>.delayed(interval);
      if (cancelled?.call() ?? false) return false;
      final r = await refreshStatus();
      if (r?.telegramLinked ?? false) return true;
    }
    return false;
  }

  Future<void> requestEmailCode(String email) => _api.requestEmailCode(email.trim());

  /// Confirms the 6-digit [code]; stores the verified address.
  Future<void> confirmEmail(String code) async {
    final email = await _api.confirmEmail(code.trim());
    await _data.saveSettings(_data.settings().copyWith(email: email, emailVerified: true));
  }

  /// Whether enabling [reminder] should ask for web push permission first.
  bool needsPushSetup(ReminderDBO reminder) =>
      reminder.enabled &&
      reminder.channel == ReminderChannel.push &&
      _platform.pushSupport == PushSupport.supported &&
      (_platform.pushPermission == PushPermission.prompt || !pushActive.value);

  /// Asks the browser for permission and subscribes this device to web push.
  /// Call it straight from a tap handler: the permission request must be the
  /// first thing that happens.
  Future<PushSetupResult> enablePush() async {
    if (_platform.pushSupport != PushSupport.supported) return PushSetupResult.unsupported;
    final permission = await _platform.requestPushPermission();
    if (permission != PushPermission.granted) return PushSetupResult.denied;
    try {
      final vapid = (await syncNow())?.vapidPublicKey;
      if (vapid == null) return PushSetupResult.failed;
      final subscription = await _platform.subscribePush(vapid);
      if (subscription == null) return PushSetupResult.failed;
      final response = await _api.sync({'pushSubscription': subscription});
      pushActive.value = response.pushActive;
      return response.pushActive ? PushSetupResult.active : PushSetupResult.failed;
    } catch (e) {
      _log.warning('enabling push failed: $e');
      return PushSetupResult.failed;
    }
  }

  /// Sends reminder [id] now (after flushing pending edits). Returns the channel used.
  Future<String?> sendTest(String id) async {
    await syncNow();
    return _api.test(id);
  }

  // ----------------------------------------------------------- meal flags

  /// Tells the backend a meal was logged today, so reminders that skip
  /// logged meals stay quiet. Fire-and-forget; only when some enabled
  /// reminder wants it.
  Future<void> onIntakeAdded(IntakeEntity intake) async {
    final today = _now();
    final when = intake.dateTime;
    if (when.year != today.year || when.month != today.month || when.day != today.day) return;
    final wanted = _data.reminders().any((r) => r.enabled && r.skipIfLogged && r.mealType?.name == intake.type.name);
    if (!wanted) return;
    try {
      await _api.sync({
        'mealLogged': {'date': dateKey(today), 'mealType': intake.type.name},
      });
    } catch (e) {
      _log.fine('meal flag failed: $e');
    }
  }

  /// `yyyy-MM-dd` of the local day.
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
