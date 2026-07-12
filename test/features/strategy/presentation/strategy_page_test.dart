import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/features/strategy/presentation/strategy_page.dart';
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

class _FakeConfigRepository extends Fake implements ConfigRepository {
  @override
  Future<ConfigEntity> getConfig() async {
    return ConfigEntity(false, false, false, AppThemeEntity.dark);
  }
}

class _FakeAddUserUsecase extends Fake implements AddUserUsecase {
  UserEntity? lastSaved;

  @override
  Future<void> addUser(UserEntity userEntity) async {
    lastSaved = userEntity;
  }
}

UserEntity _buildUser() {
  return UserEntity(
    birthday: DateTime(1990, 1, 1),
    heightCM: 178,
    weightKG: 84,
    gender: UserGenderEntity.male,
    goal: UserWeightGoalEntity.loseWeight,
    pal: UserPALEntity.lowActive,
    weeklyWeightGoalKg: -0.5,
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

Widget _buildScreen({
  required List<WeightLogEntity> weightEntries,
  List<TrackedDayEntity> trackedDays = const [],
  UserEntity? user,
  AddUserUsecase? addUserUsecase,
}) {
  return StrategyPage(
    getWeightLogUsecase: _FakeGetWeightLogUsecase(weightEntries),
    getUserUsecase: _FakeGetUserUsecase(user ?? _buildUser()),
    getTrackedDayUsecase: _FakeGetTrackedDayUsecase(trackedDays),
    configRepository: _FakeConfigRepository(),
    addUserUsecase: addUserUsecase ?? _FakeAddUserUsecase(),
  );
}

void main() {
  group('StrategyPage', () {
    testWidgets('shows the empty-state copy with fewer than two weigh-ins', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_buildScreen(weightEntries: const [])));
      await tester.pumpAndSettle();

      expect(find.text(S.current.strategyEmptyState), findsOneWidget);
      expect(find.byKey(const Key('strategy-weight-chart')), findsNothing);
    });

    testWidgets(
      'renders the dashboard (chart, estimator status, metrics, weekly '
      'rate) once there is enough weight history',
      (tester) async {
        final today = DateTime.now();
        DateTime day(int daysAgo) {
          final d = today.subtract(Duration(days: daysAgo));
          return DateTime(d.year, d.month, d.day);
        }

        final weightEntries = [
          WeightLogEntity(date: day(20), weightKg: 86.0),
          WeightLogEntity(date: day(10), weightKg: 85.0),
          WeightLogEntity(date: day(0), weightKg: 84.0),
        ];
        final trackedDays = [
          for (var i = 0; i <= 20; i++)
            TrackedDayEntity(
              day: day(i),
              calorieGoal: 2400,
              caloriesTracked: 2300,
            ),
        ];

        // The dashboard is taller than the default test viewport (chips +
        // chart + estimator card + metrics grid + weekly rate card), so
        // widgets past the fold wouldn't otherwise mount into the element
        // tree for find.text to see.
        tester.view.physicalSize = const Size(1080, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrap(
            _buildScreen(
              weightEntries: weightEntries,
              trackedDays: trackedDays,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(S.current.strategyEmptyState), findsNothing);
        expect(find.text(S.current.strategyEstimatedTdeeLabel), findsOneWidget);
        expect(find.text(S.current.strategyStaticTdeeLabel), findsOneWidget);
        expect(find.text(S.current.strategyCurrentTargetLabel), findsOneWidget);
        expect(find.text(S.current.strategyTrendWeightLabel), findsOneWidget);
        expect(find.text(S.current.strategyWeeklyRateTitle), findsOneWidget);
        expect(find.text(S.current.strategyDesiredRateLabel), findsOneWidget);
        expect(find.text(S.current.strategyObservedRateLabel), findsOneWidget);
        // Losing weight consistently -> the estimator has enough signal.
        expect(
          find.text(S.current.strategyEstimatorStatusActiveLabel),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping the desired-rate row opens the weekly goal dialog, and '
      'Reset clears the goal and persists + refreshes the UI',
      (tester) async {
        final today = DateTime.now();
        DateTime day(int daysAgo) {
          final d = today.subtract(Duration(days: daysAgo));
          return DateTime(d.year, d.month, d.day);
        }

        final weightEntries = [
          WeightLogEntity(date: day(20), weightKg: 86.0),
          WeightLogEntity(date: day(0), weightKg: 84.0),
        ];
        final user = _buildUser();
        final fakeAddUserUsecase = _FakeAddUserUsecase();

        tester.view.physicalSize = const Size(1080, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrap(
            _buildScreen(
              weightEntries: weightEntries,
              user: user,
              addUserUsecase: fakeAddUserUsecase,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(user.weeklyWeightGoalKg, -0.5);
        await tester.tap(find.text(S.current.strategyDesiredRateLabel));
        await tester.pumpAndSettle();

        expect(
          find.text(S.current.chooseWeeklyWeightGoalLabel),
          findsOneWidget,
        );
        expect(
          find.text(S.current.weeklyWeightGoalExplanation),
          findsOneWidget,
        );

        await tester.tap(find.text(S.current.buttonResetLabel));
        await tester.pumpAndSettle();

        expect(find.text(S.current.chooseWeeklyWeightGoalLabel), findsNothing);
        expect(fakeAddUserUsecase.lastSaved?.weeklyWeightGoalKg, isNull);
        expect(user.weeklyWeightGoalKg, isNull);
      },
    );

    testWidgets('switching the chart range chip does not throw', (
      tester,
    ) async {
      final today = DateTime.now();
      DateTime day(int daysAgo) {
        final d = today.subtract(Duration(days: daysAgo));
        return DateTime(d.year, d.month, d.day);
      }

      final weightEntries = [
        WeightLogEntity(date: day(20), weightKg: 86.0),
        WeightLogEntity(date: day(0), weightKg: 84.0),
      ];

      await tester.pumpWidget(
        _wrap(_buildScreen(weightEntries: weightEntries)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.strategyRangeThreeMonths));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
