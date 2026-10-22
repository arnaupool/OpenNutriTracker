import 'package:opennutritracker/features/fasting/domain/entity/fasting_session_entity.dart';

/// Why a fasting window (a start and an optional end) can't be stored.
enum FastingWindowError { startInFuture, endInFuture, endBeforeStart, tooLong, overlaps }

/// Health limits for the fasting timer, kept in one place so the screen, the
/// bloc and the tests agree on them.
///
/// Sources for the warning copy and the 24 h threshold:
///   * Washington University Physicians, "A fast guide to intermittent
///     fasting": not for people who are pregnant or breastfeeding, under 18,
///     with an eating disorder or type 1 diabetes; type 2 diabetes only under
///     a doctor's supervision.
///   * Bastyr University, "5 times you should avoid intermittent fasting":
///     blood-sugar swings and hypoglycaemia risk with diabetes, higher needs
///     in pregnancy and growth, and the trigger risk for eating disorders.
///   * Fasts beyond 24 h add dehydration, electrolyte and refeeding risks and
///     are commonly advised only with medical supervision.
class FastingSafety {
  /// Bumped whenever the content warning gains information the user must
  /// see; a stored acknowledgement below this version shows it again.
  static const int warningVersion = 2;

  /// Everyday intermittent-fasting windows. Nothing over 24 h is offered as
  /// a one-tap preset.
  static const List<int> presetHours = [12, 14, 16, 18, 20];

  /// Targets above this need an explicit confirmation that a doctor is
  /// supervising the fast.
  static const int extendedFastHours = 24;

  /// Hard cap for a target the timer will run towards.
  static const int maxTargetHours = 72;

  /// Sanity cap for a stored record (a typo in the date, a session left
  /// open for weeks). Longer records are rejected rather than stored.
  static const int maxRecordHours = 7 * 24;

  static bool isValidTargetHours(int hours) => hours >= 1 && hours <= maxTargetHours;

  static bool needsExtendedConfirmation(int targetMinutes) =>
      targetMinutes > extendedFastHours * 60;

  /// Validates a window against the clock and the user's other sessions.
  /// [end] null means the session is still running, so it extends to [now].
  /// [ignoreId] is the session being edited, which must not collide with
  /// itself.
  static FastingWindowError? validateWindow({
    required DateTime start,
    required DateTime? end,
    required DateTime now,
    required Iterable<FastingSessionEntity> others,
    String? ignoreId,
  }) {
    if (start.isAfter(now)) return FastingWindowError.startInFuture;
    if (end != null && end.isAfter(now)) return FastingWindowError.endInFuture;
    final effectiveEnd = end ?? now;
    if (end != null && !end.isAfter(start)) {
      return FastingWindowError.endBeforeStart;
    }
    if (effectiveEnd.difference(start) > const Duration(hours: maxRecordHours)) {
      return FastingWindowError.tooLong;
    }
    for (final other in others) {
      if (other.id == ignoreId) continue;
      final otherEnd = other.endedAt ?? now;
      if (start.isBefore(otherEnd) && other.startedAt.isBefore(effectiveEnd)) {
        return FastingWindowError.overlaps;
      }
    }
    return null;
  }
}
