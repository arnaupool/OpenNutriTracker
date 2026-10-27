import 'package:flutter/material.dart';
import 'package:opennutritracker/features/reminders/data/reminder_dbo.dart';
import 'package:opennutritracker/features/reminders/domain/reminder_rules.dart';
import 'package:opennutritracker/features/reminders/presentation/reminder_format.dart';
import 'package:opennutritracker/features/reminders/presentation/reminder_time_field.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// What the edit sheet asks the screen to do.
enum ReminderSheetAction { save, test, duplicate, delete }

class ReminderSheetResult {
  final ReminderSheetAction action;
  final ReminderDBO reminder;

  const ReminderSheetResult(this.action, this.reminder);
}

/// Bottom sheet that edits one reminder: name (custom only), time, weekdays,
/// channel and, for meals, "skip if already logged".
class ReminderEditSheet extends StatefulWidget {
  final ReminderDBO reminder;

  /// Channels this device can use; push is left out where web push is not available.
  final bool pushAvailable;

  /// Runs inside the Save tap, before anything is awaited: the place to ask
  /// the browser for notification permission, which needs the tap.
  final void Function(ReminderDBO candidate)? onBeforeSave;

  const ReminderEditSheet({super.key, required this.reminder, this.pushAvailable = false, this.onBeforeSave});

  @override
  State<ReminderEditSheet> createState() => _ReminderEditSheetState();
}

class _ReminderEditSheetState extends State<ReminderEditSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.reminder.label);
  late String _time = widget.reminder.time;
  late final Set<int> _days = {...widget.reminder.days};
  late ReminderChannel _channel = widget.reminder.channel;
  late bool _skipIfLogged = widget.reminder.skipIfLogged;

  bool get _editableName => ReminderRules.canRename(widget.reminder);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  ReminderDBO _candidate() => widget.reminder.copyWith(
    label: _editableName ? ReminderRules.clampLabel(_name.text) : widget.reminder.label,
    time: _time,
    days: ([..._days]..sort()),
    channel: _channel,
    skipIfLogged: _skipIfLogged,
  );

  bool get _valid => (!_editableName || ReminderRules.isValidLabel(_name.text)) && _days.isNotEmpty;

  void _pop(ReminderSheetAction action) => Navigator.of(context).pop(ReminderSheetResult(action, _candidate()));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = widget.reminder;
    final body = ReminderFormat.body(context, r);
    final channels = [
      for (final c in ReminderChannel.values)
        if (c != ReminderChannel.push || widget.pushAvailable || r.channel == ReminderChannel.push) c,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ReminderFormat.name(context, r), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_editableName)
              Semantics(
                identifier: 'reminder-edit-name',
                child: TextField(
                  controller: _name,
                  maxLength: ReminderRules.maxLabelLength,
                  decoration: InputDecoration(labelText: s.remindersFieldName),
                  onChanged: (_) => setState(() {}),
                ),
              )
            else if (body != null)
              Text('${s.remindersFieldMessage}: $body', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            ReminderTimeField(
              identifier: 'reminder-edit-time',
              label: s.remindersFieldTime,
              value: _time,
              onChanged: (v) => setState(() => _time = v),
            ),
            const SizedBox(height: 8),
            Text(s.remindersFieldDays),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (var d = 1; d <= 7; d++)
                  Semantics(
                    identifier: 'reminder-edit-day-$d',
                    child: FilterChip(
                      label: Text(ReminderFormat.dayLetter(context, d)),
                      selected: _days.contains(d),
                      showCheckmark: false,
                      onSelected: (on) => setState(() => on ? _days.add(d) : _days.remove(d)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(s.remindersFieldChannel),
            const SizedBox(height: 4),
            Semantics(
              identifier: 'reminder-edit-channel',
              child: SegmentedButton<ReminderChannel>(
                showSelectedIcon: false,
                segments: [
                  for (final c in channels)
                    ButtonSegment(value: c, label: Text(ReminderFormat.channel(context, c), maxLines: 1)),
                ],
                selected: {_channel},
                onSelectionChanged: (v) => setState(() => _channel = v.first),
              ),
            ),
            if (r.type == ReminderType.meal)
              Semantics(
                identifier: 'reminder-edit-skip-logged',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.remindersSkipIfLogged),
                  value: _skipIfLogged,
                  onChanged: (v) => setState(() => _skipIfLogged = v),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Semantics(
                  identifier: 'reminder-edit-test',
                  child: TextButton.icon(
                    icon: const Icon(Icons.send_outlined),
                    label: Text(s.remindersSendTest),
                    onPressed: _valid ? () => _pop(ReminderSheetAction.test) : null,
                  ),
                ),
                Semantics(
                  identifier: 'reminder-edit-duplicate',
                  child: TextButton.icon(
                    icon: const Icon(Icons.copy_outlined),
                    label: Text(s.remindersDuplicate),
                    onPressed: _valid ? () => _pop(ReminderSheetAction.duplicate) : null,
                  ),
                ),
                if (ReminderRules.canDelete(r))
                  Semantics(
                    identifier: 'reminder-edit-delete',
                    child: TextButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: Text(s.dialogDeleteLabel),
                      onPressed: () => _pop(ReminderSheetAction.delete),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Semantics(
                  identifier: 'reminder-edit-cancel',
                  child: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.dialogCancelLabel)),
                ),
                const SizedBox(width: 8),
                Semantics(
                  identifier: 'reminder-edit-save',
                  child: FilledButton(
                    onPressed: _valid
                        ? () {
                            widget.onBeforeSave?.call(_candidate());
                            _pop(ReminderSheetAction.save);
                          }
                        : null,
                    child: Text(s.buttonSaveLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
