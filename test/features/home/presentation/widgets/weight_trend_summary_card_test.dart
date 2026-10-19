import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/features/home/presentation/widgets/weight_trend_summary_card.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _FakeGetWeightLogUsecase extends Fake implements GetWeightLogUsecase {
  final List<WeightLogEntity> _entries;
  _FakeGetWeightLogUsecase(this._entries);

  @override
  Future<List<WeightLogEntity>> getAllEntries() async => List.of(_entries);
}

class _FakeConfigRepository extends Fake implements ConfigRepository {
  final bool _usesImperialUnits;
  _FakeConfigRepository({bool usesImperialUnits = false})
    : _usesImperialUnits = usesImperialUnits;

  @override
  Future<ConfigEntity> getConfig() async {
    return ConfigEntity(
      false,
      false,
      false,
      AppThemeEntity.dark,
      usesImperialUnits: _usesImperialUnits,
    );
  }
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
    home: Scaffold(body: child),
  );
}

Widget _buildCard({
  required List<WeightLogEntity> weightEntries,
  bool usesImperialUnits = false,
}) {
  return WeightTrendSummaryCard(
    getWeightLogUsecase: _FakeGetWeightLogUsecase(weightEntries),
    configRepository: _FakeConfigRepository(
      usesImperialUnits: usesImperialUnits,
    ),
  );
}

void main() {
  group('WeightTrendSummaryCard', () {
    testWidgets(
      'shows the insufficient-data message with fewer trend points than '
      'TdeeDynamicCalc.minTrendPointsForDynamic',
      (tester) async {
        final today = DateTime.now();
        DateTime day(int daysAgo) {
          final d = today.subtract(Duration(days: daysAgo));
          return DateTime(d.year, d.month, d.day);
        }

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
        expect(find.text(S.current.homeWeightTrendStable), findsNothing);
      },
    );

    testWidgets(
      'shows a losing-weight rate with the trending-down icon once there '
      'is enough weight history',
      (tester) async {
        final today = DateTime.now();
        DateTime day(int daysAgo) {
          final d = today.subtract(Duration(days: daysAgo));
          return DateTime(d.year, d.month, d.day);
        }

        final weightEntries = [
          for (var i = 20; i >= 0; i--)
            WeightLogEntity(date: day(i), weightKg: 84.0 + i * 0.05),
        ];

        await tester.pumpWidget(
          _wrap(_buildCard(weightEntries: weightEntries)),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(S.current.homeExpenditureInsufficientData),
          findsNothing,
        );
        expect(find.text(S.current.homeWeightTrendLabel), findsOneWidget);
        expect(find.byIcon(Icons.trending_down_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'shows the stable label with the flat icon when the trend is nearly '
      'flat',
      (tester) async {
        final today = DateTime.now();
        DateTime day(int daysAgo) {
          final d = today.subtract(Duration(days: daysAgo));
          return DateTime(d.year, d.month, d.day);
        }

        final weightEntries = [
          for (var i = 20; i >= 0; i--)
            WeightLogEntity(date: day(i), weightKg: 84.0),
        ];

        await tester.pumpWidget(
          _wrap(_buildCard(weightEntries: weightEntries)),
        );
        await tester.pumpAndSettle();

        expect(find.text(S.current.homeWeightTrendStable), findsOneWidget);
        expect(find.byIcon(Icons.trending_flat_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'converts trend weight and rate to lbs when imperial units are on',
      (tester) async {
        final today = DateTime.now();
        DateTime day(int daysAgo) {
          final d = today.subtract(Duration(days: daysAgo));
          return DateTime(d.year, d.month, d.day);
        }

        final weightEntries = [
          for (var i = 20; i >= 0; i--)
            WeightLogEntity(date: day(i), weightKg: 84.0 + i * 0.05),
        ];

        await tester.pumpWidget(
          _wrap(
            _buildCard(weightEntries: weightEntries, usesImperialUnits: true),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining(S.current.lbsLabel), findsWidgets);
      },
    );

    // FD-13 (AUDIT.md B6): MacroFactor's change rate covers the past 20
    // days, so a rate built from weigh-ins months ago is not shown.
    testWidgets('weigh-ins that all predate the 20-day window show no rate', (
      tester,
    ) async {
      final today = DateTime.now();
      DateTime day(int daysAgo) {
        final d = today.subtract(Duration(days: daysAgo));
        return DateTime(d.year, d.month, d.day);
      }

      final weightEntries = [
        for (var i = 60; i >= 30; i--)
          WeightLogEntity(date: day(i), weightKg: 85.0 - 0.15 * (60 - i)),
      ];

      await tester.pumpWidget(_wrap(_buildCard(weightEntries: weightEntries)));
      await tester.pumpAndSettle();

      expect(find.text(S.current.homeWeightTrendNoRecentData), findsOneWidget);
      expect(find.textContaining('/week'), findsNothing);
    });
  });
}
