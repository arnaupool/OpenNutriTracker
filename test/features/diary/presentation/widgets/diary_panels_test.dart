import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/activity_vertial_list.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/day_info_widget.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_panel.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_week_summary.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

class _FakeTrackedDayRepository extends Fake implements TrackedDayRepository {
  @override
  Future<List<TrackedDayEntity>> getTrackedDayByRange(DateTime start, DateTime end) async => const [];
}

Widget _wrap(Widget child) => ChangeNotifierProvider<EnergyUnitProvider>(
  create: (_) => EnergyUnitProvider(),
  child: MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

TrackedDayEntity _day(DateTime day, double kcal) => TrackedDayEntity(
  day: day,
  calorieGoal: 2000,
  caloriesTracked: kcal,
  carbsGoal: 250,
  carbsTracked: 100,
  fatGoal: 70,
  fatTracked: 40,
  proteinGoal: 120,
  proteinTracked: 80,
);

void main() {
  group('DayInfoWidget summary container', () {
    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      _wrap(
        DayInfoWidget(
          selectedDay: DateTime(2026, 11, 3),
          trackedDayEntity: _day(DateTime(2026, 11, 3), 0),
          userActivities: const [],
          breakfastIntake: const [],
          lunchIntake: const [],
          dinnerIntake: const [],
          snackIntake: const [],
          usesImperialUnits: false,
          showActivityTracking: false,
          breakfastSharePct: 0,
          lunchSharePct: 0,
          dinnerSharePct: 0,
          snackSharePct: 0,
          onDeleteIntake: (a, b, {bool isMove = false}) {},
          onDeleteActivity: (a, b) {},
          onCopyIntake: (a, b, c, d) {},
          onCopyActivity: (a, b) {},
        ),
      ),
    );

    testWidgets('is a delimited container and the kcal pill is tonal, not red, under the goal', (tester) async {
      await pump(tester);
      expect(find.byType(DiaryPanel), findsOneWidget);
      final context = tester.element(find.byType(DiaryPanel));
      final scheme = Theme.of(context).colorScheme;
      final panel = tester.widget<Container>(
        find.descendant(of: find.byType(DiaryPanel), matching: find.byType(Container)).first,
      );
      expect((panel.decoration! as BoxDecoration).color, scheme.surfaceContainer);
      final pill = tester.widget<Card>(find.byType(Card).first);
      expect(pill.color, scheme.primaryContainer);
      expect(pill.color, isNot(scheme.errorContainer));
    });
  });

  group('DiaryWeekSummary', () {
    testWidgets('shows each macro in its own delimited row', (tester) async {
      final monday = DateTime(2026, 11, 2);
      final usecase = GetTrackedDayUsecase(_FakeTrackedDayRepository());
      await tester.pumpWidget(
        _wrap(
          DiaryWeekSummary(
            selectedDate: monday,
            trackedDaysMap: {'2026-11-02': _day(monday, 1800)},
            getTrackedDayUsecase: usecase,
          ),
        ),
      );
      await tester.tap(find.text(S.current.diaryWeekSummaryTitle));
      await tester.pumpAndSettle();
      // Four totals rows (kcal, fat, protein, carbs) and four chart rows.
      expect(find.byType(DiaryPanelRow), findsNWidgets(8));
      expect(find.textContaining('1800'), findsWidgets);
    });
  });

  group('ActivityVerticalList', () {
    testWidgets('Hide is in the menu only when a hide action is given and calls it', (tester) async {
      var hidden = 0;
      Widget list({VoidCallback? onHide}) => _wrap(
        ActivityVerticalList(
          day: DateTime(2026, 11, 3),
          title: 'Activity',
          userActivityList: const [],
          onItemLongPressedCallback: (a, b) {},
          onHide: onHide,
        ),
      );

      await tester.pumpWidget(list());
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text(S.current.activityHideLabel), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await tester.pumpWidget(list(onHide: () => hidden++));
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.activityHideLabel));
      await tester.pumpAndSettle();
      expect(hidden, 1);
    });
  });
}
