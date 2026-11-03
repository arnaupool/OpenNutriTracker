import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';

/// Meal that an item logged at [now] most likely belongs to. Used by the home
/// "Add" sheet, which has no meal picker; the user can still change the meal
/// before saving.
///
/// Before 11:00 breakfast, 11:00 to 16:29 lunch, 16:30 to 19:29 snack, from
/// 19:30 dinner.
IntakeTypeEntity mealForTime(DateTime now) {
  final minutes = now.hour * 60 + now.minute;
  if (minutes < 11 * 60) return IntakeTypeEntity.breakfast;
  if (minutes < 16 * 60 + 30) return IntakeTypeEntity.lunch;
  if (minutes < 19 * 60 + 30) return IntakeTypeEntity.snack;
  return IntakeTypeEntity.dinner;
}
