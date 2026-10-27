import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Display formats shared by the plan surfaces.
class DietPlanFormat {
  /// dd/MM/yyyy, whatever the locale (the format the plan always shows).
  static String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// [value] with at most [decimals] decimals and the locale's separator.
  static String number(BuildContext context, double value, {int decimals = 1}) {
    final locale = Localizations.maybeLocaleOf(context)?.toString() ?? 'en';
    final pattern = decimals <= 0 ? '0' : '0.${'0' * decimals}';
    return NumberFormat(pattern, locale).format(value);
  }

  /// [value] with at most one decimal, none when whole (4.5, 10).
  static String compact(BuildContext context, double value) {
    final locale = Localizations.maybeLocaleOf(context)?.toString() ?? 'en';
    return NumberFormat('0.#', locale).format(value);
  }

  /// A pace such as 0.25, 0.5 or 0.75 without trailing zeros.
  static String pace(BuildContext context, double value) {
    final locale = Localizations.maybeLocaleOf(context)?.toString() ?? 'en';
    return NumberFormat('0.##', locale).format(value);
  }
}
