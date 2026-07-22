import 'package:flutter/material.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// FR-07: a third choice alongside copy/delete — copy to the chosen date
/// and then delete the original. Only intake items (which support an
/// arbitrary target date via [CopyDialog]) offer this; activities still
/// only ever copy to today, so their flow keeps [showMoveOption] off.
enum CopyOrDeleteAction { copy, move, delete }

class CopyOrDeleteDialog extends StatelessWidget {
  // Defaults to the activity flow's wording ("Copy to today", still accurate
  // there — activities always copy to today). The intake flow passes
  // copyActionLabel ("Copy") instead, since it now lets the user pick an
  // arbitrary target day via CopyDialog rather than always today.
  final String? copyLabel;
  final bool showMoveOption;

  const CopyOrDeleteDialog({
    super.key,
    this.copyLabel,
    this.showMoveOption = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.of(context).copyOrDeleteTimeDialogTitle),
      content: Text(S.of(context).copyOrDeleteTimeDialogContent),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(CopyOrDeleteAction.copy);
          },
          child: Text(
            (copyLabel ?? S.of(context).dialogCopyLabel).toUpperCase(),
          ),
        ),
        if (showMoveOption)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(CopyOrDeleteAction.move);
            },
            child: Text(S.of(context).moveActionLabel.toUpperCase()),
          ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(CopyOrDeleteAction.delete);
          },
          child: Text(S.of(context).dialogDeleteLabel.toUpperCase()),
        ),
      ],
    );
  }
}
