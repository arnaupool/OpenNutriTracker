import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/meal_for_time.dart';

void main() {
  DateTime at(int h, int m) => DateTime(2026, 5, 4, h, m);

  test('maps the time of day to a meal', () {
    expect(mealForTime(at(0, 0)), IntakeTypeEntity.breakfast);
    expect(mealForTime(at(10, 59)), IntakeTypeEntity.breakfast);
    expect(mealForTime(at(11, 0)), IntakeTypeEntity.lunch);
    expect(mealForTime(at(16, 29)), IntakeTypeEntity.lunch);
    expect(mealForTime(at(16, 30)), IntakeTypeEntity.snack);
    expect(mealForTime(at(19, 29)), IntakeTypeEntity.snack);
    expect(mealForTime(at(19, 30)), IntakeTypeEntity.dinner);
    expect(mealForTime(at(23, 59)), IntakeTypeEntity.dinner);
  });
}
