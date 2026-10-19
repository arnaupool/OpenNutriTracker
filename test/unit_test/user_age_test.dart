import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/utils/bounds/ranges_const.dart';
import 'package:opennutritracker/core/utils/bounds/validator.dart';

// QA 2026-10-19: age feeds the IOM 2005 equations (-9.72 or -7.31 kcal per
// year), so it must be the calendar age, and the onboarding picker must not
// accept birthdays that make the adult equations meaningless.
void main() {
  UserEntity bornOn(DateTime birthday) => UserEntity(
    birthday: birthday,
    heightCM: 180,
    weightKG: 80,
    gender: UserGenderEntity.male,
    goal: UserWeightGoalEntity.maintainWeight,
    pal: UserPALEntity.sedentary,
  );

  final now = DateTime.now();

  test('age is the calendar age: a birthday five days from now has not '
      'happened yet this year', () {
    final soon = DateTime(now.year - 36, now.month, now.day + 5);
    expect(bornOn(soon).age, 35);
  });

  test('age turns over on the birthday itself', () {
    final today = DateTime(now.year - 36, now.month, now.day);
    expect(bornOn(today).age, 36);
  });

  test('the latest selectable birthday is exactly the minimum adult age ago', () {
    final last = ValueValidator.getLastDate();
    expect(last, DateTime(now.year - Ranges.minAgeYears, now.month, now.day));
    expect(bornOn(last).age, Ranges.minAgeYears);
  });
}
