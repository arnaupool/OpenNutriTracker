import 'package:opennutritracker/features/reminders/data/reminder_dbo.dart';

/// Where a tapped reminder notification sends the app: its URL carries
/// `?open=weigh_in` or `?open=meal&meal=<breakfast|lunch|snack|dinner>`.
class ReminderOpenTarget {
  final bool weighIn;
  final ReminderMealType? meal;

  const ReminderOpenTarget.weighIn() : weighIn = true, meal = null;

  const ReminderOpenTarget.meal(ReminderMealType this.meal) : weighIn = false;

  /// The target in [uri]'s query, or null when there is none or it is not valid.
  static ReminderOpenTarget? fromUri(Uri uri) {
    final params = uri.queryParameters;
    switch (params['open']) {
      case 'weigh_in':
        return const ReminderOpenTarget.weighIn();
      case 'meal':
        final meal = ReminderMealType.fromWire(params['meal']);
        return meal == null ? null : ReminderOpenTarget.meal(meal);
    }
    return null;
  }
}
