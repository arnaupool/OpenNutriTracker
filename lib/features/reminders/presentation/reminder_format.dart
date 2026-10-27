import 'package:flutter/widgets.dart';
import 'package:opennutritracker/features/reminders/data/reminder_dbo.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Texts for the reminders screens.
class ReminderFormat {
  /// Name shown in the list: the label, or the built-in name.
  static String name(BuildContext context, ReminderDBO r) {
    if (r.label.isNotEmpty) return r.label;
    final s = S.of(context);
    switch (r.type) {
      case ReminderType.weighIn:
        return s.remindersNameWeighIn;
      case ReminderType.meal:
        return mealName(context, r.mealType);
      case ReminderType.custom:
        return s.remindersNew;
    }
  }

  static String mealName(BuildContext context, ReminderMealType? meal) {
    final s = S.of(context);
    switch (meal) {
      case ReminderMealType.breakfast:
        return s.remindersNameBreakfast;
      case ReminderMealType.lunch:
        return s.remindersNameLunch;
      case ReminderMealType.snack:
        return s.remindersNameSnack;
      case ReminderMealType.dinner:
        return s.remindersNameDinner;
      case null:
        return s.remindersNew;
    }
  }

  /// What the notification says for built-in types (custom ones say their label).
  static String? body(BuildContext context, ReminderDBO r) {
    final s = S.of(context);
    switch (r.type) {
      case ReminderType.weighIn:
        return s.remindersBodyWeighIn;
      case ReminderType.meal:
        switch (r.mealType) {
          case ReminderMealType.breakfast:
            return s.remindersBodyBreakfast;
          case ReminderMealType.lunch:
            return s.remindersBodyLunch;
          case ReminderMealType.snack:
            return s.remindersBodySnack;
          case ReminderMealType.dinner:
            return s.remindersBodyDinner;
          case null:
            return null;
        }
      case ReminderType.custom:
        return null;
    }
  }

  /// One-letter weekday, [isoDay] 1 = Monday .. 7 = Sunday.
  static String dayLetter(BuildContext context, int isoDay) {
    final s = S.of(context);
    return [
      s.remindersDayMon,
      s.remindersDayTue,
      s.remindersDayWed,
      s.remindersDayThu,
      s.remindersDayFri,
      s.remindersDaySat,
      s.remindersDaySun,
    ][isoDay - 1];
  }

  static String days(BuildContext context, List<int> days) =>
      ([...days]..sort()).map((d) => dayLetter(context, d)).join(' ');

  static String channel(BuildContext context, ReminderChannel channel) {
    final s = S.of(context);
    switch (channel) {
      case ReminderChannel.push:
        return s.remindersChannelPush;
      case ReminderChannel.email:
        return s.remindersChannelEmail;
      case ReminderChannel.telegram:
        return s.remindersChannelTelegram;
    }
  }

  /// Channel name from the string the backend answers in `reminders-test`.
  static String channelByName(BuildContext context, String? wire) => channel(context, ReminderChannel.fromWire(wire));
}
