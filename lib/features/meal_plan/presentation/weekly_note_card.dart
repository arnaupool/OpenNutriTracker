import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/meal_plan/domain/weekly_note_repository.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// The note of one week at the end of the meal plan. Free text; lines that
/// start with `- [ ]` or `- [x]` show as checkboxes that can be ticked without
/// editing. Every change is saved after a short pause.
class WeeklyNoteCard extends StatefulWidget {
  /// Any day of the week.
  final DateTime week;
  final WeeklyNoteRepository? repository;
  final Duration saveDelay;

  const WeeklyNoteCard({
    super.key,
    required this.week,
    this.repository,
    this.saveDelay = const Duration(milliseconds: 600),
  });

  @override
  State<WeeklyNoteCard> createState() => _WeeklyNoteCardState();
}

class _WeeklyNoteCardState extends State<WeeklyNoteCard> {
  late final WeeklyNoteRepository _repo = widget.repository ?? locator<WeeklyNoteRepository>();
  final _controller = TextEditingController();
  Timer? _saveTimer;
  late String _weekKey;
  bool _editing = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _weekKey = isoWeekKey(widget.week);
    _controller.text = _repo.textOf(_weekKey);
    _editing = _controller.text.isEmpty;
    _repo.listenable().addListener(_onStoreChanged);
  }

  @override
  void didUpdateWidget(covariant WeeklyNoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final key = isoWeekKey(widget.week);
    if (key == _weekKey) return;
    // Another week: write the pending text to the old one first.
    _flush();
    _weekKey = key;
    _controller.text = _repo.textOf(key);
    _editing = _controller.text.isEmpty;
  }

  @override
  void dispose() {
    _repo.listenable().removeListener(_onStoreChanged);
    _flush();
    _controller.dispose();
    super.dispose();
  }

  /// A synced change from another device, while this one has nothing unsaved.
  void _onStoreChanged() {
    if (_dirty || !mounted) return;
    final stored = _repo.textOf(_weekKey);
    if (stored != _controller.text) setState(() => _controller.text = stored);
  }

  void _scheduleSave() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(widget.saveDelay, _flush);
  }

  void _flush() {
    _saveTimer?.cancel();
    if (!_dirty) return;
    _dirty = false;
    _repo.save(_weekKey, _controller.text).catchError((Object _) {});
  }

  void _toggle(int lineIndex) {
    setState(() => _controller.text = toggleChecklistLine(_controller.text, lineIndex));
    _scheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'plan-weekly-note',
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sticky_note_2_outlined, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.weeklyNoteTitle, style: theme.textTheme.titleMedium)),
                  Semantics(
                    identifier: 'plan-note-edit',
                    child: TextButton(
                      onPressed: () => setState(() {
                        if (_editing) _flush();
                        _editing = !_editing;
                      }),
                      child: Text(_editing ? s.weeklyNoteDone : s.weeklyNoteEdit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_editing)
                Semantics(
                  identifier: 'plan-note-field',
                  child: TextField(
                    controller: _controller,
                    minLines: 4,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(hintText: s.weeklyNoteHint, border: const OutlineInputBorder()),
                    onChanged: (_) => _scheduleSave(),
                  ),
                )
              else
                _rendered(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rendered(BuildContext context) {
    final theme = Theme.of(context);
    final lines = parseNote(_controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++)
          if (lines[i].isChecklist)
            InkWell(
              onTap: () => _toggle(i),
              child: Row(
                children: [
                  Semantics(
                    identifier: 'plan-note-check-$i',
                    child: Checkbox(value: lines[i].checked, onChanged: (_) => _toggle(i)),
                  ),
                  Expanded(
                    child: Text(
                      lines[i].text,
                      style: lines[i].checked
                          ? theme.textTheme.bodyMedium?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: theme.colorScheme.onSurfaceVariant,
                            )
                          : theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )
          else if (lines[i].raw.trim().isEmpty)
            const SizedBox(height: 8)
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(lines[i].raw, style: theme.textTheme.bodyMedium),
            ),
      ],
    );
  }
}
