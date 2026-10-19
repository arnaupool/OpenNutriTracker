import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/features/home/presentation/widgets/goal_progress_card.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _FakeGetWeightLogUsecase extends Fake implements GetWeightLogUsecase {
  final List<WeightLogEntity> _entries;
  _FakeGetWeightLogUsecase(this._entries);

  @override
  Future<List<WeightLogEntity>> getAllEntries() async => List.of(_entries);
}

class _FakeGetUserUsecase extends Fake implements GetUserUsecase {
  final UserEntity _user;
  _FakeGetUserUsecase(this._user);

  @override
  Future<UserEntity> getUserData() async => _user;
}

class _FakeGetTrackedDayUsecase extends Fake implements GetTrackedDayUsecase {
  final List<TrackedDayEntity> _days;
  _FakeGetTrackedDayUsecase(this._days);

  @override
  Future<List<TrackedDayEntity>> getTrackedDaysByRange(
    DateTime start,
    DateTime end,
  ) async {
    return _days
        .where((d) => !d.day.isBefore(start) && !d.day.isAfter(end))
        .toList();
  }
}

UserEntity _buildUser({
  UserWeightGoalEntity goal = UserWeightGoalEntity.loseWeight,
  double? targetWeightKg,
}) {
  return UserEntity(
    birthday: DateTime(1990, 1, 1),
    heightCM: 178,
    weightKG: 84,
    gender: UserGenderEntity.male,
    goal: goal,
    pal: UserPALEntity.lowActive,
    weeklyWeightGoalKg: -0.5,
    targetWeightKg: targetWeightKg,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(body: child),
  );
}

Widget _buildCard({
  required List<WeightLogEntity> weightEntries,
  List<TrackedDayEntity> trackedDays = const [],
  UserEntity? user,
}) {
  return GoalProgressCard(
    getWeightLogUsecase: _FakeGetWeightLogUsecase(weightEntries),
    getUserUsecase: _FakeGetUserUsecase(user ?? _buildUser()),
    getTrackedDayUsecase: _FakeGetTrackedDayUsecase(trackedDays),
  );
}

void main() {
  group('GoalProgressCard', () {
    testWidgets(
      'shows the insufficient-data message with fewer trend points than '
      'TdeeDynamicCalc.minTrendPointsForDynamic',
      (tester) async {
        final today = DateTime.now();
        DateTime day(int daysAgo) {
          final d = today.subtract(Duration(days: daysAgo));
          return DateTime(d.year, d.month, d.day);
        }

        final weightEntries = [
          WeightLogEntity(date: day(2), weightKg: 84.5),
          WeightLogEntity(date: day(1), weightKg: 84.3),
          WeightLogEntity(date: day(0), weightKg: 84.0),
        ];

        await tester.pumpWidget(
          _wrap(_buildCard(weightEntries: weightEntries)),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(S.current.homeGoalProgressInsufficientData),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows the weekly-rate explanation once there is enough trend and a '
      'target weight far from the current trend (FM-14)',
      (tester) async {
        final today = DateTime.now();
        DateTime day(int daysAgo) {
          final d = today.subtract(Duration(days: daysAgo));
          return DateTime(d.year, d.month, d.day);
        }

        final weightEntries = [
          for (var i = 20; i >= 0; i--)
            WeightLogEntity(date: day(i), weightKg: 84.0),
        ];
        final trackedDays = [
          for (var i = 0; i <= 20; i++)
            TrackedDayEntity(
              day: day(i),
              calorieGoal: 2400,
              caloriesTracked: 2300,
            ),
        ];

        await tester.pumpWidget(
          _wrap(
            _buildCard(
              weightEntries: weightEntries,
              trackedDays: trackedDays,
              user: _buildUser(targetWeightKg: 78.0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(S.current.homeGoalProgressInsufficientData),
          findsNothing,
        );
        expect(
          find.textContaining('% of body weight per week'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows the maintaining explanation when the goal is maintainWeight',
      (tester) async {
        final today = DateTime.now();
        DateTime day(int daysAgo) {
          final d = today.subtract(Duration(days: daysAgo));
          return DateTime(d.year, d.month, d.day);
        }

        final weightEntries = [
          for (var i = 20; i >= 0; i--)
            WeightLogEntity(date: day(i), weightKg: 84.0),
        ];
        final trackedDays = [
          for (var i = 0; i <= 20; i++)
            TrackedDayEntity(
              day: day(i),
              calorieGoal: 2400,
              caloriesTracked: 2300,
            ),
        ];

        await tester.pumpWidget(
          _wrap(
            _buildCard(
              weightEntries: weightEntries,
              trackedDays: trackedDays,
              user: _buildUser(goal: UserWeightGoalEntity.maintainWeight),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(S.current.strategyExplanationMaintaining),
          findsOneWidget,
        );
      },
    );
  });
}
