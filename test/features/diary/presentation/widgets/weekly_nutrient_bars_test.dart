import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/weekly_nutrient_bars.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _FakeTrackedDayRepository extends Fake implements TrackedDayRepository {
  final List<TrackedDayEntity> _entries;
  _FakeTrackedDayRepository(this._entries);

  @override
  Future<List<TrackedDayEntity>> getTrackedDayByRange(
    DateTime start,
    DateTime end,
  ) async => _entries
      .where((t) => !t.day.isBefore(start) && !t.day.isAfter(end))
      .toList();
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
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('WeeklyNutrientBars', () {
    testWidgets('renders one bar chart per nutrient with the selected day '
        'highlighted and a dashed goal line', (tester) async {
      final monday = DateTime(2026, 1, 5); // a Monday
      final tuesday = monday.add(const Duration(days: 1));

      final trackedDays = [
        TrackedDayEntity(
          day: monday,
          calorieGoal: 2400,
          caloriesTracked: 2000,
          fatGoal: 70,
          fatTracked: 60,
          proteinGoal: 150,
          proteinTracked: 120,
          carbsGoal: 300,
          carbsTracked: 250,
        ),
        TrackedDayEntity(
          day: tuesday,
          calorieGoal: 2400,
          caloriesTracked: 2300,
          fatGoal: 70,
          fatTracked: 65,
          proteinGoal: 150,
          proteinTracked: 140,
          carbsGoal: 300,
          carbsTracked: 280,
        ),
      ];

      final getTrackedDayUsecase = GetTrackedDayUsecase(
        _FakeTrackedDayRepository(trackedDays),
      );

      await tester.pumpWidget(
        _wrap(
          WeeklyNutrientBars(
            selectedDate: tuesday,
            getTrackedDayUsecase: getTrackedDayUsecase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(S.current.diaryWeeklyBarsTitle), findsOneWidget);
      expect(find.byType(BarChart), findsNWidgets(4));
      // Each mini chart's header shows the selected day's "consumed / goal"
      // for the header, title-cased even though the shared label strings
      // are lowercase.
      expect(find.text('Calories (2300 / 2400 kcal)'), findsOneWidget);
      expect(find.text('Fat (65 / 70 g)'), findsOneWidget);
      expect(find.text('Protein (140 / 150 g)'), findsOneWidget);
      expect(find.text('Carbs (280 / 300 g)'), findsOneWidget);
    });

    testWidgets('reloads when the selected date moves to a different week', (
      tester,
    ) async {
      final week1Monday = DateTime(2026, 1, 5);
      final week2Monday = DateTime(2026, 1, 12);

      final getTrackedDayUsecase = GetTrackedDayUsecase(
        _FakeTrackedDayRepository([
          TrackedDayEntity(
            day: week1Monday,
            calorieGoal: 2400,
            caloriesTracked: 2000,
          ),
          TrackedDayEntity(
            day: week2Monday,
            calorieGoal: 2400,
            caloriesTracked: 1800,
          ),
        ]),
      );

      await tester.pumpWidget(
        _wrap(
          WeeklyNutrientBars(
            selectedDate: week1Monday,
            getTrackedDayUsecase: getTrackedDayUsecase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _wrap(
          WeeklyNutrientBars(
            selectedDate: week2Monday,
            getTrackedDayUsecase: getTrackedDayUsecase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BarChart), findsNWidgets(4));
    });
  });
}
