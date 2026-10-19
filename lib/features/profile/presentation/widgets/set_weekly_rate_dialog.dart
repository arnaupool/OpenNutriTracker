import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/goal_explanation.dart';
import 'package:opennutritracker/core/utils/calc/goal_rate_calc.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Picks the lose/gain pace as a % of body weight per week (FM-14), the
/// way MacroFactor expresses goal rates. Returns the chosen % from
/// `showDialog`, or null on cancel.
class SetWeeklyRateDialog extends StatefulWidget {
  final double initialRatePct;

  const SetWeeklyRateDialog({super.key, required this.initialRatePct});

  @override
  State<SetWeeklyRateDialog> createState() => _SetWeeklyRateDialogState();
}

class _SetWeeklyRateDialogState extends State<SetWeeklyRateDialog> {
  late double _ratePct;

  @override
  void initState() {
    super.initState();
    _ratePct = widget.initialRatePct.clamp(
      GoalRateCalc.minRatePct,
      GoalRateCalc.maxRatePct,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final divisions =
        ((GoalRateCalc.maxRatePct - GoalRateCalc.minRatePct) /
                GoalRateCalc.ratePctStep)
            .round();
    return AlertDialog(
      title: Text(s.profileWeeklyRateLabel),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.weeklyRateDialogDescription),
          const SizedBox(height: 16),
          Text(
            s.profileWeeklyRateValue(formatRatePct(_ratePct)),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Semantics(
            identifier: 'weekly-rate-slider',
            child: Slider(
              value: _ratePct,
              min: GoalRateCalc.minRatePct,
              max: GoalRateCalc.maxRatePct,
              divisions: divisions,
              label: '${formatRatePct(_ratePct)}%',
              onChanged: (v) => setState(
                () => _ratePct = (v / GoalRateCalc.ratePctStep).round() *
                    GoalRateCalc.ratePctStep,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.dialogCancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ratePct),
          child: Text(s.dialogOKLabel),
        ),
      ],
    );
  }
}
