import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';

/// Chips to change which meal (breakfast, lunch, dinner, snack) an item is
/// logged to before saving. Used where the meal was chosen automatically from
/// the time of day (home "Add" sheet) so the user can still correct it.
class MealTypeSelector extends StatelessWidget {
  final IntakeTypeEntity value;
  final ValueChanged<IntakeTypeEntity> onChanged;

  const MealTypeSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'meal-type-selector',
      container: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          for (final type in IntakeTypeEntity.values)
            ChoiceChip(
              avatar: Icon(type.getIconData(), size: 18),
              label: Text(AddMealExtension.fromIntakeTypeEntity(type).getTypeName(context)),
              selected: type == value,
              onSelected: (_) => onChanged(type),
            ),
        ],
      ),
    );
  }
}
