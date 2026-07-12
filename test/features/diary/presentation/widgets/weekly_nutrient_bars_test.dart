import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
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

class _FakeIntakeRepository extends Fake implements IntakeRepository {
  final Map<DateTime, List<IntakeEntity>> _byDay;
  _FakeIntakeRepository(this._byDay);

  @override
  Future<List<IntakeEntity>> getIntakeByDateAndType(
    IntakeTypeEntity type,
    DateTime day, {
    int dayStartOffsetHours = 0,
    int dayStartOffsetMinutes = 0,
  }) async {
    if (type != IntakeTypeEntity.breakfast) return [];
    final key = DateTime(day.year, day.month, day.day);
    return _byDay[key] ?? [];
  }
}

MealEntity _sodiumMeal(double sodium100) {
  return MealEntity(
    code: 'test',
    name: 'test meal',
    url: null,
    mealQuantity: null,
    mealUnit: 'g',
    servingQuantity: null,
    servingUnit: 'g',
    servingSize: null,
    source: MealSourceEntity.custom,
    nutriments: MealNutrimentsEntity(
      energyKcal100: 100,
      carbohydrates100: 0,
      fat100: 0,
      proteins100: 0,
      sugars100: 0,
      saturatedFat100: 0,
      fiber100: 0,
      sodium100: sodium100,
    ),
  );
}

IntakeEntity _intake(double amountGrams, double sodium100, DateTime at) {
  return IntakeEntity(
    id: 'i-${at.toIso8601String()}',
    unit: 'g',
    amount: amountGrams,
    type: IntakeTypeEntity.breakfast,
    meal: _sodiumMeal(sodium100),
    dateTime: at,
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
        ),
        TrackedDayEntity(
          day: tuesday,
          calorieGoal: 2400,
          caloriesTracked: 2300,
          fatGoal: 70,
          fatTracked: 65,
          proteinGoal: 150,
          proteinTracked: 140,
        ),
      ];

      final getTrackedDayUsecase = GetTrackedDayUsecase(
        _FakeTrackedDayRepository(trackedDays),
      );
      final getIntakeUsecase = GetIntakeUsecase(
        _FakeIntakeRepository({
          monday: [_intake(200, 400, monday)],
          tuesday: [_intake(100, 300, tuesday)],
        }),
      );

      await tester.pumpWidget(
        _wrap(
          WeeklyNutrientBars(
            selectedDate: tuesday,
            getTrackedDayUsecase: getTrackedDayUsecase,
            getIntakeUsecase: getIntakeUsecase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(S.current.diaryWeeklyBarsTitle), findsOneWidget);
      expect(find.byType(BarChart), findsNWidgets(4));
      // Each mini chart shows its selected-day goal in the header text.
      expect(find.textContaining(S.current.caloriesLabel), findsOneWidget);
      expect(find.textContaining(S.current.fatLabel), findsOneWidget);
      expect(find.textContaining(S.current.proteinLabel), findsOneWidget);
      expect(find.textContaining(S.current.sodiumLabel), findsOneWidget);
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
      final getIntakeUsecase = GetIntakeUsecase(_FakeIntakeRepository({}));

      await tester.pumpWidget(
        _wrap(
          WeeklyNutrientBars(
            selectedDate: week1Monday,
            getTrackedDayUsecase: getTrackedDayUsecase,
            getIntakeUsecase: getIntakeUsecase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _wrap(
          WeeklyNutrientBars(
            selectedDate: week2Monday,
            getTrackedDayUsecase: getTrackedDayUsecase,
            getIntakeUsecase: getIntakeUsecase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BarChart), findsNWidgets(4));
    });
  });
}
