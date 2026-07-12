import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/save_recipe_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/magic_food_item_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// FR-03: arguments handed off from [MagicScreen] once analysis returns at
/// least one item — the photo (if any) becomes the header banner, the items
/// become editable rows on this screen.
class ReviewMealScreenArguments {
  final List<MagicFoodItemEntity> items;
  final String? imagePath;
  final AddMealType mealType;
  final DateTime day;

  const ReviewMealScreenArguments({
    required this.items,
    required this.imagePath,
    required this.mealType,
    required this.day,
  });
}

/// FR-03: matches XMihura's reference "Review meal" screen — the AI's
/// results land here (not on [MagicScreen] itself) so the user can adjust
/// each item's portion in grams (rescaling kcal/macros live), see a
/// per-item confidence badge, then either log everything at once or save
/// the whole breakdown as a reusable [RecipeEntity] preset.
class ReviewMealScreen extends StatefulWidget {
  final AddIntakeUsecase? addIntakeUsecase;
  final AddTrackedDayUsecase? addTrackedDayUsecase;
  final GetKcalGoalUsecase? getKcalGoalUsecase;
  final GetMacroGoalUsecase? getMacroGoalUsecase;
  final SaveRecipeUseCase? saveRecipeUseCase;

  const ReviewMealScreen({
    super.key,
    this.addIntakeUsecase,
    this.addTrackedDayUsecase,
    this.getKcalGoalUsecase,
    this.getMacroGoalUsecase,
    this.saveRecipeUseCase,
  });

  @override
  State<ReviewMealScreen> createState() => _ReviewMealScreenState();
}

class _ReviewMealScreenState extends State<ReviewMealScreen> {
  late final AddIntakeUsecase _addIntakeUsecase =
      widget.addIntakeUsecase ?? locator<AddIntakeUsecase>();
  late final AddTrackedDayUsecase _addTrackedDayUsecase =
      widget.addTrackedDayUsecase ?? locator<AddTrackedDayUsecase>();
  late final GetKcalGoalUsecase _getKcalGoalUsecase =
      widget.getKcalGoalUsecase ?? locator<GetKcalGoalUsecase>();
  late final GetMacroGoalUsecase _getMacroGoalUsecase =
      widget.getMacroGoalUsecase ?? locator<GetMacroGoalUsecase>();
  late final SaveRecipeUseCase _saveRecipeUseCase =
      widget.saveRecipeUseCase ?? locator<SaveRecipeUseCase>();

  bool _argsLoaded = false;
  late ReviewMealScreenArguments _args;
  List<_ReviewItem> _items = [];

  bool _addingAll = false;
  bool _savingPreset = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _args =
        ModalRoute.of(context)?.settings.arguments
            as ReviewMealScreenArguments;
    _items = _args.items.map(_ReviewItem.fromMagicItem).toList();
    _argsLoaded = true;
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.gramsController.dispose();
    }
    super.dispose();
  }

  double get _totalKcal =>
      _items.fold(0.0, (sum, item) => sum + item.currentKcal);

  Future<void> _onAddAllPressed() async {
    setState(() => _addingAll = true);
    for (final item in _items) {
      if (item.currentGrams <= 0) continue;
      await _persistIntake(item);
    }

    try {
      locator<HomeBloc>().add(const LoadItemsEvent());
      locator<DiaryBloc>().add(const LoadDiaryYearEvent());
      locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
    } catch (_) {
      // Tests without the locator wired up — the intake/tracked-day writes
      // above already landed, this is just a best-effort UI refresh.
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.of(context).magicAddedToDiarySnackbar)),
    );
    Navigator.of(
      context,
    ).popUntil(ModalRoute.withName(NavigationOptions.mainRoute));
  }

  Future<void> _persistIntake(_ReviewItem item) async {
    final meal = MealEntity(
      code: IdGenerator.getUniqueID(),
      name: item.name,
      url: null,
      mealQuantity: item.currentGrams.toString(),
      mealUnit: 'gml',
      servingQuantity: null,
      servingUnit: 'gml',
      servingSize: '',
      nutriments: item.nutrimentsPer100,
      source: MealSourceEntity.custom,
    );
    final intake = IntakeEntity(
      id: IdGenerator.getUniqueID(),
      unit: 'g',
      amount: item.currentGrams,
      type: _args.mealType.getIntakeType(),
      meal: meal,
      dateTime: _args.day,
    );

    await _addIntakeUsecase.addIntake(intake);
    final hasTrackedDay = await _addTrackedDayUsecase.hasTrackedDay(_args.day);
    if (!hasTrackedDay) {
      final kcalGoal = await _getKcalGoalUsecase.getKcalGoal();
      await _addTrackedDayUsecase.addNewTrackedDay(
        _args.day,
        kcalGoal,
        await _getMacroGoalUsecase.getCarbsGoal(kcalGoal),
        await _getMacroGoalUsecase.getFatsGoal(kcalGoal),
        await _getMacroGoalUsecase.getProteinsGoal(kcalGoal),
      );
    }
    await _addTrackedDayUsecase.addDayCaloriesTracked(
      _args.day,
      intake.totalKcal,
    );
    await _addTrackedDayUsecase.addDayMacrosTracked(
      _args.day,
      carbsTracked: intake.totalCarbsGram,
      fatTracked: intake.totalFatsGram,
      proteinTracked: intake.totalProteinsGram,
    );
  }

  Future<void> _onSaveAsPresetPressed() async {
    final s = S.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _SavePresetNameDialog(
        defaultName: _items.length == 1 ? _items.first.name : '',
      ),
    );
    if (name == null || name.isEmpty) return;

    setState(() => _savingPreset = true);
    try {
      final now = DateTime.now();
      final ingredients = _items
          .map(
            (item) => RecipeIngredientEntity(
              snapshotMeal: MealEntity(
                code: IdGenerator.getUniqueID(),
                name: item.name,
                url: null,
                mealQuantity: null,
                mealUnit: 'gml',
                servingQuantity: null,
                servingUnit: 'gml',
                servingSize: '',
                nutriments: item.nutrimentsPer100,
                source: MealSourceEntity.custom,
              ),
              amount: item.currentGrams,
              unit: 'g',
              convertedAmountG: item.currentGrams,
            ),
          )
          .toList();

      final recipe = RecipeEntity(
        id: IdGenerator.getUniqueID(),
        name: name,
        description: null,
        ingredients: ingredients,
        totalWeightG: ingredients.fold(0.0, (sum, i) => sum + i.amount),
        aggregatedNutrimentsPer100: MealNutrimentsEntity.empty(),
        createdAt: now,
        updatedAt: now,
        servingsCount: null,
      );
      await _saveRecipeUseCase.save(recipe);

      if (!mounted) return;
      setState(() => _savingPreset = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.reviewMealPresetSavedSnackbar)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingPreset = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.reviewMealPresetSaveFailedError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final busy = _addingAll || _savingPreset;
    return Scaffold(
      appBar: AppBar(title: Text(s.reviewMealScreenTitle)),
      body: Column(
        children: [
          _HeaderBanner(
            imagePath: _args.imagePath,
            totalKcalLabel: s.reviewMealTotalKcalLabel(_totalKcal.round()),
          ),
          Expanded(
            child: Semantics(
              identifier: 'review-meal-items-list',
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _items.length,
                itemBuilder: (context, index) => _ReviewItemCard(
                  item: _items[index],
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Semantics(
                  identifier: 'review-meal-add-all-button',
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy ? null : _onAddAllPressed,
                      icon: _addingAll
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(s.reviewMealAddAllButton(_items.length)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  identifier: 'review-meal-save-preset-button',
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : _onSaveAsPresetPressed,
                      icon: _savingPreset
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.playlist_add),
                      label: Text(s.reviewMealSaveAsPresetButton),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Owns its own [TextEditingController] so disposal happens when this
/// widget is actually removed from the tree (after the dialog route's
/// exit animation completes) rather than immediately when [showDialog]
/// returns — disposing eagerly races the still-animating-out dialog and
/// throws "A TextEditingController was used after being disposed."
class _SavePresetNameDialog extends StatefulWidget {
  final String defaultName;

  const _SavePresetNameDialog({required this.defaultName});

  @override
  State<_SavePresetNameDialog> createState() => _SavePresetNameDialogState();
}

class _SavePresetNameDialogState extends State<_SavePresetNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.defaultName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.reviewMealSaveAsPresetButton),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: s.reviewMealSavePresetNameHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.dialogCancelLabel),
        ),
        Semantics(
          identifier: 'review-meal-save-preset-confirm',
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
            child: Text(s.buttonSaveLabel),
          ),
        ),
      ],
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  final String? imagePath;
  final String totalKcalLabel;

  const _HeaderBanner({required this.imagePath, required this.totalKcalLabel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 180,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: colorScheme.primaryContainer),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imagePath != null) Image.file(File(imagePath!), fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.primary.withValues(alpha: imagePath != null ? 0.45 : 0.0),
                  colorScheme.primary.withValues(alpha: imagePath != null ? 0.65 : 0.0),
                ],
              ),
            ),
          ),
          Center(
            child: Text(
              totalKcalLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: imagePath != null ? Colors.white : colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  final _ReviewItem item;
  final VoidCallback onChanged;

  const _ReviewItemCard({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final macroParts = <String>[
      if (item.currentProtein != null) 'P ${item.currentProtein!.round()}g',
      if (item.currentCarbs != null) 'C ${item.currentCarbs!.round()}g',
      if (item.currentFat != null) 'F ${item.currentFat!.round()}g',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _ConfidenceBadge(confidence: item.confidence),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    controller: item.gramsController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+([.,]\d{0,2})?$'),
                      ),
                    ],
                    decoration: InputDecoration(
                      isDense: true,
                      suffixText: s.reviewMealGramsUnit,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${item.currentKcal.round()} ${s.kcalLabel}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (macroParts.isNotEmpty) ...[
                  const Spacer(),
                  Text(
                    macroParts.join(' '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final MagicConfidence confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final (background, foreground, label) = switch (confidence) {
      MagicConfidence.low => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        s.reviewMealConfidenceLow,
      ),
      MagicConfidence.medium => (
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
        s.reviewMealConfidenceMedium,
      ),
      MagicConfidence.high => (
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
        s.reviewMealConfidenceHigh,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

/// Mutable per-row editing state. Holds the AI's per-100g rate (constant)
/// derived once from its estimated portion, so editing [gramsController]
/// only needs to rescale a multiplication, never re-derive the rate.
class _ReviewItem {
  final String name;
  final MagicConfidence confidence;
  final MealNutrimentsEntity nutrimentsPer100;
  final TextEditingController gramsController;

  _ReviewItem({
    required this.name,
    required this.confidence,
    required this.nutrimentsPer100,
    required this.gramsController,
  });

  factory _ReviewItem.fromMagicItem(MagicFoodItemEntity item) {
    final grams = item.grams > 0 ? item.grams : 100.0;
    double? per100(double? total) =>
        total == null ? null : total * 100 / grams;
    return _ReviewItem(
      name: item.name,
      confidence: item.confidence,
      nutrimentsPer100: MealNutrimentsEntity(
        energyKcal100: item.kcal * 100 / grams,
        carbohydrates100: per100(item.carbsG),
        fat100: per100(item.fatG),
        proteins100: per100(item.proteinG),
        sugars100: null,
        saturatedFat100: null,
        fiber100: null,
      ),
      gramsController: TextEditingController(text: _formatGrams(grams)),
    );
  }

  double get currentGrams {
    final raw = gramsController.text.replaceAll(',', '.');
    return double.tryParse(raw) ?? 0;
  }

  double get currentKcal =>
      (nutrimentsPer100.energyKcal100 ?? 0) * currentGrams / 100;

  double? get currentCarbs => nutrimentsPer100.carbohydrates100 == null
      ? null
      : nutrimentsPer100.carbohydrates100! * currentGrams / 100;

  double? get currentFat => nutrimentsPer100.fat100 == null
      ? null
      : nutrimentsPer100.fat100! * currentGrams / 100;

  double? get currentProtein => nutrimentsPer100.proteins100 == null
      ? null
      : nutrimentsPer100.proteins100! * currentGrams / 100;

  static String _formatGrams(double grams) {
    if (grams == grams.roundToDouble()) return grams.round().toString();
    return grams.toStringAsFixed(1);
  }
}
