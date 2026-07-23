import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class EditDialog extends StatefulWidget {
  final IntakeEntity intakeEntity;
  final bool usesImperialUnits;

  const EditDialog({
    super.key,
    required this.intakeEntity,
    required this.usesImperialUnits,
  });

  @override
  State<StatefulWidget> createState() => _EditDialogState();
}

class _EditDialogState extends State<EditDialog> {
  late TextEditingController amountEditingController;

  @override
  void initState() {
    super.initState();
    double initialAmount = _convertValue(
      widget.intakeEntity.amount,
      widget.intakeEntity.meal.mealUnit,
    );
    amountEditingController = TextEditingController(
      text: initialAmount.toStringAsFixed(2),
    );
    amountEditingController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    amountEditingController.removeListener(_onAmountChanged);
    amountEditingController.dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  /// The typed amount converted back to the metric base (g/ml) that
  /// [MealNutrimentsEntity]'s `...PerUnit` getters are keyed to — same
  /// conversion `MealDetailBloc` already applies when logging a new
  /// intake, just run in reverse off the dialog's own text field. Null
  /// when the field is empty or not a valid number.
  double? get _currentMetricAmount {
    final text = amountEditingController.text.replaceAll(',', '.');
    final parsed = double.tryParse(text);
    if (parsed == null) return null;
    return _convertBackToMetricValue(parsed, widget.intakeEntity.meal.mealUnit);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final nutriments = widget.intakeEntity.meal.nutriments;
    final hasNutritionData = nutriments.energyKcal100 != null;
    final metricAmount = _currentMetricAmount;

    return AlertDialog(
      title: Text(s.editItemDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: amountEditingController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: s.quantityLabel,
              suffixText: _convertUnit(
                context,
                widget.intakeEntity.meal.mealUnit ?? '',
              ),
            ),
          ),
          if (hasNutritionData) ...[
            const SizedBox(height: 16),
            Semantics(
              identifier: 'edit-dialog-nutrition-summary',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NutrientStat(
                    value: metricAmount == null
                        ? null
                        : metricAmount * (nutriments.energyPerUnit ?? 0),
                    unit: s.kcalLabel,
                    label: s.caloriesLabel,
                  ),
                  _NutrientStat(
                    value: metricAmount == null
                        ? null
                        : metricAmount * (nutriments.carbohydratesPerUnit ?? 0),
                    unit: s.gramUnit,
                    label: s.carbsLabel,
                  ),
                  _NutrientStat(
                    value: metricAmount == null
                        ? null
                        : metricAmount * (nutriments.fatPerUnit ?? 0),
                    unit: s.gramUnit,
                    label: s.fatLabel,
                  ),
                  _NutrientStat(
                    value: metricAmount == null
                        ? null
                        : metricAmount * (nutriments.proteinsPerUnit ?? 0),
                    unit: s.gramUnit,
                    label: s.proteinLabel,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            double newAmount = double.parse(amountEditingController.text);
            Navigator.of(context).pop(
              _convertBackToMetricValue(
                newAmount,
                widget.intakeEntity.meal.mealUnit,
              ),
            );
          },
          child: Text(s.dialogOKLabel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(s.dialogCancelLabel),
        ),
      ],
    );
  }

  double _convertValue(double value, String? unit) {
    switch (unit) {
      case 'g':
        return widget.usesImperialUnits ? UnitCalc.gToOz(value) : value;
      case 'ml':
        return widget.usesImperialUnits ? UnitCalc.mlToFlOz(value) : value;
      default:
        return value;
    }
  }

  double _convertBackToMetricValue(double value, String? unit) {
    switch (unit) {
      case 'g':
        return widget.usesImperialUnits ? UnitCalc.ozToG(value) : value;
      case 'ml':
        return widget.usesImperialUnits ? UnitCalc.flOzToMl(value) : value;
      default:
        return value;
    }
  }

  /// `'gml'` is `MealEntity.empty()`'s own placeholder for "no real unit
  /// was ever set" (custom/manually-created meals that skipped the
  /// dropdown) — shown the same way `MealDetailBottomSheet` labels that
  /// same fallback case, rather than leaking the raw internal string.
  String _convertUnit(BuildContext context, String unit) {
    switch (unit) {
      case 'g':
        return widget.usesImperialUnits ? 'oz' : 'g';
      case 'ml':
        return widget.usesImperialUnits ? 'fl.oz' : 'ml';
      case 'gml':
        return S.of(context).gramMilliliterUnit;
      default:
        return unit;
    }
  }
}

class _NutrientStat extends StatelessWidget {
  final double? value;
  final String unit;
  final String label;

  const _NutrientStat({
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value == null ? '—' : '${value!.round()} $unit',
          style: theme.textTheme.titleSmall,
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
