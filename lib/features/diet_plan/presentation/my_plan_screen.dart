import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/diet_plan/data/diet_plan_dbo.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_calc.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_goal_calc.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_usecase.dart';
import 'package:opennutritracker/features/diet_plan/presentation/diet_plan_format.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Settings -> My plan: automatic or manual end date, start date, kilos,
/// pace, pause / resume and the Home countdown switch.
class MyPlanScreen extends StatefulWidget {
  final DietPlanUsecase? usecase;

  const MyPlanScreen({super.key, this.usecase});

  @override
  State<MyPlanScreen> createState() => _MyPlanScreenState();
}

class _MyPlanScreenState extends State<MyPlanScreen> {
  late final DietPlanUsecase _usecase = widget.usecase ?? locator<DietPlanUsecase>();

  // Draft being edited; nothing is stored until Save.
  DietPlanMode _mode = DietPlanMode.auto;
  late DateTime _start;
  late double _kg;
  late double _pace;
  late DateTime _endBase;
  bool _byWeeks = false;
  int _weeks = 12;
  bool _dirty = false;
  bool _loaded = false;
  bool _busy = false;

  DateTime get _today => DietPlanCalc.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _usecase.listenable.addListener(_onStoreChanged);
    _syncDraft();
  }

  @override
  void dispose() {
    _usecase.listenable.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {
      if (!_dirty) {
        _syncDraft();
      } else {
        _loaded = _usecase.plan != null;
      }
    });
  }

  /// Copies the stored plan into the draft.
  void _syncDraft() {
    final plan = _usecase.plan;
    _loaded = plan != null;
    if (plan == null) return;
    _mode = plan.mode;
    _start = plan.startDate;
    _kg = plan.targetLossKg ?? DietPlanGoalCalc.clampLoss(5, plan.startWeightKg);
    _pace = plan.paceKgPerWeek ?? DietPlanCalc.defaultPaceKgPerWeek;
    _endBase = plan.endDate;
    _byWeeks = false;
    _weeks = (DietPlanCalc.totalDays(plan) / 7).ceil().clamp(1, 520);
    _dirty = false;
  }

  /// The stored plan with the draft applied.
  DietPlanDBO _built(DietPlanDBO stored) {
    final base = stored.copyWith(mode: _mode, startDate: _start, targetLossKg: _kg, paceKgPerWeek: _pace);
    switch (_mode) {
      case DietPlanMode.auto:
        return DietPlanCalc.recomputeAuto(base);
      case DietPlanMode.manual:
        return base.copyWith(endDate: _byWeeks ? DietPlanCalc.addDays(_start, _weeks * 7) : _endBase);
    }
  }

  void _edit(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  Future<DateTime?> _pickDate(DateTime initial, DateTime first, DateTime last) => showDatePicker(
    context: context,
    initialDate: initial.isBefore(first) ? first : (initial.isAfter(last) ? last : initial),
    firstDate: first,
    lastDate: last,
  );

  Future<void> _save(DietPlanDBO stored) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    await _usecase.saveAndSync(_built(stored));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _dirty = false;
      _syncDraft();
    });
    messenger.showSnackBar(SnackBar(content: Text(s.myPlanSaved)));
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    await _usecase.startNewPlan();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _syncDraft();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final stored = _usecase.plan;
    return Scaffold(
      appBar: AppBar(title: Text(s.myPlanTitle)),
      body: stored == null || !_loaded ? _buildEmpty(context) : _buildEditor(context, stored),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.myPlanNoPlan, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16.0),
          Semantics(
            identifier: 'my-plan-create',
            child: FilledButton(onPressed: _busy ? null : _create, child: Text(s.myPlanCreate)),
          ),
          const SizedBox(height: 8.0),
          Text(s.myPlanEngineNote, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildEditor(BuildContext context, DietPlanDBO stored) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final today = _today;
    final built = _built(stored);
    final paused = DietPlanCalc.isPaused(stored);
    final maxLoss = DietPlanGoalCalc.maxLossFor(stored.startWeightKg);
    final kg = _kg.clamp(DietPlanCalc.minLossKg, maxLoss).toDouble();
    final end = DietPlanCalc.effectiveEnd(built, today);
    final validEnd = DietPlanCalc.daysBetween(built.startDate, built.endDate) > 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Semantics(
          identifier: 'my-plan-mode',
          child: SegmentedButton<DietPlanMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: DietPlanMode.auto, label: Text(s.myPlanModeAuto)),
              ButtonSegment(value: DietPlanMode.manual, label: Text(s.myPlanModeManual)),
            ],
            selected: {_mode},
            onSelectionChanged: (sel) => _edit(() {
              final next = sel.first;
              if (next == DietPlanMode.manual && _mode == DietPlanMode.auto) {
                // Start from the end the automatic plan showed.
                _endBase = DietPlanCalc.recomputeAuto(_built(stored)).endDate;
                _weeks = (DietPlanCalc.daysBetween(_start, _endBase) / 7).ceil().clamp(1, 520);
              }
              _mode = next;
            }),
          ),
        ),
        if (_mode == DietPlanMode.auto) ...[
          const SizedBox(height: 8.0),
          Text(s.myPlanModeAutoHelp, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 8.0),
        Semantics(
          identifier: 'my-plan-start-date',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.play_circle_outline),
            title: Text(s.myPlanStartDate),
            trailing: Text(DietPlanFormat.date(_start), style: theme.textTheme.titleMedium),
            onTap: () async {
              final picked = await _pickDate(
                _start,
                DietPlanCalc.addDays(today, -365),
                DietPlanCalc.addDays(today, 365),
              );
              if (picked != null) _edit(() => _start = DietPlanCalc.dateOnly(picked));
            },
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.monitor_weight_outlined),
          title: Text(s.myPlanStartWeight),
          trailing: Text(
            '${DietPlanFormat.number(context, stored.startWeightKg)} ${s.kgLabel}',
            style: theme.textTheme.titleMedium,
          ),
        ),
        _stepperRow(
          context,
          idPrefix: 'my-plan-kg',
          label: s.myPlanKgToLose,
          value: '${DietPlanFormat.number(context, kg)} ${s.kgLabel}',
          onMinus: kg > DietPlanCalc.minLossKg ? () => _edit(() => _kg = kg - DietPlanCalc.lossStepKg) : null,
          onPlus: kg < maxLoss ? () => _edit(() => _kg = kg + DietPlanCalc.lossStepKg) : null,
        ),
        if (_mode == DietPlanMode.auto) ...[
          const SizedBox(height: 8.0),
          Text(s.myPlanPace, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8.0),
          Semantics(
            identifier: 'my-plan-pace',
            child: SegmentedButton<double>(
              showSelectedIcon: false,
              segments: [
                for (final p in DietPlanCalc.paceOptions)
                  ButtonSegment<double>(value: p, label: Text(s.dietPlanPaceOption(DietPlanFormat.pace(context, p)))),
              ],
              selected: {DietPlanCalc.paceOptions.contains(_pace) ? _pace : DietPlanCalc.defaultPaceKgPerWeek},
              onSelectionChanged: (sel) => _edit(() => _pace = sel.first),
            ),
          ),
        ] else ...[
          const SizedBox(height: 8.0),
          Semantics(
            identifier: 'my-plan-manual-kind',
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: true, label: Text(s.myPlanByWeeks)),
                ButtonSegment(value: false, label: Text(s.myPlanByDate)),
              ],
              selected: {_byWeeks},
              onSelectionChanged: (sel) => _edit(() {
                if (!sel.first) _endBase = DietPlanCalc.addDays(_start, _weeks * 7);
                _byWeeks = sel.first;
              }),
            ),
          ),
          if (_byWeeks)
            _stepperRow(
              context,
              idPrefix: 'my-plan-weeks',
              label: s.myPlanByWeeks,
              value: s.myPlanWeeksValue(_weeks.toString()),
              onMinus: _weeks > 1 ? () => _edit(() => _weeks -= 1) : null,
              onPlus: _weeks < 520 ? () => _edit(() => _weeks += 1) : null,
            )
          else
            Semantics(
              identifier: 'my-plan-end-date',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined),
                title: Text(s.myPlanEndDate),
                trailing: Text(DietPlanFormat.date(end), style: theme.textTheme.titleMedium),
                onTap: () async {
                  final picked = await _pickDate(
                    end,
                    DietPlanCalc.addDays(_start, 1),
                    DietPlanCalc.addDays(_start, 365 * 10),
                  );
                  if (picked != null) {
                    _edit(() => _endBase = DietPlanCalc.withEffectiveEnd(stored, picked, today).endDate);
                  }
                },
              ),
            ),
        ],
        const SizedBox(height: 16.0),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              s.myPlanEndSummary(DietPlanFormat.date(end), DietPlanCalc.daysLeft(built, today).toString()),
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
        if (_mode == DietPlanMode.auto) ...[
          const SizedBox(height: 8.0),
          Text(s.myPlanEngineNote, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 16.0),
        Semantics(
          identifier: 'my-plan-save',
          child: FilledButton(
            onPressed: _busy || !_dirty || !validEnd ? null : () => _save(stored),
            child: Text(s.buttonSaveLabel),
          ),
        ),
        const Divider(height: 32.0),
        if (paused) ...[Text(s.myPlanPausedNote, style: theme.textTheme.bodyMedium), const SizedBox(height: 8.0)],
        if (stored.status != DietPlanStatus.finished)
          Semantics(
            identifier: paused ? 'my-plan-resume' : 'my-plan-pause',
            child: OutlinedButton.icon(
              icon: Icon(paused ? Icons.play_arrow : Icons.pause),
              label: Text(paused ? s.myPlanResume : s.myPlanPause),
              onPressed: _busy
                  ? null
                  : () async {
                      if (paused) {
                        await _usecase.resume();
                      } else {
                        await _usecase.pause();
                      }
                      // The pause changes only pauses and status; keep any
                      // unsaved edits.
                      if (mounted) setState(() {});
                    },
            ),
          ),
        Semantics(
          identifier: 'my-plan-countdown-switch',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.dietPlanShowCountdown),
            value: stored.showCountdown,
            onChanged: (value) => _usecase.setShowCountdown(value),
          ),
        ),
      ],
    );
  }

  Widget _stepperRow(
    BuildContext context, {
    required String idPrefix,
    required String label,
    required String value,
    required VoidCallback? onMinus,
    required VoidCallback? onPlus,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
        Semantics(
          identifier: '$idPrefix-minus',
          child: IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: onMinus),
        ),
        Text(value, style: theme.textTheme.titleMedium),
        Semantics(
          identifier: '$idPrefix-plus',
          child: IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: onPlus),
        ),
      ],
    );
  }
}
