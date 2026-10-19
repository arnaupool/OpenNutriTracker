import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/features/home/presentation/widgets/weekly_expenditure_card.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _FakeGetWeightLogUsecase extends Fake implements GetWeightLogUsecase {
  final List<WeightLogEntity> _entries;
  _FakeGetWeightLogUsecase(this._entries);

  @override
  Future<List<WeightLogEntity>> getAllEntries() async => List.of(_entries);
}

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

Widget _wrap(Widget child) {
  return ChangeNotifierProvider<EnergyUnitProvider>(
    create: (_) => EnergyUnitProvider(),
    child: MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(body: child),
  ),
  );
}

Widget _buildCard({
  required List<WeightLogEntity> weightEntries,
  List<TrackedDayEntity> trackedDays = const [],
}) {
  return WeeklyExpenditureCard(
    getWeightLogUsecase: _FakeGetWeightLogUsecase(weightEntries),
    getTrackedDayUsecase: _FakeGetTrackedDayUsecase(trackedDays),
  );
}

void main() {
  group('WeeklyExpenditureCard', () {
    testWidgets(
      'shows the insufficient-data message with fewer trend points than '
      'TdeeDynamicCalc.minTrendPointsForDynamic',
      (tester) async {
        final today = DateTime.now();
        DateTime day(int daysAgo) {
          final d = today.subtract(Duration(days: daysAgo));
          return DateTime(d.year, d.month, d.day);
        }

        // Only 3 real weigh-ins -> fewer than the 7-point floor.
        final weightEntries = [
          WeightLogEntity(date: day(2), weightKg: 84.5),
          WeightLogEntity(date: day(1), weightKg: 84.3),
          WeightLogEntity(date: day(0), weightKg: 84.0),
        ];

        await tester.pumpWidget(
          _wrap(_buildCard(weightEntries: weightEntries)),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(S.current.homeExpenditureInsufficientData),
          findsOneWidget,
        );
        expect(find.text(S.current.homeExpenditureLabel), findsNothing);
      },
    );

    testWidgets(
      'shows Expenditure and Energy Balance once there is at least a '
      'week of real weigh-ins and matching intake',
      (tester) async {
        final today = DateTime.now();
        DateTime day(int daysAgo) {
          final d = today.subtract(Duration(days: daysAgo));
          return DateTime(d.year, d.month, d.day);
        }

        final weightEntries = [
          for (var i = 9; i >= 0; i--)
            WeightLogEntity(date: day(i), weightKg: 84.0 - (9 - i) * 0.05),
        ];
        final trackedDays = [
          for (var i = 0; i <= 9; i++)
            TrackedDayEntity(
              day: day(i),
              calorieGoal: 2400,
              caloriesTracked: 2300,
            ),
        ];

        await tester.pumpWidget(
          _wrap(
            _buildCard(
              weightEntries: weightEntries,
              trackedDays: trackedDays,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(S.current.homeExpenditureInsufficientData),
          findsNothing,
        );
        expect(find.text(S.current.homeExpenditureLabel), findsOneWidget);
        expect(find.text(S.current.homeEnergyBalanceLabel), findsOneWidget);
      },
    );

    testWidgets('renders nothing but stays mounted with zero weigh-ins', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_buildCard(weightEntries: const [])));
      await tester.pumpAndSettle();

      expect(
        find.text(S.current.homeExpenditureInsufficientData),
        findsOneWidget,
      );
    });
  });
}
