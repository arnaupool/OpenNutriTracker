import 'package:flutter/material.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Result of [CopyDialog]: the chosen meal type and target day range.
/// [startDate] and [endDate] are equal for a single-day copy — callers
/// that only ever handled one day can keep doing so unconditionally by
/// iterating the (inclusive) range, which collapses to exactly one
/// iteration when the two dates match.
typedef CopyDialogResult = (
  AddMealType mealType,
  DateTime startDate,
  DateTime endDate,
);

class CopyDialog extends StatefulWidget {
  final AddMealType initialValue;
  final DateTime initialDate;

  const CopyDialog({
    super.key,
    required this.initialValue,
    required this.initialDate,
  });
  @override
  State<StatefulWidget> createState() {
    return CopyDialogState();
  }
}

class CopyDialogState extends State<CopyDialog> {
  late AddMealType _selectedValue;
  late DateTime _selectedDate;
  bool _isRange = false;
  late DateTime _endDate;

  AddMealType get selectedMealType => _selectedValue;
  DateTime get selectedDate => _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue;
    _selectedDate = widget.initialDate;
    _endDate = widget.initialDate;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      // Fixed day-first format regardless of device locale, same as every
      // other date picker in the app (see onboarding/profile/weight-history).
      locale: const Locale('en', 'GB'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        // The end date can never precede the start date — nudge it
        // forward rather than leaving an invalid range silently.
        if (_endDate.isBefore(_selectedDate)) {
          _endDate = _selectedDate;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _selectedDate,
      lastDate: DateTime(2100),
      locale: const Locale('en', 'GB'),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  String _formatDdMmYyyy(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.of(context).copyDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<AddMealType>(
            value: _selectedValue,
            onChanged: (AddMealType? addMealType) {
              if (addMealType != null) {
                setState(() {
                  _selectedValue = addMealType;
                });
              }
            },
            items: AddMealType.values.map((AddMealType addMealType) {
              return DropdownMenuItem(
                value: addMealType,
                child: Text(addMealType.getTypeName(context)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Semantics(
            identifier: 'copy-dialog-date',
            child: InkWell(
              onTap: _pickDate,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(S.of(context).copyDialogDateLabel),
                  const Spacer(),
                  Text(_formatDdMmYyyy(_selectedDate)),
                ],
              ),
            ),
          ),
          Semantics(
            identifier: 'copy-dialog-range-toggle',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(S.of(context).copyDialogRangeToggleLabel),
              value: _isRange,
              onChanged: (value) => setState(() => _isRange = value),
            ),
          ),
          if (_isRange)
            Semantics(
              identifier: 'copy-dialog-end-date',
              child: InkWell(
                onTap: _pickEndDate,
                child: Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(S.of(context).copyDialogEndDateLabel),
                    const Spacer(),
                    Text(_formatDdMmYyyy(_endDate)),
                  ],
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop((
              _selectedValue,
              _selectedDate,
              _isRange ? _endDate : _selectedDate,
            ));
          },
          child: Text(S.of(context).dialogOKLabel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(S.of(context).dialogCancelLabel),
        ),
      ],
    );
  }
}
