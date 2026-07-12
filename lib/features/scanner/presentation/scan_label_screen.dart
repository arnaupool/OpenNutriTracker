import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/photo_picker_card.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/scanner/domain/entity/scanned_label_entity.dart';
import 'package:opennutritracker/features/scanner/domain/usecase/analyze_label_with_ai_usecase.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// FR-04: reached from [ScannerScreen] when a scanned barcode has no match
/// in the product database. Photograph the nutrition label, let the AI
/// transcribe it ([AnalyzeLabelWithAiUsecase]), then hand the result off
/// to [EditMealScreen] — prefilled and keyed by the scanned barcode — for
/// the user to review, correct, and save. Saving there registers it as a
/// custom meal (#167's barcode-keyed lookup), so a future scan of the same
/// product finds it locally before ever hitting Open Food Facts again.
class ScanLabelScreenArguments {
  final String barcode;
  final DateTime day;
  final IntakeTypeEntity intakeTypeEntity;

  const ScanLabelScreenArguments({
    required this.barcode,
    required this.day,
    required this.intakeTypeEntity,
  });
}

class ScanLabelScreen extends StatefulWidget {
  final GetConfigUsecase? getConfigUsecase;
  final AnalyzeLabelWithAiUsecase? analyzeLabelWithAiUsecase;
  final ImagePicker? imagePicker;

  const ScanLabelScreen({
    super.key,
    this.getConfigUsecase,
    this.analyzeLabelWithAiUsecase,
    this.imagePicker,
  });

  @override
  State<ScanLabelScreen> createState() => _ScanLabelScreenState();
}

class _ScanLabelScreenState extends State<ScanLabelScreen> {
  final _log = Logger('ScanLabelScreen');

  late final GetConfigUsecase _getConfigUsecase =
      widget.getConfigUsecase ?? locator<GetConfigUsecase>();
  late final AnalyzeLabelWithAiUsecase _analyzeUsecase =
      widget.analyzeLabelWithAiUsecase ?? locator<AnalyzeLabelWithAiUsecase>();
  late final ImagePicker _imagePicker = widget.imagePicker ?? ImagePicker();

  bool _argsLoaded = false;
  late ScanLabelScreenArguments _args;

  String? _imagePath;
  bool _analyzing = false;
  String? _errorMessage;

  bool _loadingConfig = true;
  String? _apiKey;
  String? _modelId;
  bool _usesImperialUnits = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _args =
        ModalRoute.of(context)?.settings.arguments as ScanLabelScreenArguments;
    _argsLoaded = true;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await _getConfigUsecase.getConfig();
    if (!mounted) return;
    setState(() {
      _apiKey = config.openRouterApiKey;
      _modelId = config.openRouterModelId;
      _usesImperialUnits = config.usesImperialUnits;
      _loadingConfig = false;
    });
  }

  bool get _canAnalyze => !_analyzing && _imagePath != null && !_loadingConfig;

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
    if (_modelId == null) {
      setState(() => _errorMessage = s.magicNoModelError);
      return;
    }

    setState(() {
      _analyzing = true;
      _errorMessage = null;
    });

    try {
      final bytes = await File(_imagePath!).readAsBytes();
      final base64Image = base64Encode(bytes);
      final label = await _analyzeUsecase.analyze(
        apiKey: _apiKey!,
        model: _modelId!,
        base64Image: base64Image,
      );
      if (!mounted) return;
      setState(() => _analyzing = false);

      Navigator.of(context).pushReplacementNamed(
        NavigationOptions.editMealRoute,
        arguments: EditMealScreenArguments(
          _args.day,
          _mealEntityFrom(label),
          _args.intakeTypeEntity,
          _usesImperialUnits,
        ),
      );
    } catch (e, st) {
      _log.warning('Label analysis failed', e, st);
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _errorMessage = s.scanLabelAnalysisFailedError;
      });
    }
  }

  MealEntity _mealEntityFrom(ScannedLabelEntity label) {
    return MealEntity(
      code: _args.barcode,
      name: label.name,
      brands: label.brand,
      url: null,
      mealQuantity: null,
      mealUnit: 'gml',
      servingQuantity: null,
      servingUnit: 'gml',
      servingSize: label.servingSize ?? '',
      nutriments: MealNutrimentsEntity(
        energyKcal100: label.kcal100,
        carbohydrates100: label.carbs100,
        fat100: label.fat100,
        proteins100: label.protein100,
        sugars100: label.sugars100,
        saturatedFat100: label.saturatedFat100,
        fiber100: label.fiber100,
        sodium100: label.sodiumMg100,
      ),
      source: MealSourceEntity.custom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.scanLabelScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(s.scanLabelExplanation, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          PhotoPickerCard(
            imagePath: _imagePath,
            onRemove: _onRemoveImage,
            placeholderLabel: s.scanLabelPhotoPlaceholder,
            removeButtonSemanticsId: 'scan-label-remove-photo',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  identifier: 'scan-label-camera-button',
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
                  identifier: 'scan-label-gallery-button',
                  child: OutlinedButton.icon(
                    onPressed: () => _onPickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(s.magicGalleryButton),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Semantics(
            identifier: 'scan-label-analyze-button',
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
                _analyzing ? s.magicAnalyzingLabel : s.scanLabelAnalyzeButton,
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
