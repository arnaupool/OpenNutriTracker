import 'package:opennutritracker/features/reminders/data/reminder_dbo.dart';

/// Pure rules for the reminders: built-in set, limits and channel choice.
class ReminderRules {
  static const int maxLabelLength = 40;
  static const int maxReminders = 15;
  static const int timeStepMinutes = 5;
  static const List<int> allDays = [1, 2, 3, 4, 5, 6, 7];
  static const List<int> workDays = [1, 2, 3, 4, 5];

  static const String weighInId = '${ReminderDBO.defaultIdPrefix}weigh_in';

  static String mealId(ReminderMealType meal) => '${ReminderDBO.defaultIdPrefix}${meal.name}';

  /// The five built-in reminders. Only the weigh-in is on by default.
  static List<ReminderDBO> defaults(ReminderChannel channel) => [
    ReminderDBO(id: weighInId, type: ReminderType.weighIn, time: '07:00', days: workDays, channel: channel),
    _meal(ReminderMealType.breakfast, '07:30', channel),
    _meal(ReminderMealType.lunch, '14:00', channel),
    _meal(ReminderMealType.snack, '17:30', channel),
    _meal(ReminderMealType.dinner, '21:00', channel),
  ];

  static ReminderDBO _meal(ReminderMealType meal, String time, ReminderChannel channel) => ReminderDBO(
    id: mealId(meal),
    type: ReminderType.meal,
    mealType: meal,
    time: time,
    days: allDays,
    channel: channel,
    enabled: false,
    skipIfLogged: true,
  );

  /// Telegram if linked, else email if verified, else web push when the
  /// browser can do it, else Telegram (the owner links it later).
  static ReminderChannel defaultChannel({
    required bool telegramLinked,
    required bool emailVerified,
    required bool pushSupported,
  }) {
    if (telegramLinked) return ReminderChannel.telegram;
    if (emailVerified) return ReminderChannel.email;
    if (pushSupported) return ReminderChannel.push;
    return ReminderChannel.telegram;
  }

  /// A label is valid when, trimmed, it has 1 to [maxLabelLength] characters.
  static bool isValidLabel(String label) {
    final length = label.trim().runes.length;
    return length >= 1 && length <= maxLabelLength;
  }

  static String clampLabel(String label) {
    final runes = label.trim().runes.toList();
    return String.fromCharCodes(runes.length <= maxLabelLength ? runes : runes.sublist(0, maxLabelLength));
  }

  static bool canAdd(int currentCount) => currentCount < maxReminders;

  /// The five built-in reminders can only be disabled.
  static bool canDelete(ReminderDBO reminder) => !reminder.isDefault;

  static bool canRename(ReminderDBO reminder) => !reminder.isDefault;

  /// `HH:MM` with minutes in 5-minute steps.
  static bool isValidTime(String time) {
    final m = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(time);
    return m != null && int.parse(m.group(2)!) % timeStepMinutes == 0;
  }

  static String formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Rounds [minute] to the nearest 5-minute step (carrying into the hour).
  static String snapTime(int hour, int minute) {
    final total = ((hour * 60 + minute) / timeStepMinutes).round() * timeStepMinutes % (24 * 60);
    return formatTime(total ~/ 60, total % 60);
  }

  static bool isValidDays(List<int> days) => days.isNotEmpty && days.every((d) => d >= 1 && d <= 7);

  static bool isValid(ReminderDBO r) =>
      isValidTime(r.time) &&
      isValidDays(r.days) &&
      r.label.runes.length <= maxLabelLength &&
      (r.type == ReminderType.meal) == (r.mealType != null) &&
      RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(r.id);

  /// Copy of [source] for "Duplicate": new id, disabled until the user turns it on.
  static ReminderDBO duplicate(ReminderDBO source, String newId, String name) => ReminderDBO(
    id: newId,
    type: source.type,
    mealType: source.mealType,
    label: clampLabel(name),
    time: source.time,
    days: List.of(source.days),
    channel: source.channel,
    enabled: false,
    skipIfLogged: source.skipIfLogged,
  );
}
