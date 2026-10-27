import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/features/diet_plan/data/diet_plan_data_source.dart';
import 'package:opennutritracker/features/diet_plan/data/diet_plan_dbo.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_calc.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_usecase.dart';
import 'package:opennutritracker/features/diet_plan/presentation/my_plan_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _FakeWeightLog extends Fake implements WeightLogRepository {
  @override
  Future<List<WeightLogEntity>> getAllEntries() async => [];
}

class _FakeUsers extends Fake implements UserRepository {
  final UserEntity user = UserEntity(
    birthday: DateTime(1990, 1, 1),
    heightCM: 180,
    weightKG: 80,
    gender: UserGenderEntity.male,
    goal: UserWeightGoalEntity.maintainWeight,
    pal: UserPALEntity.lowActive,
  );

  @override
  Future<UserEntity> getUserData() async => user;
}

void main() {
  late Box<DietPlanDBO> box;
  late DietPlanUsecase usecase;
  late _FakeUsers users;
  final saved = <UserEntity>[];
  var counter = 0;

  setUp(() async {
    saved.clear();
    users = _FakeUsers();
    if (!Hive.isAdapterRegistered(DietPlanDBO.hiveTypeId)) Hive.registerAdapter(DietPlanDBOAdapter());
    box = await Hive.openBox<DietPlanDBO>('my_plan_${counter++}', bytes: Uint8List(0));
    usecase = DietPlanUsecase(DietPlanDataSource(box), _FakeWeightLog(), users, (u) async => saved.add(u));
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        locale: const Locale('en'),
        home: MyPlanScreen(usecase: usecase),
      ),
    );
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await box.close();
  }

  DietPlanDBO stored() {
    final today = DietPlanCalc.dateOnly(DateTime.now());
    return DietPlanUsecase.newAutoPlan(start: today, startWeightKg: 80, kgToLose: 10, paceKgPerWeek: 0.5);
  }

  testWidgets('without a plan it offers to create one, which sets the engine up', (tester) async {
    await pump(tester);
    expect(find.text('Create plan'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Create plan'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(usecase.plan, isNotNull);
    expect(usecase.plan!.mode, DietPlanMode.auto);
    expect(saved.single.goal, UserWeightGoalEntity.loseWeight);
    expect(saved.single.targetWeightKg, isNotNull);
    expect(find.text('Save'), findsOneWidget);
    await close(tester);
  });

  testWidgets('changing the pace recalculates the end date live and Save stores it', (tester) async {
    await usecase.save(stored());
    await pump(tester);
    final today = DietPlanCalc.dateOnly(DateTime.now());
    String summary(int days) {
      final end = DietPlanCalc.addDays(today, days);
      final d = '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}';
      return 'Ends on $d ($days days left)';
    }

    expect(find.text(summary(140)), findsOneWidget);
    await tester.tap(find.text('0.75 kg/week'));
    await tester.pump();
    expect(find.text(summary(94)), findsOneWidget); // 10 / 0.75 * 7 = 93.3 -> 94
    expect(usecase.plan!.paceKgPerWeek, 0.5, reason: 'nothing is stored before Save');

    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(usecase.plan!.paceKgPerWeek, 0.75);
    expect(usecase.plan!.endDate, DietPlanCalc.addDays(today, 94));
    expect(saved.single.weeklyRatePct, closeTo(0.75 / 80 * 100, 1e-9));
    expect(saved.single.targetWeightKg, 70);
    await close(tester);
  });

  testWidgets('pause and resume toggle the plan and the switch hides the countdown', (tester) async {
    await usecase.save(stored());
    await pump(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Pause plan'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(DietPlanCalc.isPaused(usecase.plan!), isTrue);
    expect(find.text('Resume plan'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Resume plan'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(DietPlanCalc.isPaused(usecase.plan!), isFalse);

    await tester.runAsync(() async {
      await tester.tap(find.byType(SwitchListTile));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(usecase.plan!.showCountdown, isFalse);
    await close(tester);
  });

  testWidgets('manual mode takes a duration in weeks', (tester) async {
    await usecase.save(stored());
    await pump(tester);
    await tester.tap(find.text('Manual'));
    await tester.pump();
    await tester.tap(find.text('By weeks'));
    await tester.pump();
    final today = DietPlanCalc.dateOnly(DateTime.now());
    // 20 weeks carried over from the automatic plan.
    expect(find.text('20 weeks'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_circle_outline).last);
    await tester.pump();
    expect(find.text('21 weeks'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(usecase.plan!.mode, DietPlanMode.manual);
    expect(usecase.plan!.endDate, DietPlanCalc.addDays(today, 21 * 7));
    expect(saved, isEmpty, reason: 'a manual plan does not touch the engine');
    await close(tester);
  });
}
