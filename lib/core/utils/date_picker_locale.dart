import 'package:flutter/widgets.dart';

/// Locale for the Material date pickers.
///
/// The pickers used to be pinned to en_GB so English users got a day-first
/// date and a Monday-first week instead of the US layout. Pinning it for
/// everyone also put the picker in English for every other language, so the
/// pin now applies only when the app itself is in English; any other
/// language keeps the app's own locale (already day-first).
Locale? datePickerLocale(BuildContext context) {
  final current = Localizations.maybeLocaleOf(context);
  if (current == null || current.languageCode == 'en') return const Locale('en', 'GB');
  return null;
}
