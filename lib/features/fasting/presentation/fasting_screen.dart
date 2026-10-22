import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/notification_service.dart';
import 'package:opennutritracker/features/fasting/domain/entity/fasting_session_entity.dart';
import 'package:opennutritracker/features/fasting/domain/fasting_safety.dart';
import 'package:opennutritracker/features/fasting/presentation/bloc/fasting_bloc.dart';
import 'package:opennutritracker/features/fasting/presentation/widgets/fasting_format.dart';
import 'package:opennutritracker/features/fasting/presentation/widgets/fasting_record_dialog.dart';
import 'package:opennutritracker/features/fasting/presentation/widgets/fasting_safety_content.dart';
import 'package:opennutritracker/features/fasting/presentation/widgets/fasting_warning_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';

class FastingScreen extends StatefulWidget {
  const FastingScreen({super.key});

  @override
  State<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends State<FastingScreen> {
  late FastingBloc _bloc;
  int _selectedHours = 16;
  int? _customHours;
  bool _warningHandled = false;

  @override
  void initState() {
    super.initState();
    _bloc = locator<FastingBloc>();
    _bloc.add(const FastingLoadRequested());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  Future<void> _handleWarning(BuildContext context) async {
    if (_warningHandled) return;
    _warningHandled = true;
    final navigator = Navigator.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FastingWarningDialog(),
    );
    if (!mounted) return;
    if (accepted == true) {
      _bloc.add(const FastingWarningAcknowledged());
    } else {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fastingTitle),
        actions: [
          Semantics(
            identifier: 'fasting-safety-info',
            child: IconButton(
              tooltip: l10n.fastingSafetyTooltip,
              icon: const Icon(Icons.health_and_safety_outlined),
              onPressed: () => _showSafetyInfo(context),
            ),
          ),
        ],
      ),
      body: BlocConsumer<FastingBloc, FastingState>(
        bloc: _bloc,
        listenWhen: (prev, curr) {
          // Schedule on enter-Active or when the running session changes
          // (edited start time); cancel on enter-Idle (user ended the fast).
          if (curr is FastingWarningRequired) return true;
          if (curr is FastingActive) {
            return prev is! FastingActive || prev.session != curr.session;
          }
          if (curr is FastingIdle && prev is! FastingIdle) return true;
          return false;
        },
        listener: (context, state) {
          if (state is FastingWarningRequired) {
            _handleWarning(context);
          }
          if (state is FastingActive) {
            _scheduleCompleteNotification(context, state);
          }
          if (state is FastingIdle) {
            _cancelCompleteNotification();
          }
        },
        builder: (context, state) {
          if (state is FastingIdle) {
            return _buildList(context, [
              ..._buildIdle(context, l10n, state),
              ..._buildHistory(context, l10n, state.history, null),
            ]);
          }
          if (state is FastingActive) {
            return _buildList(context, [
              ..._buildActive(context, l10n, state),
              ..._buildHistory(context, l10n, state.history, state.session),
            ]);
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: children,
    );
  }

  List<Widget> _buildIdle(BuildContext context, S l10n, FastingIdle state) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final lastEnded = state.lastEnded;
    return [
      Text(
        l10n.fastingSubtitle,
        style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
      ),
      if (lastEnded != null && lastEnded.duration != null) ...[
        const SizedBox(height: 16),
        Semantics(
          identifier: 'fasting-ended-summary',
          child: Text(
            l10n.fastingEndedSummary(
              FastingFormat.hoursMinutes(lastEnded.duration!),
            ),
            style: textTheme.titleMedium,
          ),
        ),
      ],
      const SizedBox(height: 24),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final h in FastingSafety.presetHours)
            Semantics(
              identifier: 'fasting-preset-${h}h',
              child: ChoiceChip(
                label: Text('${h}h'),
                selected: _selectedHours == h && _customHours == null,
                onSelected: (_) {
                  setState(() {
                    _selectedHours = h;
                    _customHours = null;
                  });
                },
              ),
            ),
          Semantics(
            identifier: 'fasting-preset-custom',
            child: ChoiceChip(
              label: Text(
                _customHours == null
                    ? l10n.fastingPresetCustom
                    : '${_customHours}h',
              ),
              selected: _customHours != null,
              onSelected: (_) => _pickCustomHours(context),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      Center(
        child: Semantics(
          identifier: 'fasting-start',
          child: FilledButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.fastingStart),
            onPressed: () => _start(context),
          ),
        ),
      ),
      const SizedBox(height: 24),
      _notice(context, l10n.fastingStopIfUnwell, Icons.info_outline),
    ];
  }

  Future<void> _start(BuildContext context) async {
    final minutes = (_customHours ?? _selectedHours) * 60;
    if (FastingSafety.needsExtendedConfirmation(minutes)) {
      final confirmed = await _confirmExtended(context);
      if (confirmed != true) return;
    }
    _bloc.add(FastingStartRequested(minutes));
  }

  Future<bool?> _confirmExtended(BuildContext context) {
    final l10n = S.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(l10n.fastingExtendedTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.fastingExtendedBody),
                const SizedBox(height: 16),
                const FastingSafetyContent(includeEatingDisorderNote: false),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.dialogCancelLabel),
          ),
          Semantics(
            identifier: 'fasting-extended-accept',
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.fastingExtendedAccept),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomHours(BuildContext context) async {
    final controller = TextEditingController(
      text: (_customHours ?? _selectedHours).toString(),
    );
    String? error;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final l10n = S.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(l10n.fastingPresetCustom),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                suffixText: l10n.hoursLabel,
                errorText: error,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.dialogCancelLabel),
              ),
              Semantics(
                identifier: 'fasting-custom-confirm',
                child: TextButton(
                  onPressed: () {
                    final v = int.tryParse(controller.text.trim());
                    if (v != null && FastingSafety.isValidTargetHours(v)) {
                      Navigator.of(ctx).pop(v);
                    } else {
                      setDialogState(() {
                        error = l10n.fastingErrorTarget(
                          FastingSafety.maxTargetHours.toString(),
                        );
                      });
                    }
                  },
                  child: Text(l10n.dialogOKLabel),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (result != null) {
      setState(() {
        _customHours = result;
      });
    }
  }

  List<Widget> _buildActive(
    BuildContext context,
    S l10n,
    FastingActive state,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final progress = state.target.inSeconds == 0
        ? 1.0
        : (state.elapsed.inSeconds / state.target.inSeconds).clamp(0.0, 1.0);
    return [
      Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  backgroundColor: colors.surfaceContainerHighest,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    identifier: 'fasting-elapsed',
                    child: Text(
                      FastingFormat.clock(state.elapsed),
                      style: textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.fastingElapsedLabel,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      Center(
        child: Text(
          state.hasReachedTarget
              ? l10n.fastingTargetReached
              : l10n.fastingRemainingValue(FastingFormat.clock(state.remaining)),
          style: textTheme.titleMedium,
        ),
      ),
      if (state.hasReachedTarget)
        Center(
          child: Text(
            l10n.fastingPastTarget(FastingFormat.hoursMinutes(state.pastTarget)),
            style: textTheme.bodyMedium,
          ),
        ),
      Center(
        child: Text(
          l10n.fastingTargetValue(FastingFormat.hoursMinutes(state.target)),
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: Semantics(
          identifier: 'fasting-edit-start',
          child: TextButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(
              l10n.fastingStartedAt(
                FastingFormat.dateTime(context, state.session.startedAt),
              ),
            ),
            onPressed: () => _editStart(context, state),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (state.isStale)
        _notice(context, l10n.fastingOver72Notice, Icons.history, urgent: true)
      else if (state.isExtended)
        _notice(
          context,
          l10n.fastingOver24Notice,
          Icons.warning_amber_rounded,
          urgent: true,
        ),
      _notice(context, l10n.fastingStopIfUnwell, Icons.info_outline),
      const SizedBox(height: 16),
      Semantics(
        identifier: 'fasting-cancel',
        child: FilledButton.tonalIcon(
          icon: const Icon(Icons.restaurant),
          label: Text(l10n.fastingCancel),
          onPressed: () => _confirmEnd(context, state),
        ),
      ),
    ];
  }

  Widget _notice(
    BuildContext context,
    String text,
    IconData icon, {
    bool urgent = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final fg = urgent ? colors.onErrorContainer : colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: urgent
              ? colors.errorContainer
              : colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editStart(BuildContext context, FastingActive state) async {
    final now = DateTime.now();
    final picked = await FastingFormat.pickDateTime(
      context,
      initial: state.session.startedAt,
      first: now.subtract(const Duration(days: 7)),
      last: now,
    );
    if (picked == null || !context.mounted) return;
    final error = FastingSafety.validateWindow(
      start: picked,
      end: null,
      now: DateTime.now(),
      others: state.history,
      ignoreId: state.session.id,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FastingFormat.error(context, error))),
      );
      return;
    }
    _bloc.add(FastingSessionSaved(state.session.copyWith(startedAt: picked)));
  }

  Future<void> _confirmEnd(BuildContext context, FastingActive state) async {
    final l10n = S.of(context);
    final choice = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.fastingEndTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.dialogCancelLabel),
          ),
          Semantics(
            identifier: 'fasting-end-pick',
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.fastingEndPick),
            ),
          ),
          Semantics(
            identifier: 'fasting-cancel-confirm',
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.fastingEndNow),
            ),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice) {
      _bloc.add(const FastingEndRequested());
      return;
    }
    final now = DateTime.now();
    final picked = await FastingFormat.pickDateTime(
      context,
      initial: now,
      first: state.session.startedAt,
      last: now,
    );
    if (picked == null || !context.mounted) return;
    if (!picked.isAfter(state.session.startedAt) || picked.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            FastingFormat.error(
              context,
              picked.isAfter(now)
                  ? FastingWindowError.endInFuture
                  : FastingWindowError.endBeforeStart,
            ),
          ),
        ),
      );
      return;
    }
    _bloc.add(FastingEndRequested(end: picked));
  }

  List<Widget> _buildHistory(
    BuildContext context,
    S l10n,
    List<FastingSessionEntity> history,
    FastingSessionEntity? active,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final lastWeek = history.where((s) => s.startedAt.isAfter(weekAgo)).toList();
    final others = [...history, ?active];
    return [
      const SizedBox(height: 32),
      Row(
        children: [
          Expanded(
            child: Text(l10n.fastingHistoryTitle, style: textTheme.titleLarge),
          ),
          Semantics(
            identifier: 'fasting-add-past',
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.fastingAddPast),
              onPressed: () => _openRecord(context, null, others),
            ),
          ),
        ],
      ),
      if (lastWeek.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.fastingHistorySummary(
              lastWeek.length.toString(),
              FastingFormat.hoursMinutes(_average(lastWeek)),
            ),
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      if (history.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            l10n.fastingHistoryEmpty,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      for (final s in history)
        Semantics(
          identifier: 'fasting-history-${s.id}',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              s.completedAt != null
                  ? Icons.check_circle_outline
                  : Icons.timer_outlined,
              color: colors.onSurfaceVariant,
            ),
            title: Text(FastingFormat.hoursMinutes(s.duration ?? Duration.zero)),
            subtitle: Text(
              '${FastingFormat.dateTime(context, s.startedAt)} → '
              '${FastingFormat.time(context, s.endedAt!)} · '
              '${l10n.fastingTargetValue(FastingFormat.hoursMinutes(s.targetDuration))}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openRecord(
              context,
              s,
              others.where((o) => o.id != s.id).toList(),
            ),
          ),
        ),
    ];
  }

  Duration _average(List<FastingSessionEntity> sessions) {
    final total = sessions.fold<int>(
      0,
      (sum, s) => sum + (s.duration?.inMinutes ?? 0),
    );
    return Duration(minutes: total ~/ sessions.length);
  }

  Future<void> _openRecord(
    BuildContext context,
    FastingSessionEntity? session,
    List<FastingSessionEntity> others,
  ) async {
    final result = await showDialog<FastingRecordResult>(
      context: context,
      builder: (_) => FastingRecordDialog(session: session, others: others),
    );
    switch (result) {
      case FastingRecordSaved(:final session):
        _bloc.add(FastingSessionSaved(session));
      case FastingRecordDeleted(:final id):
        _bloc.add(FastingSessionDeleted(id));
      case null:
        break;
    }
  }

  Future<void> _showSafetyInfo(BuildContext context) {
    final l10n = S.of(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.fastingSafetyTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: const SingleChildScrollView(child: FastingSafetyContent()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.dialogCloseLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _scheduleCompleteNotification(
    BuildContext context,
    FastingActive state,
  ) async {
    final notificationService = locator<NotificationService>();
    final when = state.session.startedAt.add(state.session.targetDuration);
    if (!when.isAfter(DateTime.now())) {
      await notificationService.cancelFastingComplete();
      return;
    }
    final permitted = await notificationService.requestPermission();
    if (!permitted) return;
    if (!context.mounted) return;
    final l10n = S.of(context);
    await notificationService.scheduleFastingComplete(
      when: when,
      title: l10n.fastingNotificationCompleteTitle,
      body: l10n.fastingNotificationCompleteBody,
      channelName: l10n.fastingNotificationChannelName,
      channelDescription: l10n.fastingNotificationChannelDescription,
    );
  }

  Future<void> _cancelCompleteNotification() async {
    await locator<NotificationService>().cancelFastingComplete();
  }
}
