import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/features/diet_plan/data/diet_plan_data_source.dart';
import 'package:opennutritracker/features/diet_plan/data/diet_plan_dbo.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_calc.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_usecase.dart';
import 'package:opennutritracker/features/diet_plan/presentation/diet_plan_home_card.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _FakeWeightLog extends Fake implements WeightLogRepository {
  List<WeightLogEntity> entries = [];

  @override
  Future<List<WeightLogEntity>> getAllEntries() async => List.of(entries);
}

class _FakeUsers extends Fake implements UserRepository {}

void main() {
  late Box<DietPlanDBO> box;
  late _FakeWeightLog weights;
  late DietPlanUsecase usecase;
  var clock = DateTime(2026, 12, 1, 12);
  var boxCounter = 0;

  setUp(() async {
    clock = DateTime(2026, 12, 1, 12);
    weights = _FakeWeightLog();
    box = await Hive.openBox<DietPlanDBO>('diet_card_${boxCounter++}', bytes: Uint8List(0));
    if (!Hive.isAdapterRegistered(DietPlanDBO.hiveTypeId)) Hive.registerAdapter(DietPlanDBOAdapter());
    usecase = DietPlanUsecase(DietPlanDataSource(box), weights, _FakeUsers(), (_) async {});
  });

  DietPlanDBO plan({
    DateTime? start,
    double kg = 10,
    bool show = true,
    DietPlanStatus status = DietPlanStatus.active,
    List<DietPlanPause> pauses = const [],
  }) {
    final s = start ?? DateTime(2026, 10, 27);
    return DietPlanDBO(
      mode: DietPlanMode.auto,
      startDate: s,
      endDate: DietPlanCalc.autoEnd(s, kg, 0.5),
      startWeightKg: 80,
      targetLossKg: kg,
      paceKgPerWeek: 0.5,
      showCountdown: show,
      status: status,
      pauses: pauses,
    );
  }

  WeightLogEntity weigh(int daysAgo, double kg) =>
      WeightLogEntity(date: DateTime(clock.year, clock.month, clock.day - daysAgo, 8), weightKg: kg);

  Future<void> pump(WidgetTester tester, {VoidCallback? onOpen}) async {
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
        home: Scaffold(
          body: SingleChildScrollView(
            child: DietPlanHomeCard(usecase: usecase, now: () => clock, onOpenPlan: onOpen),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await box.close();
  }

  testWidgets('is hidden without a plan', (tester) async {
    await pump(tester);
    expect(find.byType(Card), findsNothing);
    await teardown(tester);
  });

  testWidgets('hidden when the countdown switch is off', (tester) async {
    await usecase.save(plan(show: false));
    await pump(tester);
    expect(find.byType(Card), findsNothing);
    await teardown(tester);
  });

  testWidgets('shows days left, end date, progress and the 7-day-average weight line', (tester) async {
    await usecase.save(plan());
    // Last weigh-in 76, but the 7-day average is 75.5; an older weigh-in is ignored.
    weights.entries = [weigh(0, 76), weigh(2, 75), weigh(10, 90)];
    await pump(tester);
    // 2026-12-01 to 2027-03-16.
    expect(find.text('105 days left'), findsOneWidget);
    expect(find.text('End: 16/03/2027'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('-4.5 kg of 10 kg'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('tapping the card opens the plan', (tester) async {
    await usecase.save(plan());
    var opened = 0;
    await pump(tester, onOpen: () => opened++);
    await tester.tap(find.text('105 days left'));
    expect(opened, 1);
    await teardown(tester);
  });

  testWidgets('paused plan shows Paused and no countdown', (tester) async {
    await usecase.save(DietPlanCalc.pause(plan(), DateTime(2026, 11, 20)));
    await pump(tester);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.textContaining('days left'), findsNothing);
    await teardown(tester);
  });

  testWidgets('finished plan offers extend, new plan and maintenance', (tester) async {
    await usecase.save(plan(start: DateTime(2026, 1, 1), kg: 5)); // ended 2026-03-11
    await pump(tester);
    expect(find.text('Plan finished'), findsOneWidget);
    expect(find.text('Extend'), findsOneWidget);
    expect(find.text('New plan'), findsOneWidget);
    expect(find.text('Switch to maintenance'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await teardown(tester);
  });

  testWidgets('goal reached early offers the same three options', (tester) async {
    await usecase.save(plan());
    weights.entries = [weigh(0, 69.8), weigh(3, 70.2)];
    await pump(tester);
    expect(find.text('Goal reached'), findsOneWidget);
    expect(find.text('Extend'), findsOneWidget);
    expect(find.text('New plan'), findsOneWidget);
    expect(find.text('Switch to maintenance'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('stalled for 21 days shows a suggestion and never changes the plan', (tester) async {
    final stored = plan();
    await usecase.save(stored);
    weights.entries = [weigh(0, 79), weigh(21, 79)];
    await pump(tester);
    expect(find.text('Progress has stalled'), findsOneWidget);
    expect(find.text('Adjust plan'), findsOneWidget);
    expect(usecase.plan!.toJson(), stored.toJson());
    await teardown(tester);
  });

  testWidgets('no stalled card while the average is still going down', (tester) async {
    await usecase.save(plan());
    weights.entries = [weigh(0, 77), weigh(21, 79)];
    await pump(tester);
    expect(find.text('Progress has stalled'), findsNothing);
    await teardown(tester);
  });

  testWidgets('the countdown drops by one at local midnight', (tester) async {
    clock = DateTime(2026, 12, 1, 23, 59, 30);
    await usecase.save(plan());
    await pump(tester);
    expect(find.text('105 days left'), findsOneWidget);
    clock = DateTime(2026, 12, 2, 0, 0, 5);
    await tester.pump(const Duration(seconds: 36));
    await tester.pump();
    expect(find.text('104 days left'), findsOneWidget);
    await teardown(tester);
  });
}
