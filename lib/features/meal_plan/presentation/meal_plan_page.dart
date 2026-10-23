import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/utils/calc/calendar_day_calc.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_data_source.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_entry_dbo.dart';
import 'package:opennutritracker/features/meal_plan/domain/log_meal_plan_usecase.dart';
import 'package:opennutritracker/features/meal_plan/domain/meal_plan_calc.dart';
import 'package:opennutritracker/features/review/domain/review_calc.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Pushed on phones from the Diary app bar; on desktop the same
/// [MealPlanPage] is a side-rail destination.
class MealPlanScreen extends StatelessWidget {
  const MealPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).planTitle)),
      body: const MealPlanPage(),
    );
  }
}

/// Day goal the plan is compared with: the day's own goal once it has been
/// tracked, otherwise today's goal.
class _DayGoal {
  final double kcal;
  final double? protein;
  final double? carbs;
  final double? fat;

  const _DayGoal(this.kcal, this.protein, this.carbs, this.fat);
}

/// Weekly meal plan (FAS-04): plan foods and recipes per day and meal,
/// compare each day with its goal, get the week's shopping list, and log a
/// day's plan into the diary in one tap.
class MealPlanPage extends StatefulWidget {
  const MealPlanPage({super.key});

  @override
  State<MealPlanPage> createState() => _MealPlanPageState();
}

class _MealPlanPageState extends State<MealPlanPage> {
  final MealPlanDataSource _plan = locator<MealPlanDataSource>();
  late DateTime _weekStart = _mondayOf(DateTime.now());
  List<MealPlanEntryDBO> _entries = [];
  Map<DateTime, _DayGoal> _goals = {};
  _DayGoal? _defaultGoal;
  bool _loading = true;

  static DateTime _mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return CalendarDayCalc.addDays(day, -(day.weekday - DateTime.monday));
  }

  List<DateTime> get _days => [for (var i = 0; i < 7; i++) CalendarDayCalc.addDays(_weekStart, i)];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final weekEnd = CalendarDayCalc.addDays(_weekStart, 6);
    final entries = _plan.entriesBetween(_weekStart, weekEnd);
    final tracked = await locator<GetTrackedDayUsecase>().getTrackedDaysByRange(
      _weekStart,
      CalendarDayCalc.addDays(weekEnd, 1),
    );
    _defaultGoal ??= await _currentGoal();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _goals = {
        for (final d in tracked)
          DateTime(d.day.year, d.day.month, d.day.day): _DayGoal(d.calorieGoal, d.proteinGoal, d.carbsGoal, d.fatGoal),
      };
      _loading = false;
    });
  }

  Future<_DayGoal> _currentGoal() async {
    final kcal = await locator<GetKcalGoalUsecase>().getKcalGoal();
    final macros = locator<GetMacroGoalUsecase>();
    return _DayGoal(
      kcal,
      await macros.getProteinsGoal(kcal),
      await macros.getCarbsGoal(kcal),
      await macros.getFatsGoal(kcal),
    );
  }

  void _moveWeek(int weeks) {
    setState(() {
      _weekStart = CalendarDayCalc.addDays(_weekStart, 7 * weeks);
      _loading = true;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Semantics(
                identifier: 'plan-prev-week',
                child: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _moveWeek(-1)),
              ),
              Text(
                s.planWeekOf(DateFormat.yMMMd(locale).format(_weekStart)),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Semantics(
                identifier: 'plan-next-week',
                child: IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _moveWeek(1)),
              ),
              Semantics(
                identifier: 'plan-this-week',
                child: TextButton(
                  onPressed: () {
                    _weekStart = _mondayOf(DateTime.now());
                    _moveWeek(0);
                  },
                  child: Text(s.planThisWeek),
                ),
              ),
              Semantics(
                identifier: 'plan-shopping-list',
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: Text(s.planShoppingList),
                  onPressed: _loading ? null : _showShoppingList,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [for (final d in _days) SizedBox(width: 340, child: _dayCard(context, d))],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _dayCard(BuildContext context, DateTime day) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final entries = _entries.where((e) => DateUtils.isSameDay(e.day, day)).toList();
    final totals = MealPlanCalc.totals(entries);
    final goal = _goals[day] ?? _defaultGoal;
    final pending = entries.where((e) => e.loggedAt == null).length;
    final today = DateUtils.dateOnly(DateTime.now());
    final isToday = DateUtils.isSameDay(day, today);
    return Card(
      shape: isToday
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat.MMMEd(locale).format(day), style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            if (goal != null) ...[
              Text(
                s.planGoalValue(totals.kcal.round().toString(), goal.kcal.round().toString()),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: goal.kcal <= 0 ? 0 : (totals.kcal / goal.kcal).clamp(0.0, 1.0),
                color: totals.kcal > goal.kcal * 1.1 ? theme.colorScheme.error : null,
              ),
              const SizedBox(height: 4),
              Text(
                '${s.reviewColProtein} ${_macro(totals.protein, goal.protein)} · '
                '${s.reviewColCarbs} ${_macro(totals.carbs, goal.carbs)} · '
                '${s.reviewColFat} ${_macro(totals.fat, goal.fat)}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            for (final type in IntakeTypeDBO.values) ..._mealSection(context, day, type, entries),
            if (pending > 0 && !day.isAfter(today)) ...[
              const SizedBox(height: 8),
              Semantics(
                identifier: 'plan-log-day',
                child: FilledButton.icon(
                  icon: const Icon(Icons.playlist_add_check),
                  label: Text(s.planLogDay),
                  onPressed: () => _logDay(context, day),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _macro(double value, double? goal) =>
      goal == null ? value.round().toString() : '${value.round()}/${goal.round()}';

  List<Widget> _mealSection(BuildContext context, DateTime day, IntakeTypeDBO type, List<MealPlanEntryDBO> entries) {
    final theme = Theme.of(context);
    final mealEntries = entries.where((e) => e.type == type).toList();
    return [
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: Text(_mealLabel(context, type), style: theme.textTheme.labelLarge)),
          Semantics(
            identifier: 'plan-add-${type.name}',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: S.of(context).planAdd,
              icon: const Icon(Icons.add, size: 20),
              onPressed: () => _addEntry(context, day, type),
            ),
          ),
        ],
      ),
      for (final e in mealEntries)
        Row(
          children: [
            Icon(
              e.loggedAt != null ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: e.loggedAt != null ? theme.colorScheme.primary : theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${e.meal.name ?? ''} · ${e.amount.round()} ${e.unit} · ${MealPlanCalc.totalsOf(e).kcal.round()} kcal',
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Semantics(
              identifier: 'plan-remove-entry',
              child: IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 16),
                onPressed: () async {
                  await _plan.delete(e.id);
                  await _load();
                },
              ),
            ),
          ],
        ),
    ];
  }

  String _mealLabel(BuildContext context, IntakeTypeDBO type) {
    final s = S.of(context);
    return switch (type) {
      IntakeTypeDBO.breakfast => s.breakfastLabel,
      IntakeTypeDBO.lunch => s.lunchLabel,
      IntakeTypeDBO.dinner => s.dinnerLabel,
      IntakeTypeDBO.snack => s.snackLabel,
    };
  }

  Future<void> _addEntry(BuildContext context, DateTime day, IntakeTypeDBO type) async {
    final picked = await showDialog<({MealDBO meal, double amount})>(
      context: context,
      builder: (_) => const _AddPlanEntryDialog(),
    );
    if (picked == null) return;
    await _plan.save(
      MealPlanEntryDBO(
        id: IdGenerator.getUniqueID(),
        day: day,
        type: type,
        meal: picked.meal,
        amount: picked.amount,
        unit: picked.meal.mealUnit == 'ml' ? 'ml' : 'g',
      ),
    );
    await _load();
  }

  Future<void> _logDay(BuildContext context, DateTime day) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = S.of(context);
    final count = await locator<LogMealPlanUsecase>().logDay(day);
    refreshAfterPlanLogged();
    await _load();
    messenger.showSnackBar(SnackBar(content: Text(s.planLogged(count.toString()))));
  }

  Future<void> _showShoppingList() async {
    final recipes = {for (final r in locator<RecipeRepository>().getAllRecipesDBO()) r.id: r};
    final items = MealPlanCalc.shoppingList(_entries, recipes);
    await showDialog<void>(
      context: context,
      builder: (_) => _ShoppingListDialog(items: items, weekStart: _weekStart),
    );
  }
}

/// Reloads the screens a "Log plan" changes.
void refreshAfterPlanLogged() {
  locator<HomeBloc>().add(const LoadItemsEvent());
  locator<DiaryBloc>().add(const LoadDiaryYearEvent());
  locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
}

class _Candidate {
  final MealDBO meal;
  final double defaultAmount;
  final IconData icon;

  const _Candidate(this.meal, this.defaultAmount, this.icon);
}

/// Picks what to plan from the user's own recipes, custom foods and recent
/// intakes (searching online databases stays in the regular add flow).
class _AddPlanEntryDialog extends StatefulWidget {
  const _AddPlanEntryDialog();

  @override
  State<_AddPlanEntryDialog> createState() => _AddPlanEntryDialogState();
}

class _AddPlanEntryDialogState extends State<_AddPlanEntryDialog> {
  final _search = TextEditingController();
  final _amount = TextEditingController();
  List<_Candidate> _candidates = [];
  _Candidate? _selected;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  @override
  void dispose() {
    _search.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    final seen = <String>{};
    final result = <_Candidate>[];
    void add(MealDBO meal, double amount, IconData icon) {
      final key = (meal.code ?? meal.name ?? '').toLowerCase();
      if (key.isEmpty || !seen.add(key)) return;
      result.add(_Candidate(meal, amount, icon));
    }

    for (final r in locator<RecipeRepository>().getAllRecipes()) {
      final serving = r.servingsCount != null && r.servingsCount! > 0 ? r.totalWeightG / r.servingsCount! : r.totalWeightG;
      add(MealDBO.fromMealEntity(r.toMealEntity()), serving, Icons.menu_book_outlined);
    }
    for (final m in locator<CustomMealDataSource>().getAllCustomMeals()) {
      add(m, 100, Icons.restaurant_outlined);
    }
    for (final i in await locator<IntakeRepository>().getRecentIntake()) {
      add(MealDBO.fromMealEntity(i.meal), i.amount, Icons.history);
    }
    if (mounted) setState(() => _candidates = result);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final query = _search.text.trim().toLowerCase();
    final visible = _candidates.where((c) => (c.meal.name ?? '').toLowerCase().contains(query)).take(60).toList();
    final selected = _selected;
    return AlertDialog(
      title: Text(s.planAdd),
      content: SizedBox(
        width: 460,
        height: 420,
        child: selected == null
            ? Column(
                children: [
                  Semantics(
                    identifier: 'plan-search-field',
                    child: TextField(
                      controller: _search,
                      autofocus: true,
                      decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: s.planSearchHint),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: visible.isEmpty
                        ? Center(child: Text(s.planNoCandidates, textAlign: TextAlign.center))
                        : Semantics(
                            identifier: 'plan-candidates',
                            child: ListView(
                              children: [
                                for (final c in visible)
                                  ListTile(
                                    leading: Icon(c.icon),
                                    title: Text(c.meal.name ?? ''),
                                    subtitle: Text(
                                      '${(c.meal.nutriments.energyKcal100 ?? 0).round()} kcal / 100 ${c.meal.mealUnit == 'ml' ? 'ml' : 'g'}',
                                    ),
                                    onTap: () => setState(() {
                                      _selected = c;
                                      _amount.text = c.defaultAmount.round().toString();
                                    }),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(selected.icon),
                    title: Text(selected.meal.name ?? ''),
                  ),
                  Semantics(
                    identifier: 'plan-amount-field',
                    child: TextField(
                      controller: _amount,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: s.planAmountLabel,
                        suffixText: selected.meal.mealUnit == 'ml' ? 'ml' : 'g',
                      ),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => selected == null ? Navigator.of(context).pop() : setState(() => _selected = null),
          child: Text(s.dialogCancelLabel),
        ),
        if (selected != null)
          Semantics(
            identifier: 'plan-add-confirm',
            child: FilledButton(
              onPressed: () {
                final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
                if (amount == null || amount <= 0) return;
                Navigator.of(context).pop((meal: selected.meal, amount: amount));
              },
              child: Text(s.planAddAction),
            ),
          ),
      ],
    );
  }
}

class _ShoppingListDialog extends StatefulWidget {
  final List<ShoppingItem> items;
  final DateTime weekStart;

  const _ShoppingListDialog({required this.items, required this.weekStart});

  @override
  State<_ShoppingListDialog> createState() => _ShoppingListDialogState();
}

class _ShoppingListDialogState extends State<_ShoppingListDialog> {
  final Set<int> _ticked = {};

  String _amount(ShoppingItem i) => '${i.amount.round()} ${i.unit}';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    return AlertDialog(
      title: Text(s.planShoppingList),
      content: SizedBox(
        width: 460,
        child: widget.items.isEmpty
            ? Text(s.planShoppingEmpty)
            : Semantics(
                identifier: 'plan-shopping-items',
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (i, item) in widget.items.indexed)
                      CheckboxListTile(
                        dense: true,
                        value: _ticked.contains(i),
                        onChanged: (v) => setState(() => v == true ? _ticked.add(i) : _ticked.remove(i)),
                        title: Text(
                          item.name,
                          style: _ticked.contains(i) ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                        ),
                        secondary: Text(_amount(item)),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        if (widget.items.isNotEmpty) ...[
          Semantics(
            identifier: 'plan-shopping-copy',
            child: TextButton.icon(
              icon: const Icon(Icons.copy),
              label: Text(s.planCopy),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: widget.items.map((i) => '- ${i.name}: ${_amount(i)}').join('\n')),
                );
                messenger.showSnackBar(SnackBar(content: Text(s.planCopied)));
              },
            ),
          ),
          Semantics(
            identifier: 'plan-shopping-csv',
            child: TextButton.icon(
              icon: const Icon(Icons.download_outlined),
              label: Text(s.reviewExportCsv),
              onPressed: () async {
                final csv = ReviewCsv.encode(
                  ['item', 'amount', 'unit'],
                  [
                    for (final i in widget.items) [i.name, i.amount, i.unit],
                  ],
                );
                final saved = await FilePicker.saveFile(
                  fileName: 'opennutritracker-shopping-${DateFormat('yyyy-MM-dd').format(widget.weekStart)}.csv',
                  type: FileType.custom,
                  allowedExtensions: ['csv'],
                  bytes: Uint8List.fromList(utf8.encode(csv)),
                );
                if (saved != null || kIsWeb) {
                  messenger.showSnackBar(SnackBar(content: Text(s.reviewExported)));
                }
              },
            ),
          ),
        ],
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.dialogCloseLabel)),
      ],
    );
  }
}

/// Home card on the phone: today's planned entries and the one-tap "Log
/// plan" (FAS-04). Hidden when nothing is pending for today.
class TodayPlanCard extends StatefulWidget {
  const TodayPlanCard({super.key});

  @override
  State<TodayPlanCard> createState() => _TodayPlanCardState();
}

class _TodayPlanCardState extends State<TodayPlanCard> {
  final LogMealPlanUsecase _usecase = locator<LogMealPlanUsecase>();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final pending = _usecase.pendingFor(today);
    if (pending.isEmpty) return const SizedBox.shrink();
    final kcal = MealPlanCalc.totals(pending).kcal.round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_note_outlined),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.planTodayTitle, style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          s.planTodaySummary(pending.length.toString(), kcal.toString()),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  identifier: 'home-log-plan',
                  child: FilledButton.icon(
                    icon: const Icon(Icons.playlist_add_check),
                    label: Text(s.planLogDay),
                    onPressed: _busy
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() => _busy = true);
                            final count = await _usecase.logDay(today);
                            refreshAfterPlanLogged();
                            if (!mounted) return;
                            setState(() => _busy = false);
                            messenger.showSnackBar(SnackBar(content: Text(s.planLogged(count.toString()))));
                          },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
