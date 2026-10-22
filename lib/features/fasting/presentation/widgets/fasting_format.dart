import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/features/fasting/domain/fasting_safety.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Shared text helpers for the fasting screen, its dialogs and the home chip.
class FastingFormat {
  /// `16h 05m`, or `42m` under an hour. Minute resolution so labels don't
  /// twitch every second.
  static String hoursMinutes(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  /// `16:05:09`, for the running clock.
  static String clock(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static String dateTime(BuildContext context, DateTime t) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.MMMd(locale).add_Hm().format(t);
  }

  static String time(BuildContext context, DateTime t) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.Hm(locale).format(t);
  }

  static String error(BuildContext context, FastingWindowError error) {
    final l10n = S.of(context);
    return switch (error) {
      FastingWindowError.startInFuture => l10n.fastingErrorStartInFuture,
      FastingWindowError.endInFuture => l10n.fastingErrorEndInFuture,
      FastingWindowError.endBeforeStart => l10n.fastingErrorEndBeforeStart,
      FastingWindowError.tooLong => l10n.fastingErrorTooLong,
      FastingWindowError.overlaps => l10n.fastingErrorOverlaps,
    };
  }

  /// Date then time picker. Returns null when either is dismissed.
  static Future<DateTime?> pickDateTime(
    BuildContext context, {
    required DateTime initial,
    required DateTime first,
    required DateTime last,
  }) async {
    final clamped = initial.isBefore(first)
        ? first
        : (initial.isAfter(last) ? last : initial);
    final date = await showDatePicker(
      context: context,
      initialDate: clamped,
      firstDate: first,
      lastDate: last,
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(clamped),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
