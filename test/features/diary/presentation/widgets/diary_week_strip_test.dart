import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_week_strip.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_week_summary.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _EmptyTrackedDayRepository extends Fake implements TrackedDayRepository {
  @override
  Future<List<TrackedDayEntity>> getTrackedDayByRange(DateTime start, DateTime end) async => [];
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
  // Wednesday; its week runs Monday 2026-01-05 to Sunday 2026-01-11.
  final selected = DateTime(2026, 1, 7);
  final today = DateTime(2026, 1, 9);

  group('DiaryWeekStrip', () {
    late DateTime? lastSelected;

    Widget strip(DateTime sel) => _wrap(
      DiaryWeekStrip(
        selectedDate: sel,
        currentDate: today,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        trackedDaysMap: const {},
        onDateSelected: (d, _) => lastSelected = d,
      ),
    );

    setUp(() => lastSelected = null);

    testWidgets('shows seven days of the selected week with the selected one highlighted', (tester) async {
      await tester.pumpWidget(strip(selected));
      await tester.pumpAndSettle();

      for (final n in ['5', '6', '7', '8', '9', '10', '11']) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('diary-week-day-2026-01-07-selected')), findsOneWidget);
      expect(find.byKey(const ValueKey('diary-week-day-2026-01-06')), findsOneWidget);
      expect(find.textContaining('January'), findsOneWidget);
    });

    testWidgets('previous and next week buttons move the selection by seven days', (tester) async {
      await tester.pumpWidget(strip(selected));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_left));
      expect(lastSelected, DateTime(2025, 12, 31));

      await tester.tap(find.byIcon(Icons.chevron_right));
      expect(lastSelected, DateTime(2026, 1, 14));
    });

    testWidgets('re-pumping with the next week selected shows that week', (tester) async {
      await tester.pumpWidget(strip(DateTime(2026, 1, 14)));
      await tester.pumpAndSettle();

      expect(find.text('12'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('5'), findsNothing);
    });

    testWidgets('tapping a day fires the selection with that day', (tester) async {
      await tester.pumpWidget(strip(selected));
      await tester.pumpAndSettle();

      await tester.tap(find.text('10'));
      expect(lastSelected, DateTime(2026, 1, 10));
    });

    testWidgets('swiping left goes to the next week', (tester) async {
      await tester.pumpWidget(strip(selected));
      await tester.pumpAndSettle();

      await tester.fling(find.byType(DiaryWeekStrip), const Offset(-300, 0), 1000);
      expect(lastSelected, DateTime(2026, 1, 14));
    });

    testWidgets('tapping the month header opens the date picker', (tester) async {
      await tester.pumpWidget(strip(selected));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('January'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });

  group('DiaryWeekSummary', () {
    testWidgets('is collapsed by default and shows total and average when expanded', (tester) async {
      final map = {
        '2026-01-05': TrackedDayEntity(
          day: DateTime(2026, 1, 5),
          calorieGoal: 2000,
          caloriesTracked: 1800,
          fatTracked: 60,
          proteinTracked: 100,
          carbsTracked: 200,
        ),
        '2026-01-06': TrackedDayEntity(
          day: DateTime(2026, 1, 6),
          calorieGoal: 2000,
          caloriesTracked: 2200,
          fatTracked: 80,
          proteinTracked: 120,
          carbsTracked: 240,
        ),
      };
      await tester.pumpWidget(
        _wrap(
          DiaryWeekSummary(
            selectedDate: selected,
            trackedDaysMap: map,
            getTrackedDayUsecase: GetTrackedDayUsecase(_EmptyTrackedDayRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(S.current.diaryWeekSummaryTitle), findsOneWidget);
      expect(find.text('4000 kcal · 140 g fat · 220 g protein · 440 g carbs'), findsNothing);

      await tester.tap(find.text(S.current.diaryWeekSummaryTitle));
      await tester.pumpAndSettle();

      expect(find.text('4000 kcal · 140 g fat · 220 g protein · 440 g carbs'), findsOneWidget);
      expect(find.text('2000 kcal · 70 g fat · 110 g protein · 220 g carbs'), findsOneWidget);
    });
  });
}
