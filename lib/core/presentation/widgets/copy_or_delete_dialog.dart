import 'package:flutter/material.dart';
import 'package:opennutritracker/generated/l10n.dart';

class CopyOrDeleteDialog extends StatelessWidget {
  // Defaults to the activity flow's wording ("Copy to today", still accurate
  // there — activities always copy to today). The intake flow passes
  // copyActionLabel ("Copy") instead, since it now lets the user pick an
  // arbitrary target day via CopyDialog rather than always today.
  final String? copyLabel;

  const CopyOrDeleteDialog({super.key, this.copyLabel});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.of(context).copyOrDeleteTimeDialogTitle),
      content: Text(S.of(context).copyOrDeleteTimeDialogContent),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: Text(
            (copyLabel ?? S.of(context).dialogCopyLabel).toUpperCase(),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: Text(S.of(context).dialogDeleteLabel.toUpperCase()),
        ),
      ],
    );
  }
}
