import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/edit_dialog.dart';
import 'package:opennutritracker/core/utils/calc/calendar_day_calc.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/review/domain/review_calc.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Pushed on phones from Strategy; on desktop the same [ReviewPage] is a
/// side-rail destination.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).reviewTitle)),
      body: const ReviewPage(),
    );
  }
}

enum _ReviewTab { weight, expenditure, adherence, diary }

/// Review views (FAS-03): weight against trend, expenditure, adherence and
/// an editable diary table, over a chosen range, each exportable as CSV.
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: _ReviewTab.values.length, vsync: this);
  ReviewRange _range = ReviewRange.days30;
  AdherencePeriod _period = AdherencePeriod.week;
  bool _loading = true;
  bool _imperial = false;
  int _offsetMinutes = 0;
  List<WeightLogEntity> _weights = [];
  List<TrackedDayEntity> _trackedDays = [];
  List<IntakeEntity> _intakes = [];

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final config = await locator<GetConfigUsecase>().getConfig();
    final weights = await locator<GetWeightLogUsecase>().getAllEntries();
    final trackedDays = await locator<GetTrackedDayUsecase>().getTrackedDaysByRange(
      DateTime(1970),
      DateTime.now().add(const Duration(days: 1)),
    );
    final intakeDbos = await locator<IntakeRepository>().getAllIntakesDBO();
    if (!mounted) return;
    setState(() {
      _imperial = config.usesImperialUnits;
      _offsetMinutes = config.dayStartOffsetTotalMinutes;
      _weights = weights;
      _trackedDays = trackedDays;
      _intakes = intakeDbos.map(IntakeEntity.fromIntakeDBO).toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      _loading = false;
    });
  }

  DateTime get _today => DateTime.now();

  DateTime? get _from => _range.startFor(_today);

  double _w(double kg) => _imperial ? UnitCalc.kgToLbs(kg) : kg;

  String get _wUnit => _imperial ? 'lb' : 'kg';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                identifier: 'review-range',
                child: SegmentedButton<ReviewRange>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: ReviewRange.days7, label: Text(s.reviewRange7)),
                    ButtonSegment(value: ReviewRange.days30, label: Text(s.reviewRange30)),
                    ButtonSegment(value: ReviewRange.days90, label: Text(s.reviewRange90)),
                    ButtonSegment(value: ReviewRange.year, label: Text(s.reviewRangeYear)),
                    ButtonSegment(value: ReviewRange.all, label: Text(s.reviewRangeAll)),
                  ],
                  selected: {_range},
                  onSelectionChanged: (v) => setState(() => _range = v.first),
                ),
              ),
              Semantics(
                identifier: 'review-refresh',
                child: IconButton(tooltip: s.reviewRefresh, icon: const Icon(Icons.refresh), onPressed: _load),
              ),
              Semantics(
                identifier: 'review-export',
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.download_outlined),
                  label: Text(s.reviewExportCsv),
                  onPressed: _loading ? null : _exportCsv,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          identifier: 'review-tabs',
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: s.reviewTabWeight),
              Tab(text: s.reviewTabExpenditure),
              Tab(text: s.reviewTabAdherence),
              Tab(text: s.reviewTabDiary),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabs,
                  children: [_weightTab(context), _expenditureTab(context), _adherenceTab(context), _diaryTab(context)],
                ),
        ),
      ],
    );
  }

  // Weight

  List<ReviewWeightRow> get _weightRows => ReviewCalc.weight(_weights, from: _from, to: _today);

  Widget _weightTab(BuildContext context) {
    final s = S.of(context);
    final rows = _weightRows;
    if (rows.isEmpty) return _empty(context);
    final colors = Theme.of(context).colorScheme;
    return _scroll([
      _ReviewLineChart(
        start: rows.first.day,
        series: [
          _Series(s.reviewChartScale, colors.onSurfaceVariant, [
            for (final r in rows)
              if (r.scaleKg != null) (r.day, _w(r.scaleKg!)),
          ], dotsOnly: true),
          _Series(s.reviewChartTrend, colors.primary, [for (final r in rows) (r.day, _w(r.trendKg))]),
        ],
      ),
      _table(
        context,
        [s.reviewColDate, '${s.reviewColScale} ($_wUnit)', '${s.reviewColTrend} ($_wUnit)', '${s.reviewColWeekChange} ($_wUnit)'],
        [
          for (final r in rows.reversed)
            [
              _date(context, r.day),
              _num(r.scaleKg == null ? null : _w(r.scaleKg!), 1),
              _num(_w(r.trendKg), 1),
              _signed(r.weekChangeKg == null ? null : _w(r.weekChangeKg!)),
            ],
        ],
      ),
    ]);
  }

  // Expenditure

  List<ReviewExpenditureRow> get _expenditureRows =>
      ReviewCalc.expenditure(_weights, _trackedDays, from: _from, to: _today);

  Widget _expenditureTab(BuildContext context) {
    final s = S.of(context);
    final rows = _expenditureRows;
    if (rows.isEmpty) return _empty(context);
    final colors = Theme.of(context).colorScheme;
    return _scroll([
      _ReviewLineChart(
        start: rows.first.day,
        series: [
          _Series(s.reviewChartIntake, colors.tertiary, [
            for (final r in rows)
              if (r.intakeKcal != null) (r.day, r.intakeKcal!),
          ], dotsOnly: true),
          _Series(s.reviewChartExpenditure, colors.primary, [
            for (final r in rows)
              if (r.expenditureKcal != null) (r.day, r.expenditureKcal!),
          ]),
        ],
      ),
      _table(
        context,
        [s.reviewColDate, s.reviewColIntake, s.reviewColGoal, s.reviewColExpenditure, s.reviewColBalance],
        [
          for (final r in rows.reversed)
            [
              _date(context, r.day),
              _num(r.intakeKcal, 0),
              _num(r.goalKcal, 0),
              _num(r.expenditureKcal, 0),
              _signed(
                r.intakeKcal != null && r.expenditureKcal != null ? r.intakeKcal! - r.expenditureKcal! : null,
                digits: 0,
              ),
            ],
        ],
      ),
    ]);
  }

  // Adherence

  List<ReviewAdherenceRow> get _adherenceRows =>
      ReviewCalc.adherence(_trackedDays, _period, from: _from, to: _today);

  String _periodLabel(BuildContext context, DateTime start) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return switch (_period) {
      AdherencePeriod.day => DateFormat.yMMMEd(locale).format(start),
      AdherencePeriod.week => '${DateFormat.yMMMd(locale).format(start)} - ${DateFormat.MMMd(locale).format(CalendarDayCalc.addDays(start, 6))}',
      AdherencePeriod.month => DateFormat.yMMMM(locale).format(start),
    };
  }

  Widget _adherenceTab(BuildContext context) {
    final s = S.of(context);
    final rows = _adherenceRows;
    return _scroll([
      Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          identifier: 'review-adherence-period',
          child: SegmentedButton<AdherencePeriod>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: AdherencePeriod.day, label: Text(s.reviewPeriodDay)),
              ButtonSegment(value: AdherencePeriod.week, label: Text(s.reviewPeriodWeek)),
              ButtonSegment(value: AdherencePeriod.month, label: Text(s.reviewPeriodMonth)),
            ],
            selected: {_period},
            onSelectionChanged: (v) => setState(() => _period = v.first),
          ),
        ),
      ),
      if (rows.isEmpty)
        _empty(context)
      else
        _table(
          context,
          [
            s.reviewColPeriod,
            s.reviewColDays,
            s.reviewColIntake,
            s.reviewColGoal,
            s.reviewColOfGoal,
            s.reviewColProtein,
            s.reviewColCarbs,
            s.reviewColFat,
          ],
          [
            for (final r in rows.reversed)
              [
                _periodLabel(context, r.start),
                '${r.loggedDays}',
                _num(r.kcal, 0),
                _num(r.kcalGoal, 0),
                r.kcalRatio == null ? '' : '${(r.kcalRatio! * 100).round()}%',
                _ofGoal(r.protein, r.proteinGoal),
                _ofGoal(r.carbs, r.carbsGoal),
                _ofGoal(r.fat, r.fatGoal),
              ],
          ],
        ),
    ]);
  }

  String _ofGoal(double value, double? goal) =>
      goal == null ? value.toStringAsFixed(0) : '${value.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)}';

  // Diary

  List<IntakeEntity> get _diaryRows {
    final from = _from;
    return _intakes.where((i) {
      final day = DayBoundaryCalc.logicalDayOfMinutes(i.dateTime, _offsetMinutes);
      return (from == null || !day.isBefore(from)) && !day.isAfter(_today);
    }).toList();
  }

  String _mealLabel(BuildContext context, IntakeTypeEntity type) {
    final s = S.of(context);
    return switch (type) {
      IntakeTypeEntity.breakfast => s.breakfastLabel,
      IntakeTypeEntity.lunch => s.lunchLabel,
      IntakeTypeEntity.dinner => s.dinnerLabel,
      IntakeTypeEntity.snack => s.snackLabel,
    };
  }

  Widget _diaryTab(BuildContext context) {
    final s = S.of(context);
    final rows = _diaryRows;
    if (rows.isEmpty) return _empty(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return _scroll([
      _table(
        context,
        [
          '',
          s.reviewColDate,
          s.reviewColTime,
          s.reviewColMeal,
          s.reviewColFood,
          s.reviewColAmount,
          s.reviewColIntake,
          s.reviewColProtein,
          s.reviewColCarbs,
          s.reviewColFat,
        ],
        [
          for (final i in rows)
            [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    identifier: 'review-diary-edit',
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _editIntake(context, i),
                    ),
                  ),
                  Semantics(
                    identifier: 'review-diary-delete',
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => _deleteIntake(context, i),
                    ),
                  ),
                ],
              ),
              _date(context, DayBoundaryCalc.logicalDayOfMinutes(i.dateTime, _offsetMinutes)),
              DateFormat.Hm(locale).format(i.dateTime),
              _mealLabel(context, i.type),
              i.meal.name ?? '',
              '${_num(i.amount, 0)} ${i.unit}',
              _num(i.totalKcal, 0),
              _num(i.totalProteinsGram, 1),
              _num(i.totalCarbsGram, 1),
              _num(i.totalFatsGram, 1),
            ],
        ],
      ),
    ]);
  }

  Future<void> _editIntake(BuildContext context, IntakeEntity intake) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = S.of(context).itemUpdatedSnackbar;
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => EditDialog(intakeEntity: intake, usesImperialUnits: _imperial),
    );
    if (amount == null) return;
    final day = DayBoundaryCalc.logicalDayOfMinutes(intake.dateTime, _offsetMinutes);
    await locator<CalendarDayBloc>().updateIntakeItem(intake.id, {'amount': amount}, day);
    _refreshOtherScreens();
    await _load();
    messenger.showSnackBar(SnackBar(content: Text(updated)));
  }

  Future<void> _deleteIntake(BuildContext context, IntakeEntity intake) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(intake.meal.name ?? ''),
        content: Text(s.reviewDeleteIntakeBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.dialogCancelLabel)),
          Semantics(
            identifier: 'review-diary-delete-confirm',
            child: TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.dialogDeleteLabel)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final day = DayBoundaryCalc.logicalDayOfMinutes(intake.dateTime, _offsetMinutes);
    await locator<CalendarDayBloc>().deleteIntakeItem(context, intake, day);
    _refreshOtherScreens();
    await _load();
    messenger.showSnackBar(SnackBar(content: Text(s.itemDeletedSnackbar)));
  }

  void _refreshOtherScreens() {
    locator<HomeBloc>().add(const LoadItemsEvent());
    locator<DiaryBloc>().add(const LoadDiaryYearEvent());
    locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
  }

  // CSV

  Future<void> _exportCsv() async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final tab = _ReviewTab.values[_tabs.index];
    final String csv;
    switch (tab) {
      case _ReviewTab.weight:
        csv = ReviewCsv.encode(
          ['date', 'scale_$_wUnit', 'trend_$_wUnit', 'week_change_$_wUnit'],
          [
            for (final r in _weightRows)
              [
                r.day,
                r.scaleKg == null ? null : _w(r.scaleKg!),
                _w(r.trendKg),
                r.weekChangeKg == null ? null : _w(r.weekChangeKg!),
              ],
          ],
        );
      case _ReviewTab.expenditure:
        csv = ReviewCsv.encode(
          ['date', 'eaten_kcal', 'goal_kcal', 'expenditure_kcal'],
          [
            for (final r in _expenditureRows) [r.day, r.intakeKcal, r.goalKcal, r.expenditureKcal],
          ],
        );
      case _ReviewTab.adherence:
        csv = ReviewCsv.encode(
          [
            'period_start',
            'days_logged',
            'kcal',
            'kcal_goal',
            'protein_g',
            'protein_goal_g',
            'carbs_g',
            'carbs_goal_g',
            'fat_g',
            'fat_goal_g',
          ],
          [
            for (final r in _adherenceRows)
              [
                r.start,
                r.loggedDays,
                r.kcal,
                r.kcalGoal,
                r.protein,
                r.proteinGoal,
                r.carbs,
                r.carbsGoal,
                r.fat,
                r.fatGoal,
              ],
          ],
        );
      case _ReviewTab.diary:
        csv = ReviewCsv.encode(
          ['date', 'time', 'meal', 'food', 'amount', 'unit', 'kcal', 'protein_g', 'carbs_g', 'fat_g'],
          [
            for (final i in _diaryRows.reversed)
              [
                DayBoundaryCalc.logicalDayOfMinutes(i.dateTime, _offsetMinutes),
                DateFormat.Hm().format(i.dateTime),
                i.type.name,
                i.meal.name,
                i.amount,
                i.unit,
                i.totalKcal,
                i.totalProteinsGram,
                i.totalCarbsGram,
                i.totalFatsGram,
              ],
          ],
        );
    }
    final from = _from == null ? 'all' : DateFormat('yyyy-MM-dd').format(_from!);
    final to = DateFormat('yyyy-MM-dd').format(_today);
    final saved = await FilePicker.saveFile(
      fileName: 'opennutritracker-${tab.name}-$from-$to.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
    // On the web the browser downloads the file and saveFile returns null.
    if (saved != null || kIsWeb) {
      messenger.showSnackBar(SnackBar(content: Text(s.reviewExported)));
    }
  }

  // Shared bits

  Widget _scroll(List<Widget> children) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      for (final c in children) ...[c, const SizedBox(height: 16)],
    ],
  );

  Widget _empty(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(child: Text(S.of(context).reviewEmpty)),
  );

  Widget _table(BuildContext context, List<String> headers, List<List<Object>> rows) {
    return Semantics(
      identifier: 'review-table',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: Theme.of(context).textTheme.labelLarge,
          columnSpacing: 24,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 44,
          columns: [for (final h in headers) DataColumn(label: Text(h))],
          rows: [
            for (final r in rows)
              DataRow(cells: [for (final c in r) DataCell(c is Widget ? c : Text(c.toString()))]),
          ],
        ),
      ),
    );
  }

  String _date(BuildContext context, DateTime day) =>
      DateFormat.yMMMEd(Localizations.localeOf(context).toLanguageTag()).format(day);

  String _num(double? v, int digits) => v == null ? '' : v.toStringAsFixed(digits);

  String _signed(double? v, {int digits = 1}) {
    if (v == null) return '';
    final text = v.toStringAsFixed(digits);
    return v > 0 ? '+$text' : text;
  }
}

class _Series {
  final String label;
  final Color color;
  final List<(DateTime, double)> points;
  final bool dotsOnly;

  const _Series(this.label, this.color, this.points, {this.dotsOnly = false});
}

/// Day-indexed line chart with a legend; dots for raw readings, a line for
/// smoothed series.
class _ReviewLineChart extends StatelessWidget {
  final DateTime start;
  final List<_Series> series;

  const _ReviewLineChart({required this.start, required this.series});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = [for (final s in series) ...s.points];
    if (all.length < 2) return const SizedBox.shrink();
    final ys = all.map((p) => p.$2);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.15).clamp(0.5, 500.0);
    final days = all.map((p) => CalendarDayCalc.daysBetween(start, p.$1)).reduce((a, b) => a > b ? a : b);
    final span = days < 1 ? 1 : days;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final format = span > 400 ? DateFormat.yMMM(locale) : DateFormat.MMMd(locale);

    return Semantics(
      identifier: 'review-chart',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            children: [
              for (final s in series)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(s.label, style: theme.textTheme.labelMedium),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: span.toDouble(),
                minY: minY - pad,
                maxY: maxY + pad,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      // One decimal on narrow ranges (weight), or
                      // neighbouring labels round to the same number.
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(maxY - minY < 10 ? 1 : 0),
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (span / 5).ceilToDouble().clamp(1, double.infinity),
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          format.format(CalendarDayCalc.addDays(start, value.toInt())),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  for (final s in series)
                    LineChartBarData(
                      spots: [
                        for (final p in s.points) FlSpot(CalendarDayCalc.daysBetween(start, p.$1).toDouble(), p.$2),
                      ],
                      isCurved: !s.dotsOnly,
                      preventCurveOverShooting: true,
                      color: s.dotsOnly ? Colors.transparent : s.color,
                      barWidth: s.dotsOnly ? 0 : 2.5,
                      dotData: FlDotData(
                        show: s.dotsOnly,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(radius: 2.5, color: s.color, strokeWidth: 0),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
