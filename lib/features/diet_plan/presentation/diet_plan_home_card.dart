import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/diet_plan/data/diet_plan_dbo.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_calc.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_usecase.dart';
import 'package:opennutritracker/features/diet_plan/presentation/diet_plan_format.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Home: days left, end date, progress bar and the 7-day-average weight line
/// of the diet plan, with the paused, finished, goal-reached and stalled
/// states. Hidden without a plan or with the countdown switched off. Tap
/// opens My plan.
class DietPlanHomeCard extends StatefulWidget {
  final DietPlanUsecase? usecase;

  /// Clock, replaceable in tests.
  final DateTime Function()? now;

  /// Called for "My plan"; defaults to pushing the route.
  final VoidCallback? onOpenPlan;

  const DietPlanHomeCard({super.key, this.usecase, this.now, this.onOpenPlan});

  @override
  State<DietPlanHomeCard> createState() => _DietPlanHomeCardState();
}

class _DietPlanHomeCardState extends State<DietPlanHomeCard> {
  late final DietPlanUsecase _usecase = widget.usecase ?? locator<DietPlanUsecase>();

  List<WeightPoint> _points = const [];
  bool _imperial = false;
  Timer? _midnight;
  StreamSubscription<dynamic>? _homeSub;
  bool _busy = false;
  late DateTime _today = DietPlanCalc.dateOnly(_now());

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _usecase.listenable.addListener(_onPlanChanged);
    if (widget.usecase == null && locator.isRegistered<HomeBloc>()) {
      // A new weigh-in or a day change reloads Home; follow it.
      _homeSub = locator<HomeBloc>().stream.listen((_) => _load());
    }
    _scheduleMidnight();
    _load();
  }

  @override
  void dispose() {
    _usecase.listenable.removeListener(_onPlanChanged);
    _homeSub?.cancel();
    _midnight?.cancel();
    super.dispose();
  }

  void _onPlanChanged() {
    if (mounted) setState(() {});
  }

  /// Refreshes at the next local midnight, then re-arms.
  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = _now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now) + const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _today = DietPlanCalc.dateOnly(_now()));
      _scheduleMidnight();
      _load();
    });
  }

  Future<void> _load() async {
    final points = await _usecase.weightPoints();
    var imperial = _imperial;
    if (locator.isRegistered<ConfigRepository>()) {
      imperial = (await locator<ConfigRepository>().getConfig()).usesImperialUnits;
    }
    if (!mounted) return;
    setState(() {
      _points = points;
      _imperial = imperial;
      _today = DietPlanCalc.dateOnly(_now());
    });
  }

  void _openPlan() {
    final callback = widget.onOpenPlan;
    if (callback != null) {
      callback();
    } else {
      Navigator.of(context).pushNamed(NavigationOptions.myPlanRoute);
    }
  }

  String _weight(double kgValue, {bool signed = false, bool negate = false}) {
    final s = S.of(context);
    final value = _imperial ? UnitCalc.kgToLbs(kgValue) : kgValue;
    final unit = _imperial ? s.lbsLabel : s.kgLabel;
    final text = DietPlanFormat.compact(context, value.abs());
    if (!signed || value.abs() < 0.05) return '$text $unit';
    final sign = (negate ? -value : value) < 0 ? '-' : '+';
    return '$sign$text $unit';
  }

  Future<void> _extend() async {
    final plan = _usecase.plan;
    if (plan == null) return;
    final picked = await showDatePicker(
      context: context,
      helpText: S.of(context).myPlanEndDate,
      initialDate: DietPlanCalc.addDays(_today, 28),
      firstDate: DietPlanCalc.addDays(_today, 1),
      lastDate: DietPlanCalc.addDays(_today, 365 * 10),
    );
    if (picked != null) await _usecase.extendTo(picked, _now());
  }

  Future<void> _newPlan() async {
    setState(() => _busy = true);
    await _usecase.startNewPlan(_now());
    if (!mounted) return;
    setState(() => _busy = false);
    _openPlan();
  }

  Future<void> _maintenance() async {
    final messenger = ScaffoldMessenger.of(context);
    final message = S.of(context).homePlanMaintenanceDone;
    setState(() => _busy = true);
    await _usecase.switchToMaintenance();
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final plan = _usecase.plan;
    if (plan == null || !plan.showCountdown) return const SizedBox.shrink();
    final s = S.of(context);
    final theme = Theme.of(context);
    final today = _today;
    final average = DietPlanCalc.windowAverage(_points, today);
    final reached = plan.status != DietPlanStatus.finished && DietPlanCalc.goalReached(plan, average);
    final paused = DietPlanCalc.isPaused(plan);
    final finished = DietPlanCalc.isFinished(plan, today);

    String title;
    Widget? body;
    var showEndActions = false;
    var showProgress = false;
    if (reached) {
      title = s.homePlanReachedTitle;
      body = Text(s.homePlanReachedBody, style: theme.textTheme.bodyMedium);
      showEndActions = true;
    } else if (paused) {
      title = s.homePlanPaused;
    } else if (finished) {
      title = s.homePlanFinishedTitle;
      showEndActions = true;
    } else {
      final left = DietPlanCalc.daysLeft(plan, today);
      title = left <= 0 ? s.homePlanLastDay : (left == 1 ? s.homePlanOneDayLeft : s.homePlanDaysLeft(left.toString()));
      showProgress = true;
    }

    final stalled = !reached && !paused && !finished && DietPlanCalc.isStalled(plan, today, _points);
    final lost = DietPlanCalc.lostKg(plan, average);
    final end = DietPlanCalc.effectiveEnd(plan, today);
    final targetLoss = plan.targetLossKg;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Semantics(
            identifier: 'home-diet-plan-card',
            child: Card(
              clipBehavior: Clip.antiAlias,
              margin: EdgeInsets.zero,
              child: InkWell(
                onTap: _openPlan,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.flag_outlined),
                          const SizedBox(width: 12),
                          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                          if (!paused) Text(s.homePlanEnd(DietPlanFormat.date(end)), style: theme.textTheme.bodyMedium),
                        ],
                      ),
                      if (body != null) ...[const SizedBox(height: 8), body],
                      if (showProgress) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: DietPlanCalc.progress(plan, today),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                      if (lost != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          targetLoss != null
                              ? s.homePlanWeightLine(_weight(lost, signed: true, negate: true), _weight(targetLoss))
                              : s.homePlanWeightChange(_weight(lost, signed: true, negate: true)),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      if (paused) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Semantics(
                            identifier: 'home-diet-plan-resume',
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      await _usecase.resume(_now());
                                    },
                              child: Text(s.myPlanResume),
                            ),
                          ),
                        ),
                      ],
                      if (showEndActions) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Semantics(
                              identifier: 'home-diet-plan-extend',
                              child: OutlinedButton(onPressed: _busy ? null : _extend, child: Text(s.homePlanExtend)),
                            ),
                            Semantics(
                              identifier: 'home-diet-plan-new',
                              child: OutlinedButton(onPressed: _busy ? null : _newPlan, child: Text(s.homePlanNewPlan)),
                            ),
                            Semantics(
                              identifier: 'home-diet-plan-maintenance',
                              child: FilledButton(
                                onPressed: _busy ? null : _maintenance,
                                child: Text(s.homePlanMaintenance),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (stalled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.trending_flat),
                          const SizedBox(width: 12),
                          Expanded(child: Text(s.homePlanStalledTitle, style: theme.textTheme.titleMedium)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(s.homePlanStalledBody, style: theme.textTheme.bodyMedium),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Semantics(
                          identifier: 'home-diet-plan-stalled-adjust',
                          child: TextButton(onPressed: _openPlan, child: Text(s.homePlanStalledAction)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
