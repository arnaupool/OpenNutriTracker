import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/fasting/presentation/bloc/fasting_bloc.dart';
import 'package:opennutritracker/features/fasting/presentation/widgets/fasting_format.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Renders only while a fasting session is active. The chip is the home
/// surface's entire participation in fasting — no "start a fast" prompt
/// when dormant, no streak, no encouragement copy, all in line with the
/// rest of #84.
class FastingHomeChip extends StatelessWidget {
  const FastingHomeChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          locator<FastingBloc>()..add(const FastingLoadRequested()),
      child: const _FastingHomeChipView(),
    );
  }
}

class _FastingHomeChipView extends StatelessWidget {
  const _FastingHomeChipView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FastingBloc, FastingState>(
      builder: (context, state) {
        if (state is! FastingActive) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Semantics(
            identifier: 'home-fasting-chip',
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => Navigator.of(context)
                  .pushNamed(NavigationOptions.fastingRoute),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .secondaryContainer
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      // Minutes resolution on the chip; seconds would
                      // twitch every tick.
                      state.hasReachedTarget
                          ? S.of(context).fastingHomeChipReached(
                              FastingFormat.hoursMinutes(state.elapsed),
                            )
                          : S.of(context).fastingHomeChipBody(
                              FastingFormat.hoursMinutes(state.remaining),
                            ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
