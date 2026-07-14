import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/dbo/calories_profile_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_gender_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_pal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_weight_goal_dbo.dart';

// UserDBO gained @JsonSerializable() for the cloud-backup snapshot (Fase
// Cuenta, FA-11). Every other DBO the export/import path touches already
// had JSON coverage exercised indirectly through the export/import zip
// round trip; UserBox has no such path today, so this is the only place
// verifying its toJson()/fromJson() actually round-trips.
void main() {
  group('UserDBO JSON round-trip', () {
    test(
      'every field, including nested enums, survives toJson -> fromJson',
      () {
        final original = UserDBO(
          birthday: DateTime(1990, 5, 20),
          heightCM: 178.5,
          weightKG: 82.3,
          gender: UserGenderDBO.nonBinary,
          goal: UserWeightGoalDBO.loseWeight,
          pal: UserPALDBO.active,
          weeklyWeightGoalKg: -0.5,
          caloriesProfile: CaloriesProfileDBO.testosteroneTypical,
          targetWeightKg: 75.0,
          caloriesTaperEnabled: true,
        );

        final restored = UserDBO.fromJson(original.toJson());

        expect(restored.birthday, original.birthday);
        expect(restored.heightCM, original.heightCM);
        expect(restored.weightKG, original.weightKG);
        expect(restored.gender, UserGenderDBO.nonBinary);
        expect(restored.goal, UserWeightGoalDBO.loseWeight);
        expect(restored.pal, UserPALDBO.active);
        expect(restored.weeklyWeightGoalKg, original.weeklyWeightGoalKg);
        expect(
          restored.caloriesProfile,
          CaloriesProfileDBO.testosteroneTypical,
        );
        expect(restored.targetWeightKg, original.targetWeightKg);
        expect(restored.caloriesTaperEnabled, isTrue);
      },
    );

    test('nullable fields stay null after round-trip', () {
      final original = UserDBO(
        birthday: DateTime(1985, 1, 1),
        heightCM: 165.0,
        weightKG: 60.0,
        gender: UserGenderDBO.female,
        goal: UserWeightGoalDBO.maintainWeight,
        pal: UserPALDBO.sedentary,
      );

      final restored = UserDBO.fromJson(original.toJson());

      expect(restored.weeklyWeightGoalKg, isNull);
      expect(restored.caloriesProfile, isNull);
      expect(restored.targetWeightKg, isNull);
      expect(restored.caloriesTaperEnabled, isFalse);
    });
  });
}
