import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/profile/presentation/widgets/set_weekly_weight_goal_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';

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
  group('SetWeeklyWeightGoalDialog', () {
    testWidgets('Cancel returns WeeklyWeightGoalCancelled',
        (tester) async {
      WeeklyWeightGoalResult? captured;
      await tester.pumpWidget(_wrap(Builder(builder: (context) {
        return Center(
          child: ElevatedButton(
            onPressed: () async {
              captured = await showDialog<WeeklyWeightGoalResult>(
                context: context,
                builder: (_) => const SetWeeklyWeightGoalDialog(
                  currentGoalKg: null,
                  usesImperialUnits: false,
                  referenceWeightKg: 70.0,
                ),
              );
            },
            child: const Text('Open'),
          ),
        );
      })));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.dialogCancelLabel));
      await tester.pumpAndSettle();
      expect(captured, isA<WeeklyWeightGoalCancelled>());
    });

    testWidgets('Reset returns WeeklyWeightGoalCleared', (tester) async {
      WeeklyWeightGoalResult? captured;
      await tester.pumpWidget(_wrap(Builder(builder: (context) {
        return Center(
          child: ElevatedButton(
            onPressed: () async {
              captured = await showDialog<WeeklyWeightGoalResult>(
                context: context,
                builder: (_) => const SetWeeklyWeightGoalDialog(
                  currentGoalKg: 0.5,
                  usesImperialUnits: false,
                  referenceWeightKg: 70.0,
                ),
              );
            },
            child: const Text('Open'),
          ),
        );
      })));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.buttonResetLabel));
      await tester.pumpAndSettle();
      expect(captured, isA<WeeklyWeightGoalCleared>());
    });

    testWidgets('OK returns WeeklyWeightGoalSet with the slider value',
        (tester) async {
      WeeklyWeightGoalResult? captured;
      await tester.pumpWidget(_wrap(Builder(builder: (context) {
        return Center(
          child: ElevatedButton(
            onPressed: () async {
              captured = await showDialog<WeeklyWeightGoalResult>(
                context: context,
                builder: (_) => const SetWeeklyWeightGoalDialog(
                  currentGoalKg: -0.25,
                  usesImperialUnits: false,
                  referenceWeightKg: 70.0,
                ),
              );
            },
            child: const Text('Open'),
          ),
        );
      })));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.dialogOKLabel));
      await tester.pumpAndSettle();
      expect(captured, isA<WeeklyWeightGoalSet>());
      expect((captured as WeeklyWeightGoalSet).kgPerWeek, -0.25);
    });

    testWidgets('slider bounds scale to 1% of the reference weight', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SetWeeklyWeightGoalDialog(
            currentGoalKg: null,
            usesImperialUnits: false,
            referenceWeightKg: 100.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, -1.0);
      expect(slider.max, 1.0);
      expect(find.text('-1.0 kg'), findsOneWidget);
      expect(find.text('+1.0 kg'), findsOneWidget);
    });

    testWidgets(
      'a currentGoalKg outside the reference-weight bound is clamped',
      (tester) async {
        WeeklyWeightGoalResult? captured;
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      captured = await showDialog<WeeklyWeightGoalResult>(
                        context: context,
                        builder: (_) => const SetWeeklyWeightGoalDialog(
                          currentGoalKg: 5.0,
                          usesImperialUnits: false,
                          referenceWeightKg: 50.0,
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(S.current.dialogOKLabel));
        await tester.pumpAndSettle();

        expect(captured, isA<WeeklyWeightGoalSet>());
        // 1% of 50 kg = 0.5 kg — the 5.0 kg stored goal gets clamped down
        // to the slider's max rather than crashing or silently overshooting.
        expect((captured as WeeklyWeightGoalSet).kgPerWeek, 0.5);
      },
    );
  });
}
