import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/features/home/presentation/widgets/food_logging_habit_card.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:table_calendar/table_calendar.dart';

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

// TableCalendar<T> is generic and instantiated without an explicit type
// argument, so find.byType(TableCalendar) (which resolves the bare type to
// TableCalendar<dynamic>) never matches the actual TableCalendar<Object?>
// in the tree. `is TableCalendar` checks against the raw class instead.
Finder get _findTableCalendar =>
    find.byWidgetPredicate((widget) => widget is TableCalendar);

// Matches CompactHabitCalendar's own marker dot (a 5x5 circular Container),
// so tests can assert on how many days actually rendered as "marked"
// without reaching into the widget's private state.
Finder get _findMarkerDots => find.byWidgetPredicate(
  (widget) =>
      widget is Container &&
      widget.constraints ==
          const BoxConstraints.tightFor(width: 5.0, height: 5.0),
);

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

void main() {
  group('FoodLoggingHabitCard', () {
    testWidgets('shows the card title and a compact calendar with no '
        'tracked days', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FoodLoggingHabitCard(
            getTrackedDayUsecase: _FakeGetTrackedDayUsecase([]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(S.current.homeLoggingHabitCardTitle), findsOneWidget);
      expect(_findTableCalendar, findsOneWidget);
      expect(_findMarkerDots, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'excludes activity-only days (caloriesTracked == 0) from the '
      'logging streak',
      (tester) async {
        final now = DateTime.now();
        // Two distinct, always-in-month days, independent of what "today"
        // happens to be on the machine running the test.
        final activityOnlyDay = DateTime(now.year, now.month, 1);
        final realFoodDay = DateTime(now.year, now.month, 2);

        await tester.pumpWidget(
          _wrap(
            FoodLoggingHabitCard(
              getTrackedDayUsecase: _FakeGetTrackedDayUsecase([
                TrackedDayEntity(
                  day: activityOnlyDay,
                  calorieGoal: 2400,
                  caloriesTracked: 0,
                ),
                TrackedDayEntity(
                  day: realFoodDay,
                  calorieGoal: 2400,
                  caloriesTracked: 2100,
                ),
              ]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(_findTableCalendar, findsOneWidget);
        expect(_findMarkerDots, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
