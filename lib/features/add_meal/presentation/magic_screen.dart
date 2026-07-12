import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/open_router_model_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_open_router_models_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/magic_food_item_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/analyze_meal_with_ai_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// FR-02: photo and/or text → AI-estimated macro breakdown, via the
/// OpenRouter client built in FR-01. Matches XMihura's reference "Magic"
/// screen: photo picker, free-text description, Single item / Meal
/// breakdown toggle, and an inline Provider→Model pair (grouped from the
/// "Vendor: Model name" convention OpenRouter's catalog already uses,
/// distinct from Settings' flat searchable list) that can override the
/// globally configured model for this one analysis.
class MagicScreen extends StatefulWidget {
  final GetOpenRouterModelsUsecase? getOpenRouterModelsUsecase;
  final GetConfigUsecase? getConfigUsecase;
  final AnalyzeMealWithAiUsecase? analyzeMealWithAiUsecase;
  final AddIntakeUsecase? addIntakeUsecase;
  final AddTrackedDayUsecase? addTrackedDayUsecase;
  final GetKcalGoalUsecase? getKcalGoalUsecase;
  final GetMacroGoalUsecase? getMacroGoalUsecase;
  final ImagePicker? imagePicker;

  const MagicScreen({
    super.key,
    this.getOpenRouterModelsUsecase,
    this.getConfigUsecase,
    this.analyzeMealWithAiUsecase,
    this.addIntakeUsecase,
    this.addTrackedDayUsecase,
    this.getKcalGoalUsecase,
    this.getMacroGoalUsecase,
    this.imagePicker,
  });

  @override
  State<MagicScreen> createState() => _MagicScreenState();
}

class _MagicScreenState extends State<MagicScreen> {
  final _log = Logger('MagicScreen');

  late final GetOpenRouterModelsUsecase _getModelsUsecase =
      widget.getOpenRouterModelsUsecase ??
      locator<GetOpenRouterModelsUsecase>();
  late final GetConfigUsecase _getConfigUsecase =
      widget.getConfigUsecase ?? locator<GetConfigUsecase>();
  late final AnalyzeMealWithAiUsecase _analyzeUsecase =
      widget.analyzeMealWithAiUsecase ?? locator<AnalyzeMealWithAiUsecase>();
  late final AddIntakeUsecase _addIntakeUsecase =
      widget.addIntakeUsecase ?? locator<AddIntakeUsecase>();
  late final AddTrackedDayUsecase _addTrackedDayUsecase =
      widget.addTrackedDayUsecase ?? locator<AddTrackedDayUsecase>();
  late final GetKcalGoalUsecase _getKcalGoalUsecase =
      widget.getKcalGoalUsecase ?? locator<GetKcalGoalUsecase>();
  late final GetMacroGoalUsecase _getMacroGoalUsecase =
      widget.getMacroGoalUsecase ?? locator<GetMacroGoalUsecase>();
  late final ImagePicker _imagePicker = widget.imagePicker ?? ImagePicker();

  late AddMealScreenArguments _args;

  final _descriptionController = TextEditingController();

  String? _imagePath;
  bool _mealBreakdown = false;

  bool _loadingModels = true;
  List<OpenRouterModelEntity> _models = const [];
  String? _apiKey;
  String? _selectedProvider;
  String? _selectedModelId;

  bool _analyzing = false;
  String? _errorMessage;
  List<MagicFoodItemEntity>? _results;
  final Set<int> _addedIndices = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _args =
        ModalRoute.of(context)?.settings.arguments as AddMealScreenArguments;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await _getConfigUsecase.getConfig();
    _apiKey = config.openRouterApiKey;
    try {
      final models = await _getModelsUsecase.getModels();
      if (!mounted) return;
      setState(() {
        _models = models;
        _loadingModels = false;
        final preselected = config.openRouterModelId != null
            ? models.where((m) => m.id == config.openRouterModelId).firstOrNull
            : null;
        final initial =
            preselected ?? (models.isNotEmpty ? models.first : null);
        _selectedProvider = initial == null ? null : _providerOf(initial);
        _selectedModelId = initial?.id;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingModels = false);
    }
  }

  String _providerOf(OpenRouterModelEntity model) {
    final idx = model.name.indexOf(': ');
    return idx == -1 ? model.name : model.name.substring(0, idx);
  }

  String _modelLabelOf(OpenRouterModelEntity model) {
    final idx = model.name.indexOf(': ');
    return idx == -1 ? model.name : model.name.substring(idx + 2);
  }

  List<String> get _providers =>
      _models.map(_providerOf).toSet().toList()..sort();

  List<OpenRouterModelEntity> get _modelsForSelectedProvider =>
      _models.where((m) => _providerOf(m) == _selectedProvider).toList();

  bool get _canAnalyze {
    final hasInput =
        _imagePath != null || _descriptionController.text.trim().isNotEmpty;
    return !_analyzing &&
        hasInput &&
        _selectedModelId != null &&
        !_loadingModels;
  }

  Future<void> _onPickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(source: source);
      if (picked == null) return;
      setState(() {
        _imagePath = picked.path;
        _results = null;
        _errorMessage = null;
      });
    } catch (e, st) {
      _log.warning('Image pick failed', e, st);
    }
  }

  void _onRemoveImage() {
    setState(() => _imagePath = null);
  }

  Future<void> _onAnalyzePressed() async {
    final s = S.of(context);
    if (_apiKey == null || _apiKey!.isEmpty) {
      setState(() => _errorMessage = s.magicNoApiKeyError);
      return;
    }
    if (_selectedModelId == null) {
      setState(() => _errorMessage = s.magicNoModelError);
      return;
    }

    setState(() {
      _analyzing = true;
      _errorMessage = null;
      _results = null;
      _addedIndices.clear();
    });

    try {
      String? base64Image;
      if (_imagePath != null) {
        final bytes = await File(_imagePath!).readAsBytes();
        base64Image = base64Encode(bytes);
      }
      final items = await _analyzeUsecase.analyze(
        apiKey: _apiKey!,
        model: _selectedModelId!,
        mealBreakdown: _mealBreakdown,
        description: _descriptionController.text,
        base64Image: base64Image,
      );
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _results = items;
        if (items.isEmpty) _errorMessage = s.magicEmptyResultError;
      });
    } catch (e, st) {
      _log.warning('Magic analysis failed', e, st);
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _errorMessage = s.magicAnalysisFailedError;
      });
    }
  }

  Future<void> _onAddToDiary(int index, MagicFoodItemEntity item) async {
    final nutriments = MealNutrimentsEntity(
      energyKcal100: item.kcal,
      carbohydrates100: item.carbsG,
      fat100: item.fatG,
      proteins100: item.proteinG,
      sugars100: null,
      saturatedFat100: null,
      fiber100: null,
    );
    final meal = MealEntity(
      code: IdGenerator.getUniqueID(),
      name: item.name,
      url: null,
      mealQuantity: '100',
      mealUnit: 'gml',
      servingQuantity: null,
      servingUnit: 'gml',
      servingSize: '',
      nutriments: nutriments,
      source: MealSourceEntity.custom,
    );
    final intake = IntakeEntity(
      id: IdGenerator.getUniqueID(),
      unit: 'g',
      amount: 100,
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

    try {
      locator<HomeBloc>().add(const LoadItemsEvent());
      locator<DiaryBloc>().add(const LoadDiaryYearEvent());
      locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
    } catch (_) {
      // Tests without the locator wired up — the intake/tracked-day writes
      // above already landed, this is just a best-effort UI refresh.
    }

    if (!mounted) return;
    setState(() => _addedIndices.add(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.of(context).magicAddedToDiarySnackbar)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.magicScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _PhotoPicker(imagePath: _imagePath, onRemove: _onRemoveImage),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  identifier: 'magic-camera-button',
                  child: OutlinedButton.icon(
                    onPressed: () => _onPickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(s.magicCameraButton),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  identifier: 'magic-gallery-button',
                  child: OutlinedButton.icon(
                    onPressed: () => _onPickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(s.magicGalleryButton),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            identifier: 'magic-description-field',
            child: TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: s.magicDescribeFoodHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            identifier: 'magic-breakdown-toggle',
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(s.magicSingleItemLabel),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(s.magicMealBreakdownLabel),
                ),
              ],
              selected: {_mealBreakdown},
              onSelectionChanged: (selection) =>
                  setState(() => _mealBreakdown = selection.first),
            ),
          ),
          const SizedBox(height: 16),
          if (_loadingModels)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Semantics(
                    identifier: 'magic-provider-dropdown',
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedProvider,
                      decoration: InputDecoration(
                        labelText: s.magicProviderLabel,
                        border: const OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: [
                        for (final provider in _providers)
                          DropdownMenuItem(
                            value: provider,
                            child: Text(
                              provider,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (provider) {
                        if (provider == null) return;
                        final firstModel = _models.firstWhere(
                          (m) => _providerOf(m) == provider,
                        );
                        setState(() {
                          _selectedProvider = provider;
                          _selectedModelId = firstModel.id;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    identifier: 'magic-model-dropdown',
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedModelId,
                      decoration: InputDecoration(
                        labelText: s.magicModelLabel,
                        border: const OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: [
                        for (final model in _modelsForSelectedProvider)
                          DropdownMenuItem(
                            value: model.id,
                            child: Text(
                              _modelLabelOf(model),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (modelId) =>
                          setState(() => _selectedModelId = modelId),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          Semantics(
            identifier: 'magic-analyze-button',
            child: FilledButton.icon(
              onPressed: _canAnalyze ? _onAnalyzePressed : null,
              icon: _analyzing
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(
                _analyzing ? s.magicAnalyzingLabel : s.magicAnalyzeButton,
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_results != null && _results!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              s.magicResultsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Semantics(
              identifier: 'magic-results-list',
              child: Column(
                children: [
                  for (var i = 0; i < _results!.length; i++)
                    _ResultCard(
                      item: _results![i],
                      added: _addedIndices.contains(i),
                      onAdd: () => _onAddToDiary(i, _results![i]),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onRemove;

  const _PhotoPicker({required this.imagePath, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: imagePath == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(s.mealImageLabel),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(imagePath!), fit: BoxFit.cover),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Semantics(
                    identifier: 'magic-remove-photo',
                    child: IconButton.filled(
                      icon: const Icon(Icons.close),
                      onPressed: onRemove,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final MagicFoodItemEntity item;
  final bool added;
  final VoidCallback onAdd;

  const _ResultCard({
    required this.item,
    required this.added,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final macroParts = <String>[
      if (item.carbsG != null) '${item.carbsG!.round()}g C',
      if (item.fatG != null) '${item.fatG!.round()}g F',
      if (item.proteinG != null) '${item.proteinG!.round()}g P',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${item.kcal.round()} ${s.kcalLabel}'
                    '${macroParts.isEmpty ? '' : ' · ${macroParts.join(' · ')}'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Semantics(
              identifier: 'magic-add-to-diary',
              child: Tooltip(
                message: s.magicAddToDiaryButton,
                child: FilledButton(
                  onPressed: added ? null : onAdd,
                  child: Icon(added ? Icons.check : Icons.add),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
