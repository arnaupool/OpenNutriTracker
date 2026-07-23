import 'package:flutter/material.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Date-range picker for [DayInfoWidget]'s "repeat day" action — every
/// item in the day keeps its own original meal type at the target
/// date(s), so unlike [CopyDialog] there's no meal-type dropdown here.
class CopyDayDialog extends StatefulWidget {
  final DateTime initialDate;

  const CopyDayDialog({super.key, required this.initialDate});

  @override
  State<CopyDayDialog> createState() => _CopyDayDialogState();
}

class _CopyDayDialogState extends State<CopyDayDialog> {
  late DateTimeRange _selectedRange;

  @override
  void initState() {
    super.initState();
    _selectedRange = DateTimeRange(
      start: widget.initialDate,
      end: widget.initialDate,
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedRange,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      // Fixed day-first format regardless of device locale, same as every
      // other date picker in the app (see onboarding/profile/weight-history).
      locale: const Locale('en', 'GB'),
    );
    if (picked != null) {
      setState(() => _selectedRange = picked);
    }
  }

  String _formatDdMmYyyy(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatRange() {
    final start = _formatDdMmYyyy(_selectedRange.start);
    if (DateUtils.isSameDay(_selectedRange.start, _selectedRange.end)) {
      return start;
    }
    return '$start - ${_formatDdMmYyyy(_selectedRange.end)}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.of(context).copyDayDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            identifier: 'copy-day-dialog-date',
            child: InkWell(
              onTap: _pickDateRange,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(S.of(context).copyDialogDateLabel),
                  const Spacer(),
                  Text(_formatRange()),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_selectedRange);
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
