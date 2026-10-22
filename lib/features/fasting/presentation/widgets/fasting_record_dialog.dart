import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/features/fasting/domain/entity/fasting_session_entity.dart';
import 'package:opennutritracker/features/fasting/domain/fasting_safety.dart';
import 'package:opennutritracker/features/fasting/presentation/widgets/fasting_format.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// What the record dialog hands back: a session to store, or a delete.
sealed class FastingRecordResult {
  const FastingRecordResult();
}

class FastingRecordSaved extends FastingRecordResult {
  final FastingSessionEntity session;

  const FastingRecordSaved(this.session);
}

class FastingRecordDeleted extends FastingRecordResult {
  final String id;

  const FastingRecordDeleted(this.id);
}

/// Adds a past fast or edits / deletes one from the history. Validates the
/// window against the clock and the user's other sessions before closing,
/// so the user sees why a save is refused.
class FastingRecordDialog extends StatefulWidget {
  /// The session being edited; null to add a new one.
  final FastingSessionEntity? session;

  /// Every other stored session, the running one included, for the overlap
  /// check.
  final List<FastingSessionEntity> others;

  const FastingRecordDialog({super.key, this.session, required this.others});

  @override
  State<FastingRecordDialog> createState() => _FastingRecordDialogState();
}

class _FastingRecordDialogState extends State<FastingRecordDialog> {
  late DateTime _start;
  late DateTime _end;
  late final TextEditingController _target;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    final now = DateTime.now();
    _end = s?.endedAt ?? DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _start = s?.startedAt ?? _end.subtract(const Duration(hours: 16));
    _target = TextEditingController(
      text: ((s?.targetDurationMinutes ?? 16 * 60) / 60).round().toString(),
    );
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final now = DateTime.now();
    final picked = await FastingFormat.pickDateTime(
      context,
      initial: start ? _start : _end,
      first: now.subtract(const Duration(days: 730)),
      last: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
      _error = null;
    });
  }

  void _save() {
    final l10n = S.of(context);
    final hours = int.tryParse(_target.text.trim());
    if (hours == null || !FastingSafety.isValidTargetHours(hours)) {
      setState(() => _error =
          l10n.fastingErrorTarget(FastingSafety.maxTargetHours.toString()));
      return;
    }
    final error = FastingSafety.validateWindow(
      start: _start,
      end: _end,
      now: DateTime.now(),
      others: widget.others,
      ignoreId: widget.session?.id,
    );
    if (error != null) {
      setState(() => _error = FastingFormat.error(context, error));
      return;
    }
    final session = FastingSessionEntity(
      id: widget.session?.id ?? IdGenerator.getUniqueID(),
      startedAt: _start,
      targetDurationMinutes: hours * 60,
    ).endedAtTime(_end);
    Navigator.of(context).pop(FastingRecordSaved(session));
  }

  Future<void> _delete() async {
    final l10n = S.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.fastingDeleteTitle),
        content: Text(l10n.fastingDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.dialogCancelLabel),
          ),
          Semantics(
            identifier: 'fasting-delete-confirm',
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.dialogDeleteLabel),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      Navigator.of(context).pop(FastingRecordDeleted(widget.session!.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final colors = Theme.of(context).colorScheme;
    final editing = widget.session != null;
    final length = _end.difference(_start);
    return AlertDialog(
      title: Text(editing ? l10n.fastingRecordEditTitle : l10n.fastingRecordAddTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              identifier: 'fasting-record-start',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_arrow_outlined),
                title: Text(l10n.fastingRecordStart),
                subtitle: Text(FastingFormat.dateTime(context, _start)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () => _pick(start: true),
              ),
            ),
            Semantics(
              identifier: 'fasting-record-end',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.stop_outlined),
                title: Text(l10n.fastingRecordEnd),
                subtitle: Text(FastingFormat.dateTime(context, _end)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () => _pick(start: false),
              ),
            ),
            if (!length.isNegative)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(FastingFormat.hoursMinutes(length)),
              ),
            Semantics(
              identifier: 'fasting-record-target',
              child: TextField(
                controller: _target,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.fastingRecordTarget,
                  suffixText: l10n.hoursLabel,
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
      ),
      actions: [
        if (editing)
          Semantics(
            identifier: 'fasting-record-delete',
            child: TextButton(
              onPressed: _delete,
              child: Text(l10n.dialogDeleteLabel),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.dialogCancelLabel),
        ),
        Semantics(
          identifier: 'fasting-record-save',
          child: FilledButton(
            onPressed: _save,
            child: Text(l10n.buttonSaveLabel),
          ),
        ),
      ],
    );
  }
}
