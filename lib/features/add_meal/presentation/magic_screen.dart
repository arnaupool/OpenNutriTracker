import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/entity/open_router_model_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_open_router_models_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/analyze_meal_with_ai_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/review_meal_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// FR-02: photo and/or text → AI-estimated macro breakdown, via the
/// OpenRouter client built in FR-01. Matches XMihura's reference "Magic"
/// screen: photo picker, free-text description, Single item / Meal
/// breakdown toggle, and an inline Provider→Model pair (grouped from the
/// "Vendor: Model name" convention OpenRouter's catalog already uses,
/// distinct from Settings' flat searchable list) that can override the
/// globally configured model for this one analysis. A successful analysis
/// hands the results off to [ReviewMealScreen] (FR-03) rather than
/// rendering them inline — that screen owns quantity editing, confidence
/// badges, and the add-to-diary / save-as-preset actions.
class MagicScreen extends StatefulWidget {
  final GetOpenRouterModelsUsecase? getOpenRouterModelsUsecase;
  final GetConfigUsecase? getConfigUsecase;
  final AnalyzeMealWithAiUsecase? analyzeMealWithAiUsecase;
  final ImagePicker? imagePicker;

  const MagicScreen({
    super.key,
    this.getOpenRouterModelsUsecase,
    this.getConfigUsecase,
    this.analyzeMealWithAiUsecase,
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
      if (items.isEmpty) {
        setState(() {
          _analyzing = false;
          _errorMessage = s.magicEmptyResultError;
        });
        return;
      }
      setState(() => _analyzing = false);
      Navigator.of(context).pushNamed(
        NavigationOptions.reviewMealRoute,
        arguments: ReviewMealScreenArguments(
          items: items,
          imagePath: _imagePath,
          mealType: _args.mealType,
          day: _args.day,
        ),
      );
    } catch (e, st) {
      _log.warning('Magic analysis failed', e, st);
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _errorMessage = s.magicAnalysisFailedError;
      });
    }
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

