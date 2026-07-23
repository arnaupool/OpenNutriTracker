import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/edit_dialog.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

MealEntity _buildMeal({
  String? mealUnit = 'g',
  MealNutrimentsEntity? nutriments,
}) {
  return MealEntity(
    code: 'test-meal',
    name: 'Test Meal',
    url: null,
    mealQuantity: null,
    mealUnit: mealUnit,
    servingQuantity: null,
    servingUnit: null,
    servingSize: null,
    nutriments: nutriments ?? MealNutrimentsEntity.empty(),
    source: MealSourceEntity.custom,
  );
}

IntakeEntity _buildIntake({
  double amount = 100,
  String? mealUnit = 'g',
  MealNutrimentsEntity? nutriments,
}) {
  return IntakeEntity(
    id: 'intake-1',
    unit: 'g',
    amount: amount,
    type: IntakeTypeEntity.breakfast,
    meal: _buildMeal(mealUnit: mealUnit, nutriments: nutriments),
    dateTime: DateTime(2026, 5, 21),
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
    home: Scaffold(body: child),
  );
}

void main() {
  group('EditDialog', () {
    testWidgets('pre-fills the amount and shows the real unit as a suffix',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          EditDialog(
            intakeEntity: _buildIntake(amount: 150, mealUnit: 'g'),
            usesImperialUnits: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('150.00'), findsOneWidget);
      expect(find.text('g'), findsOneWidget);
    });

    testWidgets(
      "shows the g/ml fallback label instead of the raw 'gml' placeholder",
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            EditDialog(
              intakeEntity: _buildIntake(amount: 100, mealUnit: 'gml'),
              usesImperialUnits: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('gml'), findsNothing);
        expect(find.text(S.current.gramMilliliterUnit), findsOneWidget);
      },
    );

    testWidgets(
      'shows the calories/carbs/fat/protein for the item at its logged '
      'amount when the meal has nutrition data',
      (tester) async {
        final nutriments = const MealNutrimentsEntity(
          energyKcal100: 200,
          carbohydrates100: 50,
          fat100: 10,
          proteins100: 20,
          sugars100: null,
          saturatedFat100: null,
          fiber100: null,
        );

        await tester.pumpWidget(
          _wrap(
            EditDialog(
              intakeEntity: _buildIntake(
                amount: 150,
                mealUnit: 'g',
                nutriments: nutriments,
              ),
              usesImperialUnits: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 150 g at 200 kcal/50 g carbs/10 g fat/20 g protein per 100 g.
        expect(find.text('300 ${S.current.kcalLabel}'), findsOneWidget);
        expect(find.text('75 ${S.current.gramUnit}'), findsOneWidget);
        expect(find.text('15 ${S.current.gramUnit}'), findsOneWidget);
        expect(find.text('30 ${S.current.gramUnit}'), findsOneWidget);
      },
    );

    testWidgets(
      'updates the nutrition summary live as the user types a new amount',
      (tester) async {
        final nutriments = const MealNutrimentsEntity(
          energyKcal100: 100,
          carbohydrates100: 20,
          fat100: 5,
          proteins100: 10,
          sugars100: null,
          saturatedFat100: null,
          fiber100: null,
        );

        await tester.pumpWidget(
          _wrap(
            EditDialog(
              intakeEntity: _buildIntake(
                amount: 100,
                mealUnit: 'g',
                nutriments: nutriments,
              ),
              usesImperialUnits: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('100 ${S.current.kcalLabel}'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), '200');
        await tester.pumpAndSettle();

        expect(find.text('200 ${S.current.kcalLabel}'), findsOneWidget);
        expect(find.text('100 ${S.current.kcalLabel}'), findsNothing);
      },
    );

    testWidgets(
      'hides the nutrition summary entirely when the meal has no '
      'nutrition data at all',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            EditDialog(
              intakeEntity: _buildIntake(
                amount: 100,
                mealUnit: 'g',
                nutriments: MealNutrimentsEntity.empty(),
              ),
              usesImperialUnits: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(S.current.caloriesLabel), findsNothing);
        expect(find.text(S.current.carbsLabel), findsNothing);
      },
    );

    testWidgets('OK returns the amount converted back to the metric value',
        (tester) async {
      double? returned;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final future = showDialog<double>(
        context: capturedContext,
        builder: (_) => EditDialog(
          intakeEntity: _buildIntake(amount: 150, mealUnit: 'g'),
          usesImperialUnits: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '200');
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.dialogOKLabel));
      await tester.pumpAndSettle();
      returned = await future;

      expect(returned, 200);
    });
  });
}
