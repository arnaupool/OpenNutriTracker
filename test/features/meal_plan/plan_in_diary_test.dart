import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/sync/sync_crypto.dart';
import 'package:opennutritracker/core/sync/sync_engine.dart';
import 'package:opennutritracker/core/sync/sync_state_store.dart';
import 'package:opennutritracker/core/sync/synced_box.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_data_source.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_entry_dbo.dart';
import 'package:opennutritracker/features/meal_plan/domain/log_meal_plan_usecase.dart';
import 'package:opennutritracker/features/meal_plan/domain/meal_plan_calc.dart';
import 'package:opennutritracker/features/meal_plan/presentation/planned_intake_card.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

import '../../helpers/fake_sync_server.dart';
import '../../helpers/hive_test_setup.dart';

class _FakeAddIntake extends Fake implements AddIntakeUsecase {
  final List<IntakeEntity> intakes = [];

  @override
  Future<void> addIntake(IntakeEntity intakeEntity) async {
    // Awaiting makes concurrent confirmations interleave, like two taps.
    await Future<void>.delayed(Duration.zero);
    intakes.add(intakeEntity);
  }
}

class _FakeTrackedDays extends Fake implements AddTrackedDayUsecase {
  double kcalTracked = 0;
  final Set<DateTime> days = {};

  @override
  Future<bool> hasTrackedDay(DateTime day) async => days.contains(day);

  @override
  Future<void> addNewTrackedDay(DateTime day, double kcal, double carbs, double fat, double protein) async {
    days.add(day);
  }

  @override
  Future<void> addDayCaloriesTracked(DateTime day, double caloriesTracked) async {
    kcalTracked += caloriesTracked;
  }

  @override
  Future<void> addDayMacrosTracked(
    DateTime day, {
    double? carbsTracked,
    double? fatTracked,
    double? proteinTracked,
  }) async {}
}

class _FakeKcalGoal extends Fake implements GetKcalGoalUsecase {
  @override
  Future<double> getKcalGoal({double? kcalUserAdjustment, dynamic userEntity}) async => 2000;
}

class _FakeMacroGoal extends Fake implements GetMacroGoalUsecase {
  @override
  Future<double> getCarbsGoal(double totalCalorieGoal) async => 250;

  @override
  Future<double> getFatsGoal(double totalCalorieGoal) async => 70;

  @override
  Future<double> getProteinsGoal(double totalCalorieGoal) async => 150;
}

MealDBO _meal(String name, {double kcal100 = 100}) => MealDBO(
  code: name,
  name: name,
  brands: null,
  thumbnailImageUrl: null,
  mainImageUrl: null,
  url: null,
  mealQuantity: '100',
  mealUnit: 'g',
  servingQuantity: null,
  servingUnit: null,
  servingSize: null,
  source: MealSourceDBO.custom,
  nutriments: MealNutrimentsDBO(
    energyKcal100: kcal100,
    carbohydrates100: 10,
    fat100: 2,
    proteins100: 10,
    sugars100: null,
    saturatedFat100: null,
    fiber100: null,
  ),
);

final _day = DateTime(2031, 3, 14); // a future day on purpose

MealPlanEntryDBO _entry(String id, {double grams = 200, IntakeTypeDBO type = IntakeTypeDBO.lunch, String? name}) =>
    MealPlanEntryDBO(id: id, day: _day, type: type, meal: _meal(name ?? 'Rice'), amount: grams, unit: 'g');

class _Rig {
  final Box<MealPlanEntryDBO> box;
  final _FakeAddIntake intakes = _FakeAddIntake();
  final _FakeTrackedDays tracked = _FakeTrackedDays();
  late final MealPlanDataSource plan = MealPlanDataSource(box);
  late final LogMealPlanUsecase usecase = LogMealPlanUsecase(plan, intakes, tracked, _FakeKcalGoal(), _FakeMacroGoal());

  _Rig(this.box);
}

void main() {
  late Directory dir;
  var boxCount = 0;

  setUpAll(() {
    registerHiveAdaptersOnce();
    if (!Hive.isAdapterRegistered(MealPlanEntryDBO.hiveTypeId)) {
      Hive.registerAdapter(MealPlanEntryDBOAdapter());
    }
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('plan_diary');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<_Rig> rig() async => _Rig(await Hive.openBox<MealPlanEntryDBO>('plan${boxCount++}', bytes: Uint8List(0)));

  group('planned entries in the Diary', () {
    test('a pending entry is shown for its day (even a future one) but counts nowhere', () async {
      final r = await rig();
      await r.plan.save(_entry('a'));

      expect(r.usecase.pendingFor(_day).map((e) => e.id), ['a']);
      expect(r.usecase.pendingFor(DateTime(2031, 3, 15)), isEmpty);
      expect(r.intakes.intakes, isEmpty);
      expect(r.tracked.kcalTracked, 0);
    });

    test('confirm logs exactly one normal intake with the planned quantity', () async {
      final r = await rig();
      await r.plan.save(_entry('a', grams: 250, type: IntakeTypeDBO.dinner));

      expect(await r.usecase.confirm('a'), isTrue);

      expect(r.intakes.intakes, hasLength(1));
      final intake = r.intakes.intakes.single;
      expect(intake.amount, 250);
      expect(intake.unit, 'g');
      expect(intake.type, IntakeTypeEntity.dinner);
      expect(DateUtils.isSameDay(intake.dateTime, _day), isTrue);
      expect(r.tracked.kcalTracked, closeTo(250, 0.001)); // 100 kcal / 100 g * 250 g
      expect(r.plan.get('a')!.loggedAt, isNotNull);
      expect(r.usecase.pendingFor(_day), isEmpty);
    });

    test('confirming twice, even at the same time, logs a single intake', () async {
      final r = await rig();
      await r.plan.save(_entry('a'));

      final results = await Future.wait([r.usecase.confirm('a'), r.usecase.confirm('a')]);
      expect(results.where((logged) => logged), hasLength(1));
      expect(await r.usecase.confirm('a'), isFalse);

      expect(r.intakes.intakes, hasLength(1));
      expect(r.tracked.kcalTracked, closeTo(200, 0.001));
    });

    test('discard hides the entry for its day without logging anything', () async {
      final r = await rig();
      await r.plan.save(_entry('a'));
      await r.plan.save(_entry('b'));

      await r.usecase.discard('a');

      expect(r.usecase.pendingFor(_day).map((e) => e.id), ['b']);
      expect(r.plan.get('a')!.discardedAt, isNotNull);
      expect(r.plan.get('a')!.loggedAt, isNull);
      expect(await r.usecase.confirm('a'), isFalse);
      expect(r.intakes.intakes, isEmpty);
      // "Log plan" of the day skips it too.
      expect(await r.usecase.logDay(_day), 1);
      expect(r.intakes.intakes, hasLength(1));
    });

    test('a plan edited before confirming is what gets logged', () async {
      final r = await rig();
      await r.plan.save(_entry('a', grams: 100));
      expect(r.usecase.pendingFor(_day).single.amount, 100);

      await r.plan.save(r.plan.get('a')!.copyWith(amount: 300));
      expect(r.usecase.pendingFor(_day).single.amount, 300);
      await r.usecase.confirm('a');

      expect(r.intakes.intakes.single.amount, 300);
    });

    test('deleting a plan entry removes its pending item but never a confirmed intake', () async {
      final r = await rig();
      await r.plan.save(_entry('pending'));
      await r.plan.save(_entry('done'));
      await r.usecase.confirm('done');

      await r.plan.delete('pending');
      await r.plan.delete('done');

      expect(r.usecase.pendingFor(_day), isEmpty);
      expect(r.intakes.intakes, hasLength(1));
      expect(r.tracked.kcalTracked, closeTo(200, 0.001));
    });

    test('the confirmation state survives closing and reopening the box', () async {
      var box = await Hive.openBox<MealPlanEntryDBO>('persist');
      final r = _Rig(box);
      await r.plan.save(_entry('a'));
      await r.plan.save(_entry('b'));
      await r.usecase.confirm('a');
      await r.usecase.discard('b');
      await box.close();

      box = await Hive.openBox<MealPlanEntryDBO>('persist');
      final reopened = MealPlanDataSource(box);
      expect(reopened.get('a')!.loggedAt, isNotNull);
      expect(reopened.get('b')!.discardedAt, isNotNull);
      expect(reopened.get('a')!.isPending, isFalse);
      expect(reopened.get('b')!.isPending, isFalse);
    });

    test('the JSON used by sync and backups carries the state', () {
      final entry = _entry('a').copyWith(loggedAt: DateTime.utc(2026, 11, 4), discardedAt: DateTime.utc(2026, 11, 5));
      Map<String, dynamic> viaJson(MealPlanEntryDBO e) => jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>;
      final back = MealPlanEntryDBO.fromJson(viaJson(entry));
      expect(back.loggedAt, DateTime.utc(2026, 11, 4));
      expect(back.discardedAt, DateTime.utc(2026, 11, 5));
      // Entries written before the field existed read as undiscarded.
      final old = viaJson(entry)..remove('discardedAt');
      expect(MealPlanEntryDBO.fromJson(old).discardedAt, isNull);
    });
  });

  group('sync of the confirmation state between two devices', () {
    late FakeSyncServer server;
    late Uint8List key;

    setUp(() {
      server = FakeSyncServer();
      key = SyncCrypto.generateKey();
    });

    Future<({_Rig rig, SyncEngine engine, SyncTarget target})> device() async {
      final r = await rig();
      final stateBox = await Hive.openBox<dynamic>('state${boxCount++}', bytes: Uint8List(0));
      final engine = SyncEngine(
        boxes: [
          SyncedBox<MealPlanEntryDBO>(
            name: 'MealPlanBox',
            box: r.box,
            identityOf: (_, key) => key?.toString(),
            toJson: (v) => v.toJson(),
            fromJson: MealPlanEntryDBO.fromJson,
            naturalKey: true,
          ),
        ],
      );
      final target = SyncTarget(remote: server.remote('u1'), state: SyncStateStore.account(stateBox, 'u1'), key: key);
      return (rig: r, engine: engine, target: target);
    }

    DateTime at(int minute) => DateTime.utc(2026, 11, 4, 12, minute);

    test('a confirmation and a discard on one device reach the other', () async {
      final phone = await device();
      final desktop = await device();
      await phone.rig.plan.save(_entry('a'));
      await phone.rig.plan.save(_entry('b'));
      await phone.rig.plan.save(_entry('c'));
      await phone.engine.sync(phone.target, now: at(0));
      await desktop.engine.sync(desktop.target, now: at(1));
      expect(desktop.rig.usecase.pendingFor(_day).map((e) => e.id), unorderedEquals(['a', 'b', 'c']));

      await phone.rig.usecase.confirm('a', now: at(2));
      await phone.rig.usecase.discard('b', now: at(2));
      await phone.engine.sync(phone.target, now: at(3));
      await desktop.engine.sync(desktop.target, now: at(4));

      expect(desktop.rig.usecase.pendingFor(_day).map((e) => e.id), ['c']);
      expect(desktop.rig.plan.get('a')!.loggedAt, isNotNull);
      expect(desktop.rig.plan.get('b')!.discardedAt, isNotNull);
      // The desktop did not log the entry again: its own diary is untouched.
      expect(desktop.rig.intakes.intakes, isEmpty);
    });

    test('a plan entry deleted on one device disappears from the other', () async {
      final phone = await device();
      final desktop = await device();
      await phone.rig.plan.save(_entry('a'));
      await phone.engine.sync(phone.target, now: at(0));
      await desktop.engine.sync(desktop.target, now: at(1));

      await phone.rig.plan.delete('a');
      await phone.engine.sync(phone.target, now: at(2));
      await desktop.engine.sync(desktop.target, now: at(3));

      expect(desktop.rig.usecase.pendingFor(_day), isEmpty);
    });
  });

  group('PlannedEntriesBuilder', () {
    Widget wrap(_Rig r, {IntakeTypeEntity type = IntakeTypeEntity.lunch}) => ChangeNotifierProvider<EnergyUnitProvider>(
      create: (_) => EnergyUnitProvider(),
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: PlannedEntriesBuilder(
            day: _day,
            type: type,
            usecase: r.usecase,
            builder: (context, cards) => Row(children: cards),
          ),
        ),
      ),
    );

    testWidgets('shows a labelled planned card in its meal and nothing for other meals', (tester) async {
      final r = await rig();
      await r.plan.save(_entry('a', name: 'Arroz'));
      await tester.pumpWidget(wrap(r));

      expect(find.text('PLANIFICADO'), findsOneWidget);
      expect(find.text('Arroz'), findsOneWidget);
      expect(find.text('Confirmar'), findsOneWidget);

      await tester.pumpWidget(wrap(r, type: IntakeTypeEntity.dinner));
      expect(find.text('PLANIFICADO'), findsNothing);
    });

    testWidgets('one tap on Confirmar logs it once, even if tapped twice', (tester) async {
      final r = await rig();
      await r.plan.save(_entry('a', name: 'Arroz'));
      await tester.pumpWidget(wrap(r));

      await tester.tap(find.text('Confirmar'));
      await tester.tap(find.text('Confirmar'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(r.intakes.intakes, hasLength(1));
      expect(find.text('PLANIFICADO'), findsNothing);
    });

    testWidgets('Descartar hides the card and logs nothing', (tester) async {
      final r = await rig();
      await r.plan.save(_entry('a', name: 'Arroz'));
      await tester.pumpWidget(wrap(r));

      await tester.tap(find.byTooltip('Descartar'));
      await tester.pumpAndSettle();

      expect(find.text('PLANIFICADO'), findsNothing);
      expect(r.intakes.intakes, isEmpty);
    });

    testWidgets('the card follows plan edits and deletions while it is on screen', (tester) async {
      final r = await rig();
      await r.plan.save(_entry('a', name: 'Arroz', grams: 100));
      await tester.pumpWidget(wrap(r));
      expect(find.textContaining('100 g'), findsOneWidget);

      await tester.runAsync(() => r.plan.save(r.plan.get('a')!.copyWith(amount: 300)));
      await tester.pump();
      expect(find.textContaining('300 g'), findsOneWidget);

      await tester.runAsync(() => r.plan.delete('a'));
      await tester.pump();
      expect(find.text('PLANIFICADO'), findsNothing);
    });
  });

  group('a plan day counts what is already in the diary', () {
    IntakeEntity intake(String id, double grams) => IntakeEntity(
      id: id,
      unit: 'g',
      amount: grams,
      type: IntakeTypeEntity.lunch,
      meal: MealEntity.fromMealDBO(_meal('Bread', kcal100: 250)),
      dateTime: DateTime(2031, 3, 14, 13),
    );

    test('diary intakes plus pending entries; confirmed counts once, discarded never', () {
      final pending = _entry('a', grams: 200); // 200 kcal
      final confirmed = _entry('b', grams: 100).copyWith(loggedAt: DateTime(2031, 3, 14, 12)); // 100 kcal
      final discarded = _entry('c', grams: 300).copyWith(discardedAt: DateTime(2031, 3, 14, 12));
      final diary = [
        intake('own', 100), // 250 kcal logged straight in the diary
        intake('plan-b', 100), // the intake confirming entry b (100 g at 250 kcal/100 g here)
      ];
      final totals = MealPlanCalc.dayTotals([pending, confirmed, discarded], diary);
      expect(totals.kcal, closeTo(200 + 250 + 250, 0.001));
    });

    test('only intakes not created from the plan are listed separately', () {
      final listed = MealPlanCalc.diaryOnly([intake('own', 50), intake('plan-b', 100)]);
      expect(listed.map((i) => i.id), ['own']);
    });
  });
}
