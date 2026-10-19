import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
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

class _FakeGetKcalGoalUsecase extends Fake implements GetKcalGoalUsecase {
  final double _kcalGoal;
  final ({bool isDue, DateTime nextCheckInDay, int weekday})? _checkIn;
  final double? _recommended;
  _FakeGetKcalGoalUsecase(
    this._kcalGoal, {
    ({bool isDue, DateTime nextCheckInDay, int weekday})? checkIn,
    double? recommended,
  }) : _checkIn = checkIn,
       _recommended = recommended;

  @override
  Future<double> getKcalGoal({
    UserEntity? userEntity,
    double? kcalUserAdjustment,
  }) async => _kcalGoal;

  @override
  Future<({bool isDue, DateTime nextCheckInDay, int weekday})?>
  getCheckInStatus() async => _checkIn;

  @override
  Future<double> getRecommendedKcalGoal({UserEntity? userEntity}) async =>
      _recommended ?? _kcalGoal;
}

class _FakeGetMacroGoalUsecase extends Fake implements GetMacroGoalUsecase {
  final double _proteinG;
  final double _fatG;
  final double _carbG;
  _FakeGetMacroGoalUsecase({
    double proteinG = 150,
    double fatG = 70,
    double carbG = 250,
  }) : _proteinG = proteinG,
       _fatG = fatG,
       _carbG = carbG;

  @override
  Future<double> getProteinsGoal(double totalCalorieGoal) async => _proteinG;
  @override
  Future<double> getFatsGoal(double totalCalorieGoal) async => _fatG;
  @override
  Future<double> getCarbsGoal(double totalCalorieGoal) async => _carbG;
}

UserEntity _buildUser({double? targetWeightKg}) {
  return UserEntity(
    birthday: DateTime(1990, 1, 1),
    heightCM: 178,
    weightKG: 84,
    gender: UserGenderEntity.male,
    goal: UserWeightGoalEntity.loseWeight,
    pal: UserPALEntity.lowActive,
    weeklyWeightGoalKg: -0.5,
    targetWeightKg: targetWeightKg,
  );
}

Widget _wrap(Widget child) {
  return ChangeNotifierProvider<EnergyUnitProvider>(
    create: (_) => EnergyUnitProvider(),
    child: MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(body: child),
  ),
  );
}

Widget _buildScreen({
  required List<WeightLogEntity> weightEntries,
  List<TrackedDayEntity> trackedDays = const [],
  UserEntity? user,
  double kcalGoal = 2400,
  ({bool isDue, DateTime nextCheckInDay, int weekday})? checkIn,
  double? recommendedKcal,
}) {
  return StrategyPage(
    getWeightLogUsecase: _FakeGetWeightLogUsecase(weightEntries),
    getUserUsecase: _FakeGetUserUsecase(user ?? _buildUser()),
    getTrackedDayUsecase: _FakeGetTrackedDayUsecase(trackedDays),
    configRepository: _FakeConfigRepository(),
    getKcalGoalUsecase: _FakeGetKcalGoalUsecase(
      kcalGoal,
      checkIn: checkIn,
      recommended: recommendedKcal,
    ),
    getMacroGoalUsecase: _FakeGetMacroGoalUsecase(),
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
      'renders the dashboard (chart, estimator status, today\'s target, '
      'macro distribution) once there is enough weight history',
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
        // chart + estimator card + today's-target card + macro chart), so
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
        expect(find.text(S.current.strategyTrendWeightLabel), findsOneWidget);
        expect(find.text(S.current.strategyTodayTargetLabel), findsOneWidget);
        expect(find.text('2400 ${S.current.kcalLabel}'), findsOneWidget);
        expect(
          find.text(S.current.strategyMacroDistributionTitle),
          findsOneWidget,
        );
        // Losing weight consistently -> the estimator has enough signal.
        expect(
          find.text(S.current.strategyEstimatorStatusActiveLabel),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows the maintenance-band explanation when a target weight is set '
      'and the trend is within 0.7 kg of it',
      (tester) async {
        final today = DateTime.now();
        DateTime day(int daysAgo) {
          final d = today.subtract(Duration(days: daysAgo));
          return DateTime(d.year, d.month, d.day);
        }

        final weightEntries = [
          WeightLogEntity(date: day(20), weightKg: 84.2),
          WeightLogEntity(date: day(10), weightKg: 84.1),
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

        tester.view.physicalSize = const Size(1080, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrap(
            _buildScreen(
              weightEntries: weightEntries,
              trackedDays: trackedDays,
              user: _buildUser(targetWeightKg: 84.0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(S.current.strategyExplanationWithinBand('0.7 kg')),
          findsOneWidget,
        );
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

    testWidgets(
      'offers 1Y and All range chips, and All renders a chart spanning a '
      'multi-year weigh-in history without throwing',
      (tester) async {
        final today = DateTime.now();
        DateTime day(int daysAgo) {
          final d = today.subtract(Duration(days: daysAgo));
          return DateTime(d.year, d.month, d.day);
        }

        // Five years of history: 6M/1Y ranges would clip this to just the
        // last entries, so "All" is the only chip that can show all of it.
        final weightEntries = [
          WeightLogEntity(date: day(5 * 365), weightKg: 95.0),
          WeightLogEntity(date: day(365), weightKg: 88.0),
          WeightLogEntity(date: day(0), weightKg: 84.0),
        ];

        tester.view.physicalSize = const Size(1080, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrap(_buildScreen(weightEntries: weightEntries)),
        );
        await tester.pumpAndSettle();

        expect(find.text(S.current.strategyRangeOneYear), findsOneWidget);
        expect(find.text(S.current.strategyRangeAllTime), findsOneWidget);
        expect(find.byType(LineChart), findsOneWidget);

        await tester.tap(find.text(S.current.strategyRangeAllTime));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(LineChart), findsOneWidget);

        await tester.tap(find.text(S.current.strategyRangeOneYear));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(LineChart), findsOneWidget);
      },
    );

    // FM-15: weekly check-in card.
    List<WeightLogEntity> twoWeighIns() {
      final today = DateTime.now();
      final d = DateTime(today.year, today.month, today.day);
      return [
        WeightLogEntity(date: d.subtract(const Duration(days: 1)), weightKg: 84.2),
        WeightLogEntity(date: d, weightKg: 84.0),
      ];
    }

    testWidgets('a due check-in offers the new target and both choices', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _buildScreen(
            weightEntries: twoWeighIns(),
            kcalGoal: 2400,
            recommendedKcal: 2250,
            checkIn: (
              isDue: true,
              nextCheckInDay: DateTime(2026, 10, 19),
              weekday: DateTime.monday,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(S.current.strategyCheckInDue('2250 kcal', '2400 kcal')), findsOneWidget);
      expect(find.text(S.current.strategyCheckInApply), findsOneWidget);
      expect(find.text(S.current.strategyCheckInKeep), findsOneWidget);
    });

    testWidgets('between check-ins the card shows the next check-in date', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _buildScreen(
            weightEntries: twoWeighIns(),
            checkIn: (
              isDue: false,
              nextCheckInDay: DateTime(2026, 10, 26),
              weekday: DateTime.monday,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Next check-in:'), findsOneWidget);
      expect(find.text(S.current.strategyCheckInApply), findsNothing);
    });
  });
}
