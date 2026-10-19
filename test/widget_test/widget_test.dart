import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/home/presentation/widgets/dashboard_widget.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('DashboardWidget displays correct data', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider<EnergyUnitProvider>(
        create: (_) => EnergyUnitProvider(),
        child: MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: const DashboardWidget(
            totalKcalSupplied: 1500,
            totalKcalBurned: 500,
            totalKcalDaily: 2000,
            totalKcalLeft: 1000,
            totalCarbsIntake: 200,
            totalFatsIntake: 50,
            totalProteinsIntake: 100,
            totalCarbsGoal: 250,
            totalFatsGoal: 60,
            totalProteinsGoal: 120,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify that the supplied and burned calorie values are displayed.
    expect(find.text('1500'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);

    // Verify that the kcal left label is displayed as AnimatedFlipCounter
    final kcalLeftFlipCounter = tester.firstWidget<AnimatedFlipCounter>(
      find.byType(AnimatedFlipCounter),
    );
    expect(kcalLeftFlipCounter.value, 1000);
  });

  // QA 2026-10-19: values are rounded, not truncated, so Home, Diary,
  // Strategy and the edit dialog agree (2465.8 kcal showed as 2465 on
  // Diary and 2466 on Strategy; 52.5 g protein as 52 vs 53).
  testWidgets('DashboardWidget rounds kcal and grams', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<EnergyUnitProvider>(
        create: (_) => EnergyUnitProvider(),
        child: MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: const DashboardWidget(
            totalKcalSupplied: 959.6,
            totalKcalBurned: 0,
            totalKcalDaily: 2465.8,
            totalKcalLeft: 1506.2,
            totalCarbsIntake: 119.5,
            totalFatsIntake: 30.4,
            totalProteinsIntake: 52.5,
            totalCarbsGoal: 222.6,
            totalFatsGoal: 99.4,
            totalProteinsGoal: 170.5,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('960'), findsOneWidget);
    expect(tester.firstWidget<AnimatedFlipCounter>(find.byType(AnimatedFlipCounter)).value, 1506);
    expect(find.text('120/223 g'), findsOneWidget);
    expect(find.text('30/99 g'), findsOneWidget);
    expect(find.text('53/171 g'), findsOneWidget);
  });
}
