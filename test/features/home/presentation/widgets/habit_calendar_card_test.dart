import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/features/home/presentation/widgets/compact_habit_calendar.dart';
import 'package:opennutritracker/features/home/presentation/widgets/habit_calendar_card.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:table_calendar/table_calendar.dart';

class _FakeGetTrackedDayUsecase extends Fake implements GetTrackedDayUsecase {
  final List<TrackedDayEntity> _days;
  _FakeGetTrackedDayUsecase(this._days);

  @override
  Future<List<TrackedDayEntity>> getTrackedDaysByRange(DateTime start, DateTime end) async {
    return _days.where((d) => !d.day.isBefore(start) && !d.day.isAfter(end)).toList();
  }
}

class _FakeGetWeightLogUsecase extends Fake implements GetWeightLogUsecase {
  final List<WeightLogEntity> _entries;
  _FakeGetWeightLogUsecase(this._entries);

  @override
  Future<List<WeightLogEntity>> getEntriesInRange(DateTime from, DateTime to) async {
    return _entries.where((e) => !e.date.isBefore(from) && !e.date.isAfter(to)).toList();
  }
}

// TableCalendar<T> is generic, so find.byType(TableCalendar) never matches the
// TableCalendar<Object?> in the tree; `is TableCalendar` checks the raw class.
Finder get _findTableCalendar => find.byWidgetPredicate((widget) => widget is TableCalendar);

// The marks the calendar draws: a filled dot for logging, a ring for weigh-ins
// (only those inside the calendar; the legend carries its own).
Finder _marks({required bool ring}) => find.byWidgetPredicate((widget) => widget is HabitMarker && widget.ring == ring);

Finder get _calendarDots => find.descendant(of: _findTableCalendar, matching: _marks(ring: false));
Finder get _calendarRings => find.descendant(of: _findTableCalendar, matching: _marks(ring: true));

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('es'),
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

Widget _card({List<TrackedDayEntity> tracked = const [], List<WeightLogEntity> weights = const []}) {
  return HabitCalendarCard(
    getTrackedDayUsecase: _FakeGetTrackedDayUsecase(tracked),
    getWeightLogUsecase: _FakeGetWeightLogUsecase(weights),
  );
}

TrackedDayEntity _tracked(DateTime day, double kcal) =>
    TrackedDayEntity(day: day, calorieGoal: 2400, caloriesTracked: kcal);

void main() {
  group('HabitCalendarCard', () {
    testWidgets('one card, one calendar, a legend and zero counts when nothing is logged', (tester) async {
      await tester.pumpWidget(_wrap(_card()));
      await tester.pumpAndSettle();

      expect(find.text(S.current.homeHabitsCardTitle), findsOneWidget);
      expect(_findTableCalendar, findsOneWidget);
      expect(_calendarDots, findsNothing);
      expect(_calendarRings, findsNothing);
      expect(find.text('${S.current.homeHabitWeighInLabel} ${S.current.homeHabitDaysCount(0)}'), findsOneWidget);
      expect(find.text('${S.current.homeHabitLoggingLabel} ${S.current.homeHabitDaysCount(0)}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a day with both habits carries a dot and a ring; counts are per habit', (tester) async {
      final now = DateTime.now();
      final both = DateTime(now.year, now.month, 1);
      final foodOnly = DateTime(now.year, now.month, 2);
      final activityOnly = DateTime(now.year, now.month, 3);
      await tester.pumpWidget(
        _wrap(
          _card(
            tracked: [_tracked(both, 2000), _tracked(foodOnly, 1800), _tracked(activityOnly, 0)],
            weights: [WeightLogEntity(date: both, weightKg: 84)],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_calendarDots, findsNWidgets(2));
      expect(_calendarRings, findsOneWidget);
      // Singular for one day, plural for several; activity-only days do not count.
      expect(find.text('Pesaje 1 día'), findsOneWidget);
      expect(find.text('Registro 2 días'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('future days with logged food still count (logging ahead)', (tester) async {
      final now = DateTime.now();
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      await tester.pumpWidget(
        _wrap(
          _card(tracked: [for (var d = 1; d <= 4; d++) _tracked(DateTime(nextMonth.year, nextMonth.month, d), 2000)]),
        ),
      );
      await tester.pumpAndSettle();
      expect(_calendarDots, findsNothing);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(_calendarDots, findsNWidgets(4));
      expect(find.text('Registro 4 días'), findsOneWidget);
      expect(find.text('Pesaje 0 días'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
