import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/calories_profile_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/utils/calc/tdee_calc.dart';

import '../fixture/user_entity_fixtures.dart';

void main() {
  test('IOM TDEE calculation for a male user', () {
    // Mock a male user
    UserEntity user = UserEntity(
      birthday: DateTime(
        DateTime.now().year - 25,
        DateTime.now().month,
        DateTime.now().day - 1,
      ),
      heightCM: 180.0,
      weightKG: 80.0,
      gender: UserGenderEntity.male,
      goal: UserWeightGoalEntity.maintainWeight,
      pal: UserPALEntity.sedentary,
    );

    // Call the TDEE calculation method
    double userTdee = TDEECalc.getTDEEKcalIOM2005(user);

    // 864 – (9.72 × age [y]) + PA × (14.2 × weight [kg]
    // + 503 × height [m])

    // 864 - (9.72 * 25) + 1.0 *( 14,2 * 80) + 503 * 1.80 = 2662
    int expectedTdee = 2662;

    expect(userTdee.toInt(), expectedTdee);
  });

  test('IOM TDEE calculation for a female user', () {
    // Mock a female user
    UserEntity user =
        UserEntityFixtures.middleAgedActiveFemaleWantingToLoseWeight;

    // Call the TDEE calculation method
    double userTdee = TDEECalc.getTDEEKcalIOM2005(user);

    // 387 – (7.31 × age [y]) + PA × (10.9 × weight [kg]
    // + 660.7 × height [m])

    // 387 - (7.31 * 54) + 1.27 * (10.9 * 75 + 660.7 * 1.60) = 2373
    int expectedTdee = 2373;

    expect(userTdee.toInt(), expectedTdee);
  });

  group('IOM TDEE non-binary calculations', () {
    UserEntity baseUser({
      required UserGenderEntity gender,
      CaloriesProfileEntity? profile,
    }) {
      return UserEntity(
        birthday: DateTime(
          DateTime.now().year - 25,
          DateTime.now().month,
          DateTime.now().day - 1,
        ),
        heightCM: 180.0,
        weightKG: 80.0,
        gender: gender,
        goal: UserWeightGoalEntity.maintainWeight,
        pal: UserPALEntity.sedentary,
        caloriesProfile: profile,
      );
    }

    test('non-binary defaults to the mean of male and female outputs', () {
      final maleTdee =
          TDEECalc.getTDEEKcalIOM2005(baseUser(gender: UserGenderEntity.male));
      final femaleTdee =
          TDEECalc.getTDEEKcalIOM2005(baseUser(gender: UserGenderEntity.female));
      final nonBinaryDefault =
          TDEECalc.getTDEEKcalIOM2005(baseUser(gender: UserGenderEntity.nonBinary));

      expect(nonBinaryDefault, closeTo((maleTdee + femaleTdee) / 2, 0.001));
    });

    test('non-binary with averaged profile equals the default', () {
      final averaged = TDEECalc.getTDEEKcalIOM2005(baseUser(
        gender: UserGenderEntity.nonBinary,
        profile: CaloriesProfileEntity.averaged,
      ));
      final defaulted = TDEECalc.getTDEEKcalIOM2005(
          baseUser(gender: UserGenderEntity.nonBinary));
      expect(averaged, closeTo(defaulted, 0.001));
    });

    test('non-binary with estrogen-typical profile matches female formula', () {
      final estrogen = TDEECalc.getTDEEKcalIOM2005(baseUser(
        gender: UserGenderEntity.nonBinary,
        profile: CaloriesProfileEntity.estrogenTypical,
      ));
      final female =
          TDEECalc.getTDEEKcalIOM2005(baseUser(gender: UserGenderEntity.female));
      expect(estrogen, closeTo(female, 0.001));
    });

    test('non-binary with testosterone-typical profile matches male formula',
        () {
      final testosterone = TDEECalc.getTDEEKcalIOM2005(baseUser(
        gender: UserGenderEntity.nonBinary,
        profile: CaloriesProfileEntity.testosteroneTypical,
      ));
      final male =
          TDEECalc.getTDEEKcalIOM2005(baseUser(gender: UserGenderEntity.male));
      expect(testosterone, closeTo(male, 0.001));
    });
  });

  group('IOM TDEE non-binary at non-sedentary PALs (PA gender regression)', () {
    // Regression for the PA-gender bug: getPAValueFromPALValue used to read
    // userEntity.gender directly, so for a non-binary user the male half of
    // the averaged TDEE was computed with the female PA constant. The fix
    // routes each half through getPAValueForFormula with an explicit flag,
    // so the male half uses 1.12 / 1.54 and the female half uses 1.14 / 1.45
    // regardless of the user's stored gender enum.
    UserEntity buildUser(UserPALEntity pal,
        {CaloriesProfileEntity? profile, UserGenderEntity? gender}) {
      return UserEntity(
        birthday: DateTime(
          DateTime.now().year - 25,
          DateTime.now().month,
          DateTime.now().day - 1,
        ),
        heightCM: 180.0,
        weightKG: 80.0,
        gender: gender ?? UserGenderEntity.nonBinary,
        goal: UserWeightGoalEntity.maintainWeight,
        pal: pal,
        caloriesProfile: profile,
      );
    }

    test('lowActive averaged equals (binary male + binary female) / 2', () {
      final maleTdee =
          TDEECalc.getTDEEKcalIOM2005(buildUser(UserPALEntity.lowActive,
              gender: UserGenderEntity.male));
      final femaleTdee =
          TDEECalc.getTDEEKcalIOM2005(buildUser(UserPALEntity.lowActive,
              gender: UserGenderEntity.female));
      final averaged = TDEECalc.getTDEEKcalIOM2005(buildUser(
        UserPALEntity.lowActive,
        profile: CaloriesProfileEntity.averaged,
      ));
      expect(averaged, closeTo((maleTdee + femaleTdee) / 2, 0.001));
    });

    test('veryActive averaged equals (binary male + binary female) / 2', () {
      final maleTdee =
          TDEECalc.getTDEEKcalIOM2005(buildUser(UserPALEntity.veryActive,
              gender: UserGenderEntity.male));
      final femaleTdee =
          TDEECalc.getTDEEKcalIOM2005(buildUser(UserPALEntity.veryActive,
              gender: UserGenderEntity.female));
      final averaged = TDEECalc.getTDEEKcalIOM2005(buildUser(
        UserPALEntity.veryActive,
        profile: CaloriesProfileEntity.averaged,
      ));
      expect(averaged, closeTo((maleTdee + femaleTdee) / 2, 0.001));
    });

    test('lowActive averaged uses both PA constants — '
        'numerical pin (would fail with shared female PA = 1.14)', () {
      // Hand-computed expected for 80 kg / 180 cm / age 25 / lowActive (PAL 1.5),
      // PA multiplying both the weight and the height term:
      //   male half  = 864 - 9.72*25 + 1.12*(14.2*80 + 503*1.80)
      //              = 864 - 243   + 1.12*2041.4 = 2907.37
      //   female half= 387 - 7.31*25 + 1.14*(10.9*80 + 660.7*1.80)
      //              = 387 - 182.75 + 1.14*2061.26 = 2554.09
      //   averaged   = (2907.37 + 2554.09) / 2 ≈ 2730.73
      // A shared female PA (1.14) in the male half would give
      //   (864 - 243 + 1.14*2041.4 + 2554.09) / 2 ≈ 2751.15.
      final averaged = TDEECalc.getTDEEKcalIOM2005(buildUser(
        UserPALEntity.lowActive,
        profile: CaloriesProfileEntity.averaged,
      ));
      expect(averaged, closeTo(2730.73, 0.5));
    });

    test('estrogenTypical at lowActive uses female PA (1.14)', () {
      final estrogen = TDEECalc.getTDEEKcalIOM2005(buildUser(
        UserPALEntity.lowActive,
        profile: CaloriesProfileEntity.estrogenTypical,
      ));
      // 387 - 7.31*25 + 1.14*(10.9*80 + 660.7*1.80) ≈ 2554.09
      expect(estrogen, closeTo(2554.09, 0.5));
    });

    test('testosteroneTypical at veryActive uses male PA (1.54)', () {
      final testosterone = TDEECalc.getTDEEKcalIOM2005(buildUser(
        UserPALEntity.veryActive,
        profile: CaloriesProfileEntity.testosteroneTypical,
      ));
      // 864 - 9.72*25 + 1.54*(14.2*80 + 503*1.80)
      //   = 864 - 243 + 1.54*2041.4 = 3764.76
      expect(testosterone, closeTo(3764.76, 0.5));
    });
  });

  // QA 2026-10-19: in the IOM 2005 adult equations the PA coefficient
  // multiplies the weight AND the height term: men
  // TEE = 864 - 9.72*age + PA*(14.2*kg + 503*m), women
  // TEE = 387 - 7.31*age + PA*(10.9*kg + 660.7*m)
  // (https://www.cdc.gov/PCD/issues/2006/oct/06_0034.htm). Applying PA to
  // the weight term only understated every non-sedentary TDEE, by up to
  // ~490 kcal/day for a very active 180 cm man.
  group('IOM 2005: PA multiplies weight and height', () {
    UserEntity user(UserGenderEntity g, UserPALEntity pal, double kg, double cm) => UserEntity(
      birthday: DateTime(DateTime.now().year - 30, 1, 1),
      heightCM: cm,
      weightKG: kg,
      gender: g,
      goal: UserWeightGoalEntity.maintainWeight,
      pal: pal,
    );

    test('active man, 30 y, 80 kg, 180 cm', () {
      final u = user(UserGenderEntity.male, UserPALEntity.active, 80, 180);
      final expected = 864 - 9.72 * u.age + 1.27 * (14.2 * 80 + 503 * 1.80);
      expect(TDEECalc.getTDEEKcalIOM2005(u), closeTo(expected, 0.01));
    });

    test('low-active woman, 30 y, 60 kg, 165 cm', () {
      final u = user(UserGenderEntity.female, UserPALEntity.lowActive, 60, 165);
      final expected = 387 - 7.31 * u.age + 1.14 * (10.9 * 60 + 660.7 * 1.65);
      expect(TDEECalc.getTDEEKcalIOM2005(u), closeTo(expected, 0.01));
    });
  });

  group('Real-user kcal goal must differ from the old dummy fallback', () {
    // Regression for the onboarding race: when getUserData() returned the
    // hardcoded 80 kg / 180 cm / male / age 26 / active / maintain dummy,
    // the home screen showed ≈ 2959 kcal regardless of who the user was.
    // For a generic sedentary female with a lose-weight goal, the budget
    // must land far below that — otherwise we have regressed back to
    // pulling the dummy.
    test('female / sedentary / lose-weight produces a budget well below the '
        'old male / active / maintain dummy', () {
      final user = UserEntity(
        birthday: DateTime(
          DateTime.now().year - 35,
          DateTime.now().month,
          DateTime.now().day - 1,
        ),
        heightCM: 165.0,
        weightKG: 70.0,
        gender: UserGenderEntity.female,
        goal: UserWeightGoalEntity.loseWeight,
        pal: UserPALEntity.sedentary,
      );

      final totalGoal = CalorieGoalCalc.getTotalKcalGoal(user, 0);
      // BMR = 387 - 7.31*35 + 1.0*10.9*70 + 660.7*1.65
      //     = 387 - 255.85 + 763.0 + 1090.155 ≈ 1984.3
      // Total goal = 1984.3 - 500 ≈ 1484.3 — well below the dummy's 2959.
      expect(totalGoal, lessThan(1700));
      expect(totalGoal, greaterThan(1300));
    });
  });
}
