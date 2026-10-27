import 'package:flutter/material.dart';
import 'package:opennutritracker/features/reminders/domain/reminder_rules.dart';

/// An `HH:MM` time picked with an hour and a minute dropdown, minutes in
/// [ReminderRules.timeStepMinutes] steps.
class ReminderTimeField extends StatelessWidget {
  final String identifier;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const ReminderTimeField({
    super.key,
    required this.identifier,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    // A time that is not on a step (older data) shows at its nearest step.
    final minute = int.tryParse(parts.last) ?? 0;
    final snapped = ReminderRules.snapTime(hour, minute).split(':');
    final h = int.parse(snapped.first);
    final m = int.parse(snapped.last);
    return Row(
      children: [
        Expanded(child: Text(label)),
        Semantics(
          identifier: '$identifier-hour',
          child: DropdownButton<int>(
            value: h,
            items: [for (var i = 0; i < 24; i++) DropdownMenuItem(value: i, child: Text(i.toString().padLeft(2, '0')))],
            onChanged: (v) {
              if (v != null) onChanged(ReminderRules.formatTime(v, m));
            },
          ),
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text(':')),
        Semantics(
          identifier: '$identifier-minute',
          child: DropdownButton<int>(
            value: m,
            items: [
              for (var i = 0; i < 60; i += ReminderRules.timeStepMinutes)
                DropdownMenuItem(value: i, child: Text(i.toString().padLeft(2, '0'))),
            ],
            onChanged: (v) {
              if (v != null) onChanged(ReminderRules.formatTime(h, v));
            },
          ),
        ),
      ],
    );
  }
}
