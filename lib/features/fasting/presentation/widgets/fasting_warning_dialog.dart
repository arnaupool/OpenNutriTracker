import 'package:flutter/material.dart';
import 'package:opennutritracker/features/fasting/presentation/widgets/fasting_safety_content.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Content warning shown before the fasting timer becomes usable, and again
/// whenever FastingSafety.warningVersion adds information.
///
/// Returns `true` when the user accepts and `false` (or null on barrier
/// dismissal — though the dialog is non-dismissible by default) when they
/// decline. The caller is responsible for routing back when declined and for
/// persisting the acknowledgement when accepted.
class FastingWarningDialog extends StatelessWidget {
  const FastingWarningDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return AlertDialog(
      title: Text(l10n.fastingWarningTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: const SingleChildScrollView(child: FastingSafetyContent()),
      ),
      actions: [
        Semantics(
          identifier: 'fasting-warning-decline',
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.fastingWarningDecline),
          ),
        ),
        Semantics(
          identifier: 'fasting-warning-accept',
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.fastingWarningAccept),
          ),
        ),
      ],
    );
  }
}
