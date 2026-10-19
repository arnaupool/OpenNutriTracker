import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_data_source.dart';
import 'package:opennutritracker/core/data/data_source/weight_log_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/physical_activity_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_gender_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_pal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_weight_goal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/utils/calc/dynamic_maintenance_calc.dart';
import 'package:opennutritracker/core/utils/calc/macro_dynamic_calc.dart';
import 'package:opennutritracker/core/utils/calc/tdee_dynamic_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_interpolation_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_trend_calc.dart';

import '../helpers/hive_test_setup.dart';

// FM-06/FM-07: covers the *decision tree* GetKcalGoalUsecase/
// GetMacroGoalUsecase now run — dynamic-if-trustworthy, phased by
// distance-to-goal, falling back to the untouched static formula
// otherwise. The underlying calc math (EWMA, TdeeDynamicCalc,
// DynamicMaintenanceCalc, MacroDynamicCalc) is weight_motor_engine_test's
// job; this file is about proving the *wiring* picks the right branch.
void main() {
  late Box<UserDBO> userBox;
  late Box<ConfigDBO> configBox;
  late Box<WeightLogDBO> weightLogBox;
  late Box<TrackedDayDBO> trackedDayBox;
  late Box<UserActivityDBO> activityBox;

  late GetKcalGoalUsecase getKcalGoalUsecase;
  late GetMacroGoalUsecase getMacroGoalUsecase;
  late UserDataSource userDataSource;
  late WeightLogDataSource weightLogDataSource;
  late WeightLogRepository weightLogRepository;
  late TrackedDayDataSource trackedDayDataSource;
  late ConfigDataSource configDataSource;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('.');
    registerHiveAdaptersOnce();
  });

  setUp(() async {
    final suffix = '${DateTime.now().microsecondsSinceEpoch}';
    userBox = await Hive.openBox<UserDBO>('kcal_wiring_user_$suffix');
    configBox = await Hive.openBox<ConfigDBO>('kcal_wiring_config_$suffix');
    weightLogBox = await Hive.openBox<WeightLogDBO>(
      'kcal_wiring_weight_$suffix',
    );
    trackedDayBox = await Hive.openBox<TrackedDayDBO>(
      'kcal_wiring_tracked_$suffix',
    );
    activityBox = await Hive.openBox<UserActivityDBO>(
      'kcal_wiring_activity_$suffix',
    );

    userDataSource = UserDataSource(userBox);
    weightLogDataSource = WeightLogDataSource(weightLogBox);
    weightLogRepository = WeightLogRepository(weightLogDataSource);
    trackedDayDataSource = TrackedDayDataSource(trackedDayBox);
    configDataSource = ConfigDataSource(configBox);
    await configDataSource.initializeConfig();

    getKcalGoalUsecase = GetKcalGoalUsecase(
      UserRepository(userDataSource),
      ConfigRepository(configDataSource),
      weightLogRepository,
      TrackedDayRepository(trackedDayDataSource),
    );
    getMacroGoalUsecase = GetMacroGoalUsecase(
      ConfigRepository(configDataSource),
      UserRepository(userDataSource),
    );
  });

  tearDown(() async {
    await userBox.deleteFromDisk();
    await configBox.deleteFromDisk();
    await weightLogBox.deleteFromDisk();
    await trackedDayBox.deleteFromDisk();
    await activityBox.deleteFromDisk();
  });

  UserDBO baseUser({
    UserWeightGoalDBO goal = UserWeightGoalDBO.loseWeight,
    double? targetWeightKg,
    double? weeklyWeightGoalKg,
    double weightKg = 84.0,
  }) => UserDBO(
    birthday: DateTime(1994, 1, 1),
    heightCM: 178,
    weightKG: weightKg,
    gender: UserGenderDBO.male,
    goal: goal,
    pal: UserPALDBO.lowActive,
    targetWeightKg: targetWeightKg,
    weeklyWeightGoalKg: weeklyWeightGoalKg,
  );

  // GetKcalGoalUsecase's intake lookback window is relative to
  // DateTime.now() (today, whenever the suite actually runs) — not a
  // fixed calendar date — so seeded history has to be anchored the same
  // way, or it silently falls outside the window and the "dynamic" path
  // never activates.
  final todayMidnight = DateTime.now();
  DateTime daysAgo(int n) => DateTime(
    todayMidnight.year,
    todayMidnight.month,
    todayMidnight.day,
  ).subtract(Duration(days: n));

  Future<void> seedStepHistory({
    required int days,
    required double dailyIntakeKcal,
    int endDaysAgo = 0,
  }) async {
    await weightLogDataSource.addEntry(
      WeightLogDBO(date: daysAgo(endDaysAgo + days - 1), weightKg: 88.0),
    );
    for (var daysBack = days - 2; daysBack >= 0; daysBack--) {
      await weightLogDataSource.addEntry(
        WeightLogDBO(date: daysAgo(endDaysAgo + daysBack), weightKg: 84.0),
      );
    }
    for (var daysBack = days - 1; daysBack >= 0; daysBack--) {
      await trackedDayDataSource.saveTrackedDay(
        TrackedDayDBO(
          day: daysAgo(endDaysAgo + daysBack),
          calorieGoal: dailyIntakeKcal,
          caloriesTracked: dailyIntakeKcal,
        ),
      );
    }
  }

  /// Seeds a 10-day weight trend — above the 7-point floor where the
  /// dynamic estimate starts blending in, but below
  /// TdeeDynamicCalc.fullyMatureTrendPoints (21) where it's blended in
  /// *fully* — that steps from 88kg to 84kg, ending today, plus matching
  /// intake so TdeeDynamicCalc.estimateTdee has real data to read —
  /// mirrors the step-response shape weight_motor_engine_test already
  /// validated the math against. Used by the tests that specifically
  /// exercise the static/dynamic *blend ramp* itself.
  Future<void> seedTenDayHistory({double dailyIntakeKcal = 2600}) async {
    await seedStepHistory(days: 10, dailyIntakeKcal: dailyIntakeKcal);
  }

  /// Same step shape as [seedTenDayHistory], but long enough (25 days)
  /// to clear TdeeDynamicCalc.fullyMatureTrendPoints (21) — the dynamic
  /// estimate is blended in at 100%, so tests using this can assert
  /// against the pure dynamic branch without also reasoning about the
  /// blend ramp.
  Future<void> seedMatureHistory({double dailyIntakeKcal = 2600}) async {
    await seedStepHistory(days: 25, dailyIntakeKcal: dailyIntakeKcal);
  }

  /// Recomputes exactly what the dynamic branch should have produced
  /// (post-smoothing, matching what GetKcalGoalUsecase actually calls),
  /// independently of GetKcalGoalUsecase, to compare against.
  Future<double> expectedDynamicTdee() async {
    final entries = await weightLogRepository.getAllEntries();
    final trend = WeightTrendCalc.computeTrend(
      WeightInterpolationCalc.fillGaps(entries),
    );
    final trackedDays = await trackedDayDataSource.getAllTrackedDays();
    final intake = {
      for (final d in trackedDays)
        DateTime(d.day.year, d.day.month, d.day.day): d.caloriesTracked,
    };
    return TdeeDynamicCalc.estimateTdeeSmoothed(
      trendSeries: trend,
      dailyIntakeKcal: intake,
    )!;
  }

  group('GetKcalGoalUsecase — dynamic vs. static branch selection', () {
    test('no weight history at all falls back to the untouched static '
        'formula', () async {
      await userDataSource.saveUserData(baseUser());

      final goal = await getKcalGoalUsecase.getKcalGoal();

      final expectedStatic = CalorieGoalCalc.getTotalKcalGoal(
        (await UserRepository(userDataSource).getUserData()),
        0,
      );
      expect(goal, closeTo(expectedStatic, 0.01));
    });

    test('fewer than 7 trend points still falls back to static even '
        'though TdeeDynamicCalc itself would return a value', () async {
      await userDataSource.saveUserData(baseUser());
      // Only 3 days — TdeeDynamicCalc.estimateTdee needs just 2 to return
      // *something*, but GetKcalGoalUsecase's own stability threshold is
      // higher than that.
      await weightLogDataSource.addEntry(
        WeightLogDBO(date: daysAgo(2), weightKg: 88.0),
      );
      await weightLogDataSource.addEntry(
        WeightLogDBO(date: daysAgo(1), weightKg: 87.5),
      );
      await weightLogDataSource.addEntry(
        WeightLogDBO(date: daysAgo(0), weightKg: 87.0),
      );
      for (var daysBack = 2; daysBack >= 0; daysBack--) {
        await trackedDayDataSource.saveTrackedDay(
          TrackedDayDBO(
            day: daysAgo(daysBack),
            calorieGoal: 2600,
            caloriesTracked: 2600,
          ),
        );
      }

      final goal = await getKcalGoalUsecase.getKcalGoal();
      final expectedStatic = CalorieGoalCalc.getTotalKcalGoal(
        await UserRepository(userDataSource).getUserData(),
        0,
      );
      expect(goal, closeTo(expectedStatic, 0.01));
    });

    // FM-14 (AUDIT.md B3): MacroFactor sets lose/gain goals as a percentage
    // of body weight per week and subtracts the implied deficit from the
    // expenditure (help.macrofactorapp.com art. 222); the 0.15%/week nudge
    // belongs to the maintenance goal (art. 125). Default rate 0.5%/week.
    double rateKcalPerDay(double trendWeightKg, double ratePct) =>
        ratePct / 100 * trendWeightKg * DynamicMaintenanceCalc.kcalPerKgBodyMass / 7;

    Future<double> currentTrendWeight() async {
      final entries = await weightLogRepository.getAllEntries();
      return WeightTrendCalc.computeTrend(
        WeightInterpolationCalc.fillGaps(entries),
      ).last.trendWeightKg;
    }

    test('lose weight far from the target subtracts the deficit of the '
        'chosen % of body weight per week from the dynamic TDEE', () async {
      await userDataSource.saveUserData(
        baseUser(targetWeightKg: 75.0), // >0.7kg from the ~84kg trend
      );
      await seedMatureHistory();

      final goal = await getKcalGoalUsecase.getKcalGoal();

      final tdee = await expectedDynamicTdee();
      final trendKg = await currentTrendWeight();
      expect(goal, closeTo(tdee - rateKcalPerDay(trendKg, 0.5), 0.01));
      // Not the maintenance nudge any more.
      final nudge = DynamicMaintenanceCalc.recommendedKcal(
        trendWeightKg: trendKg,
        goalWeightKg: 75.0,
        tdeeKcal: tdee,
      );
      expect(goal, isNot(closeTo(nudge, 5)));
    });

    test('lose weight already within the band of the target maintains at '
        'the dynamic TDEE', () async {
      await userDataSource.saveUserData(baseUser(targetWeightKg: 84.0));
      await seedMatureHistory();

      final goal = await getKcalGoalUsecase.getKcalGoal();
      expect(goal, closeTo(await expectedDynamicTdee(), 0.01));
    });

    test('maintain with the trend outside the band of the target applies '
        "MacroFactor's 0.15%/week dynamic maintenance nudge", () async {
      await userDataSource.saveUserData(
        baseUser(goal: UserWeightGoalDBO.maintainWeight, targetWeightKg: 80.0),
      );
      await seedMatureHistory();

      final goal = await getKcalGoalUsecase.getKcalGoal();
      final tdee = await expectedDynamicTdee();
      final expected = DynamicMaintenanceCalc.recommendedKcal(
        trendWeightKg: await currentTrendWeight(),
        goalWeightKg: 80.0,
        tdeeKcal: tdee,
      );
      expect(goal, closeTo(expected, 0.01));
      expect(goal, lessThan(tdee - 50));
    });

    test(
      'maintain goal uses the dynamic TDEE directly, no correction',
      () async {
        await userDataSource.saveUserData(
          baseUser(goal: UserWeightGoalDBO.maintainWeight),
        );
        await seedMatureHistory();

        final goal = await getKcalGoalUsecase.getKcalGoal();
        final tdee = await expectedDynamicTdee();
        expect(goal, closeTo(tdee, 0.01));
      },
    );

    test('lose weight with no target weight still uses the % rate on top '
        'of the dynamic TDEE', () async {
      await userDataSource.saveUserData(baseUser()); // no targetWeightKg
      await seedMatureHistory();

      final goal = await getKcalGoalUsecase.getKcalGoal();
      final tdee = await expectedDynamicTdee();
      final trendKg = await currentTrendWeight();
      expect(goal, closeTo(tdee - rateKcalPerDay(trendKg, 0.5), 0.01));
    });

    test('between the noise floor and full maturity, the goal is a linear '
        'blend of static and dynamic — not an all-or-nothing snap', () async {
      final user = baseUser(goal: UserWeightGoalDBO.maintainWeight);
      await userDataSource.saveUserData(user);
      await seedTenDayHistory(); // 10 trend points: floor=7, mature=21

      final goal = await getKcalGoalUsecase.getKcalGoal();

      final staticGoal = CalorieGoalCalc.getTotalKcalGoal(
        await UserRepository(userDataSource).getUserData(),
        0,
      );
      final dynamicTdee = await expectedDynamicTdee();
      // 10 trend points, floor 7, mature 21 -> (10-7)/(21-7) = 3/14.
      const expectedBlendWeight = 3 / 14;
      final expectedGoal =
          staticGoal + expectedBlendWeight * (dynamicTdee - staticGoal);

      expect(goal, closeTo(expectedGoal, 0.01));
      // Sanity: sits strictly between the two pure branches, not equal
      // to either — proves this is really a blend, not a coincidence.
      expect(goal, isNot(closeTo(staticGoal, 1.0)));
      expect(goal, isNot(closeTo(dynamicTdee, 1.0)));
    });

    // FM-12 (AUDIT.md B1): MacroFactor estimates expenditure from intake and
    // trend weight only, so exercise is already inside the observed TDEE;
    // adding today's logged activities on top counted it twice.
    for (final mature in [false, true]) {
      test('a logged activity today does not raise the goal '
          '(${mature ? 'dynamic' : 'static'} path)', () async {
        await userDataSource.saveUserData(
          baseUser(goal: UserWeightGoalDBO.maintainWeight),
        );
        if (mature) await seedMatureHistory();
        final before = await getKcalGoalUsecase.getKcalGoal();

        await UserActivityDataSource(activityBox).addUserActivity(
          UserActivityDBO(
            'fm12-ride',
            60,
            677,
            DateTime.now(),
            PhysicalActivityDBO(
              'bicycling_mountain',
              'bicycling, mountain',
              'general',
              8.5,
              [],
              PhysicalActivityTypeDBO.bicycling,
            ),
          ),
        );

        final after = await getKcalGoalUsecase.getKcalGoal();
        expect(after, closeTo(before, 0.01));
      });
    }

    // FM-13 (AUDIT.md B2): MacroFactor V3 pauses expenditure updates when
    // more than 3 of the last 7 days lack nutrition data, and after a gap
    // carries the last high-confidence value forward. The goal must stay
    // what it was on the last logged day instead of drifting while the
    // intake lookback slides, and must not snap back to the static formula.
    for (final gapDays in [5, 30]) {
      test('$gapDays days without logging keeps the goal as it stood on the '
          'last logged day', () async {
        await userDataSource.saveUserData(
          baseUser(goal: UserWeightGoalDBO.maintainWeight),
        );
        await seedStepHistory(
          days: 25,
          dailyIntakeKcal: 2600,
          endDaysAgo: gapDays,
        );

        final lastLogged = daysAgo(gapDays);
        final trend = WeightTrendCalc.computeTrend(
          WeightInterpolationCalc.fillGaps(
            await weightLogRepository.getAllEntries(),
          ),
        );
        final trackedDays = await trackedDayDataSource.getAllTrackedDays();
        final intakeAsOfLastLogged = {
          for (final d in trackedDays)
            if (!d.day.isBefore(lastLogged.subtract(const Duration(days: 25))))
              DateTime(d.day.year, d.day.month, d.day.day): d.caloriesTracked,
        };
        final expected = TdeeDynamicCalc.estimateTdeeSmoothed(
          trendSeries: trend,
          dailyIntakeKcal: intakeAsOfLastLogged,
        )!;

        final goal = await getKcalGoalUsecase.getKcalGoal();
        expect(goal, closeTo(expected, 0.01));
      });
    }
  });

  group('GetMacroGoalUsecase — dynamic protein-first vs. manual override', () {
    test('no manual override uses MacroDynamicCalc protein-first', () async {
      await userDataSource.saveUserData(baseUser(weightKg: 84.0));

      const kcalGoal = 2200.0;
      final protein = await getMacroGoalUsecase.getProteinsGoal(kcalGoal);

      final expected = MacroDynamicCalc.calculateMacros(
        totalKcalGoal: kcalGoal,
        weightKg: 84.0,
        heightCm: 178,
        proteinGPerKg: 1.8,
        isWeightLossGoal: true,
      );
      expect(protein, closeTo(expected.proteinG, 0.01));
    });

    test('a manual override on any one macro routes all three through the '
        'old fixed-percentage system instead', () async {
      await userDataSource.saveUserData(baseUser(weightKg: 84.0));
      final config = ConfigDBO.empty();
      config.userProteinGoalPct = 0.35;
      await configDataSource.addConfig(config);

      const kcalGoal = 2200.0;
      final protein = await getMacroGoalUsecase.getProteinsGoal(kcalGoal);
      final carbs = await getMacroGoalUsecase.getCarbsGoal(kcalGoal);

      // Protein: the overridden 35% share, not the protein-first g/kg math.
      expect(protein, closeTo((kcalGoal * 0.35) / 4, 0.01));
      // Carbs: no override was set for it, but because *a* manual override
      // exists at all, it still falls back to the default 60% share
      // rather than MacroDynamicCalc's 50/50-of-remainder split.
      expect(carbs, closeTo((kcalGoal * 0.6) / 4, 0.01));
    });
  });
}
