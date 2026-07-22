import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/features/home/presentation/widgets/weigh_in_habit_card.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:table_calendar/table_calendar.dart';

class _FakeGetWeightLogUsecase extends Fake implements GetWeightLogUsecase {
  final List<WeightLogEntity> _entries;
  _FakeGetWeightLogUsecase(this._entries);

  @override
  Future<List<WeightLogEntity>> getEntriesInRange(
    DateTime from,
    DateTime to,
  ) async {
    return _entries
        .where((e) => !e.date.isBefore(from) && !e.date.isAfter(to))
        .toList();
  }
}

// TableCalendar<T> is generic and instantiated without an explicit type
// argument, so find.byType(TableCalendar) (which resolves the bare type to
// TableCalendar<dynamic>) never matches the actual TableCalendar<Object?>
// in the tree. `is TableCalendar` checks against the raw class instead.
Finder get _findTableCalendar =>
    find.byWidgetPredicate((widget) => widget is TableCalendar);

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
  group('WeighInHabitCard', () {
    testWidgets('shows the card title and a compact non-interactive '
        'calendar with no weigh-ins logged', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WeighInHabitCard(getWeightLogUsecase: _FakeGetWeightLogUsecase([])),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(S.current.homeWeighInHabitCardTitle), findsOneWidget);
      expect(_findTableCalendar, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without throwing when there are weigh-ins earlier '
        'this month', (tester) async {
      final today = DateTime.now();
      final earlierThisMonth = DateTime(today.year, today.month, 1);

      await tester.pumpWidget(
        _wrap(
          WeighInHabitCard(
            getWeightLogUsecase: _FakeGetWeightLogUsecase([
              WeightLogEntity(date: earlierThisMonth, weightKg: 84.0),
              WeightLogEntity(date: today, weightKg: 83.5),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_findTableCalendar, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
