import 'package:flutter/material.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Placeholder for the Strategy tab (FP-05). The real dashboard — trend
/// weight vs. scale weight, estimated vs. static TDEE, desired vs.
/// observed weekly rate — is built out in FD-01; this stub only wires up
/// the bottom nav destination and appbar so the tab exists and compiles
/// in the meantime.
class StrategyPage extends StatelessWidget {
  const StrategyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        identifier: 'strategy-placeholder',
        child: Text(
          S.of(context).strategyLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
