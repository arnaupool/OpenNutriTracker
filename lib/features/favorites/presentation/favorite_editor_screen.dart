import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_entity.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_repository.dart';
import 'package:opennutritracker/features/scanner/presentation/barcode_capture_page.dart';
import 'package:opennutritracker/generated/l10n.dart';

class FavoriteEditorArguments {
  /// The favorite to edit; null creates a new one.
  final String? favoriteId;

  /// A code to start a new favorite with.
  final String? initialBarcode;

  const FavoriteEditorArguments({this.favoriteId, this.initialBarcode});
}

/// Creates or edits a favorite: name, brand, macros per 100 g/ml, default
/// portion, barcodes, and deletion. Saving never touches past diary entries
/// (they hold their own copy of the meal).
class FavoriteEditorScreen extends StatefulWidget {
  const FavoriteEditorScreen({super.key});

  @override
  State<FavoriteEditorScreen> createState() => _FavoriteEditorScreenState();
}

class _FavoriteEditorScreenState extends State<FavoriteEditorScreen> {
  final FavoriteFoodRepository _repo = locator<FavoriteFoodRepository>();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _kcal = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _protein = TextEditingController();
  final _portionName = TextEditingController();
  final _portionQuantity = TextEditingController();
  final _barcodeInput = TextEditingController();

  FavoriteFoodEntity? _existing;
  String _unit = 'g';
  List<String> _barcodes = [];
  String? _barcodeError;
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments as FavoriteEditorArguments?;
    final id = args?.favoriteId;
    final existing = id == null ? null : _repo.getById(id);
    _existing = existing;
    if (existing != null) {
      _name.text = existing.name;
      _brand.text = existing.brand ?? '';
      _kcal.text = _fmt(existing.nutriments.energyKcal100);
      _carbs.text = _fmt(existing.nutriments.carbohydrates100);
      _fat.text = _fmt(existing.nutriments.fat100);
      _protein.text = _fmt(existing.nutriments.proteins100);
      _unit = existing.unit;
      _portionName.text = existing.portionName ?? '';
      _portionQuantity.text = _fmt(existing.portionQuantity);
      _barcodes = [...existing.barcodes];
    } else if (args?.initialBarcode != null) {
      _barcodes = [args!.initialBarcode!];
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _brand, _kcal, _carbs, _fat, _protein, _portionName, _portionQuantity, _barcodeInput]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(double? v) {
    if (v == null) return '';
    final rounded = double.parse(v.toStringAsFixed(2));
    return rounded == rounded.roundToDouble() ? rounded.toStringAsFixed(0) : rounded.toString();
  }

  static double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  String? _nonNegative(String? value, {required bool required}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return required ? S.of(context).favoriteNumberInvalid : null;
    final n = _parse(text);
    return n == null || n < 0 ? S.of(context).favoriteNumberInvalid : null;
  }

  String? _portionQuantityError(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty && _portionName.text.trim().isEmpty) return null;
    final n = _parse(text);
    return n == null || n <= 0 ? S.of(context).favoritePortionInvalid : null;
  }

  /// Why [code] cannot be added, or null when it can.
  String? _barcodeProblem(String code) {
    final s = S.of(context);
    if (!isPlausibleBarcode(code)) return s.customMealBarcodeInvalid;
    if (_barcodes.contains(code)) return s.favoriteBarcodeDuplicate;
    final owner = _repo.findByBarcode(code);
    if (owner != null && owner.id != _existing?.id) return s.favoriteBarcodeTaken;
    return null;
  }

  void _addBarcode(String raw) {
    final code = raw.trim();
    final problem = _barcodeProblem(code);
    setState(() {
      _barcodeError = problem;
      if (problem == null) {
        _barcodes = [..._barcodes, code];
        _barcodeInput.clear();
      }
    });
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const BarcodeCapturePage()));
    if (code != null && mounted) _addBarcode(code);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = S.of(context).favoriteSaved;
    setState(() => _saving = true);
    final base = _existing?.nutriments ?? MealNutrimentsEntity.empty();
    final nutriments = nutrimentsWithMacros(
      base,
      kcal: _parse(_kcal.text),
      carbs: _parse(_carbs.text),
      fat: _parse(_fat.text),
      protein: _parse(_protein.text),
    );
    final brand = _brand.text.trim();
    final hasPortion = _portionQuantity.text.trim().isNotEmpty;
    final now = DateTime.now();
    final existing = _existing;
    final portionName = _portionName.text.trim();
    final favorite = FavoriteFoodEntity(
      id: existing?.id ?? IdGenerator.getUniqueID(),
      name: _name.text.trim(),
      brand: brand.isEmpty ? null : brand,
      imageUrl: existing?.imageUrl,
      nutriments: nutriments,
      unit: _unit,
      portionName: hasPortion && portionName.isNotEmpty ? portionName : null,
      portionQuantity: hasPortion ? _parse(_portionQuantity.text) : null,
      barcodes: _barcodes,
      originSource: existing?.originSource,
      originId: existing?.originId,
      createdAt: existing?.createdAt ?? now,
      modifiedAt: now,
    );
    await _repo.save(favorite, now: now);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(saved)));
    navigator.pop(favorite.id);
  }

  Future<void> _delete() async {
    final existing = _existing;
    if (existing == null) return;
    final s = S.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.favoriteDelete),
        content: Text(s.favoriteDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(s.dialogCancelLabel)),
          Semantics(
            identifier: 'favorite-delete-confirm',
            child: TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(s.dialogDeleteLabel)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo.delete(existing.id);
    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final per100 = _unit == 'ml' ? s.favoriteMacrosPer100ml : s.favoriteMacrosPer100g;
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? s.favoriteNew : s.favoriteEditTitle),
        actions: [
          if (_existing != null)
            Semantics(
              identifier: 'favorite-delete',
              child: IconButton(tooltip: s.favoriteDelete, icon: const Icon(Icons.delete_outline), onPressed: _delete),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Semantics(
                identifier: 'favorite-name',
                child: TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: s.mealNameLabel),
                  validator: (v) => (v ?? '').trim().isEmpty ? s.mealNameValidationError : null,
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                identifier: 'favorite-brand',
                child: TextFormField(
                  controller: _brand,
                  decoration: InputDecoration(labelText: s.favoriteBrandLabel),
                ),
              ),
              const SizedBox(height: 16),
              Text(s.favoriteUnitLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Semantics(
                identifier: 'favorite-unit',
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'g', label: Text(s.gramUnit)),
                    ButtonSegment(value: 'ml', label: Text(s.milliliterUnit)),
                  ],
                  selected: {_unit},
                  onSelectionChanged: (v) => setState(() => _unit = v.first),
                ),
              ),
              const SizedBox(height: 20),
              Text(per100, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _numberField('favorite-kcal', _kcal, '${s.mealEnergyLabel} (${s.kcalLabel})', required: true),
              _numberField('favorite-carbs', _carbs, '${s.mealCarbsLabel} (${s.gramUnit})'),
              _numberField('favorite-fat', _fat, '${s.mealFatLabel} (${s.gramUnit})'),
              _numberField('favorite-protein', _protein, '${s.mealProteinLabel} (${s.gramUnit})'),
              const SizedBox(height: 20),
              Text(s.favoritePortionTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Semantics(
                identifier: 'favorite-portion-name',
                child: TextFormField(
                  controller: _portionName,
                  decoration: InputDecoration(labelText: s.favoritePortionNameLabel),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                identifier: 'favorite-portion-quantity',
                child: TextFormField(
                  controller: _portionQuantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: s.favoritePortionQuantityLabel, suffixText: _unit),
                  validator: _portionQuantityError,
                ),
              ),
              const SizedBox(height: 20),
              Text(s.favoriteBarcodesTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_barcodes.isNotEmpty)
                Semantics(
                  identifier: 'favorite-barcodes',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final code in _barcodes)
                        InputChip(
                          label: Text(code),
                          onDeleted: () => setState(() => _barcodes = [..._barcodes]..remove(code)),
                        ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Semantics(
                      identifier: 'favorite-barcode-input',
                      child: TextField(
                        controller: _barcodeInput,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(hintText: s.favoriteBarcodeAddHint, errorText: _barcodeError),
                        onSubmitted: _addBarcode,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    identifier: 'favorite-barcode-add',
                    child: IconButton.filledTonal(
                      tooltip: s.favoriteBarcodeAdd,
                      icon: const Icon(Icons.add),
                      onPressed: () => _addBarcode(_barcodeInput.text),
                    ),
                  ),
                  Semantics(
                    identifier: 'favorite-barcode-scan',
                    child: IconButton.filledTonal(
                      tooltip: s.favoriteBarcodeScan,
                      icon: const Icon(Icons.qr_code_scanner_outlined),
                      onPressed: _scanBarcode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Semantics(
                identifier: 'favorite-save',
                child: FilledButton(onPressed: _saving ? null : _save, child: Text(s.buttonSaveLabel)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberField(String id, TextEditingController controller, String label, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      identifier: id,
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        validator: (v) => _nonNegative(v, required: required),
      ),
    ),
  );
}
