import 'package:flutter/material.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Attribution the BEDCA terms of use require wherever its data is shown.
class BedcaDisclaimer extends StatelessWidget {
  const BedcaDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      S.of(context).bedcaDisclaimer,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            fontStyle: FontStyle.italic,
          ),
    );
  }
}
