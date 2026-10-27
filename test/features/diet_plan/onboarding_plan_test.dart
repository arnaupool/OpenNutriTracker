import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/onboarding/presentation/widgets/onboarding_overview_page_body.dart';
import 'package:opennutritracker/features/onboarding/presentation/widgets/onboarding_plan_page_body.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

Widget _wrap(Widget child) => ChangeNotifierProvider(
  create: (_) => EnergyUnitProvider(),
  child: MaterialApp(
    localizationsDelegates: const [S.delegate],
    supportedLocales: S.delegate.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  group('plan page', () {
    testWidgets('shows kilos, adjusts them in half-kilo steps and picks the pace', (tester) async {
      var loss = 10.0;
      var pace = 0.5;
      late StateSetter setOuter;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return SizedBox(
                height: 600,
                child: OnboardingPlanPageBody(
                  isLoseGoal: true,
                  lossKg: loss,
                  maxLossKg: 50,
                  paceKgPerWeek: pace,
                  onLossChanged: (v) => setOuter(() => loss = v),
                  onPaceChanged: (v) => setOuter(() => pace = v),
                ),
              );
            },
          ),
        ),
      );
      expect(find.text('10.0 kg'), findsOneWidget);
      expect(find.text('0.25 kg/week'), findsOneWidget);
      expect(find.text('0.5 kg/week'), findsOneWidget);
      expect(find.text('0.75 kg/week'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      expect(loss, 10.5);
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pump();
      expect(loss, 9.5);

      await tester.tap(find.text('0.75 kg/week'));
      await tester.pump();
      expect(pace, 0.75);
    });

    testWidgets('limits go from 0.5 kg to the cap', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 600,
            child: OnboardingPlanPageBody(
              isLoseGoal: true,
              lossKg: 0.5,
              maxLossKg: 15,
              paceKgPerWeek: 0.5,
              onLossChanged: (_) {},
              onPaceChanged: (_) {},
            ),
          ),
        ),
      );
      final minus = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove_circle_outline));
      expect(minus.onPressed, isNull);
    });

    testWidgets('other goals only see a note', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingPlanPageBody(
            isLoseGoal: false,
            lossKg: 5,
            maxLossKg: 50,
            paceKgPerWeek: 0.5,
            onLossChanged: (_) {},
            onPaceChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(Slider), findsNothing);
      expect(find.textContaining('weight loss'), findsOneWidget);
    });
  });

  group('overview page', () {
    Widget overview({
      DateTime? end,
      bool warning = false,
      double? suggested,
      bool show = true,
      ValueChanged<bool>? onSwitch,
      VoidCallback? onApply,
    }) => OnboardingOverviewPageBody(
      calorieGoalDayString: '1800',
      carbsGoalString: '200',
      fatGoalString: '60',
      proteinGoalString: '120',
      setButtonActive: (_) {},
      showLowKcalWarning: warning,
      lowKcalWarningThreshold: 1200,
      planEnd: end,
      planDays: 140,
      showCountdown: show,
      onShowCountdownChanged: onSwitch,
      suggestedPace: suggested,
      onApplySuggestedPace: onApply,
    );

    testWidgets('states the end date and day count and has the countdown switch', (tester) async {
      bool? switched;
      await tester.pumpWidget(_wrap(overview(end: DateTime(2027, 3, 16), onSwitch: (v) => switched = v)));
      expect(find.text("You'd reach your goal on 16/03/2027 (140 days)"), findsOneWidget);
      final tile = find.widgetWithText(SwitchListTile, 'Show countdown on Home');
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      await tester.tap(tile);
      expect(switched, isFalse);
    });

    testWidgets('no plan line for other goals', (tester) async {
      await tester.pumpWidget(_wrap(overview()));
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.textContaining('reach your goal'), findsNothing);
    });

    testWidgets('floor warning offers a lower pace', (tester) async {
      var applied = 0;
      await tester.pumpWidget(
        _wrap(overview(end: DateTime(2027, 3, 16), warning: true, suggested: 0.25, onApply: () => applied++)),
      );
      expect(find.textContaining('try 0.25 kg/week'), findsOneWidget);
      await tester.tap(find.text('Use 0.25 kg/week'));
      expect(applied, 1);
    });
  });
}
