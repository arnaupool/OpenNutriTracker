import 'package:flutter/material.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// #284: Dialog for setting the weekly weight change rate. The dialog
/// returns one of three [WeeklyWeightGoalResult] cases:
///
/// - [WeeklyWeightGoalCancelled] when the user dismisses or taps Cancel.
///   (This is also what the framework returns from a back-button pop,
///   so callers don't need to special-case `null`.)
/// - [WeeklyWeightGoalCleared] when the user taps Reset, asking to
///   fall back to the overall weight goal (lose / maintain / gain).
/// - [WeeklyWeightGoalSet] with a kg/week value when the user taps OK
///   on a slider position. Negative = lose, positive = gain, zero =
///   maintain.
///
/// The previous shape of this API returned a `double?` and overloaded
/// `double.nan` as a sentinel for "clear". The sealed type makes the
/// intent obvious in the caller's switch and removes a footgun where
/// any caller forgetting to check `isNaN` would silently set the user
/// to a NaN goal.
sealed class WeeklyWeightGoalResult {
  const WeeklyWeightGoalResult();
}

class WeeklyWeightGoalCancelled extends WeeklyWeightGoalResult {
  const WeeklyWeightGoalCancelled();
}

class WeeklyWeightGoalCleared extends WeeklyWeightGoalResult {
  const WeeklyWeightGoalCleared();
}

class WeeklyWeightGoalSet extends WeeklyWeightGoalResult {
  final double kgPerWeek;
  const WeeklyWeightGoalSet(this.kgPerWeek);
}

class SetWeeklyWeightGoalDialog extends StatefulWidget {
  final double? currentGoalKg;
  final bool usesImperialUnits;

  /// The user's current weight (trend weight where available, falling back
  /// to their last logged weight otherwise) — the slider's range is derived
  /// from this rather than a fixed kg figure, so the bound scales with the
  /// person instead of applying the same absolute limit to everyone.
  final double referenceWeightKg;

  const SetWeeklyWeightGoalDialog({
    super.key,
    required this.currentGoalKg,
    required this.usesImperialUnits,
    required this.referenceWeightKg,
  });

  @override
  State<SetWeeklyWeightGoalDialog> createState() =>
      _SetWeeklyWeightGoalDialogState();
}

class _SetWeeklyWeightGoalDialogState extends State<SetWeeklyWeightGoalDialog> {
  // Slider range: ±1% of the user's current weight per week — the commonly
  // cited safe-rate-of-change guideline — rather than a fixed kg figure
  // that would let a 50 kg and a 120 kg user set the same absolute pace.
  static const double _maxRatePct = 0.01;
  static const int _divisions = 8;

  late final double _minKg = -widget.referenceWeightKg * _maxRatePct;
  late final double _maxKg = widget.referenceWeightKg * _maxRatePct;

  late double _selectedKg;

  @override
  void initState() {
    super.initState();
    _selectedKg = widget.currentGoalKg ?? 0.0;
    _selectedKg = _selectedKg.clamp(_minKg, _maxKg);
  }

  double get _displayValue =>
      widget.usesImperialUnits ? _selectedKg * 2.20462 : _selectedKg;

  String _formatBound(double kg) {
    final value = widget.usesImperialUnits ? kg * 2.20462 : kg;
    final sign = value > 0 ? '+' : '';
    final unit = widget.usesImperialUnits
        ? S.of(context).lbsLabel
        : S.of(context).kgLabel;
    return '$sign${value.toStringAsFixed(1)} $unit';
  }

  String get _displayLabel {
    if (_selectedKg == 0.0) return S.of(context).goalMaintainWeight;
    final sign = _displayValue > 0 ? '+' : '';
    final formatted = '$sign${_displayValue.toStringAsFixed(2)}';
    return widget.usesImperialUnits
        ? S.of(context).weeklyWeightGoalLbsPerWeek(formatted)
        : S.of(context).weeklyWeightGoalKgPerWeek(formatted);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.of(context).chooseWeeklyWeightGoalLabel),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_displayLabel, style: Theme.of(context).textTheme.titleMedium),
          Slider(
            min: _minKg,
            max: _maxKg,
            divisions: _divisions,
            value: _selectedKg,
            label: _displayLabel,
            onChanged: (value) => setState(() => _selectedKg = value),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatBound(_minKg),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                _formatBound(_maxKg),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context).weeklyWeightGoalExplanation,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop<WeeklyWeightGoalResult>(const WeeklyWeightGoalCancelled()),
          child: Text(S.of(context).dialogCancelLabel),
        ),
        // Always offer Reset — users need a way to fall back to the
        // overall weight goal (lose / maintain / gain) even if they
        // opened the slider once and never set an explicit weekly rate.
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop<WeeklyWeightGoalResult>(const WeeklyWeightGoalCleared()),
          child: Text(S.of(context).buttonResetLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop<WeeklyWeightGoalResult>(WeeklyWeightGoalSet(_selectedKg)),
          child: Text(S.of(context).dialogOKLabel),
        ),
      ],
    );
  }
}
