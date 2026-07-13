import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/save_recipe_usecase.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/magic_food_item_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/generate_meal_name_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/review_meal_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _FakeAddIntakeUsecase extends Fake implements AddIntakeUsecase {
  final List<IntakeEntity> added = [];

  @override
  Future<void> addIntake(IntakeEntity intakeEntity) async {
    added.add(intakeEntity);
  }
}

class _FakeAddTrackedDayUsecase extends Fake implements AddTrackedDayUsecase {
  @override
  Future<bool> hasTrackedDay(DateTime day) async => true;

  @override
  Future<void> addDayCaloriesTracked(DateTime day, double amount) async {}

  @override
  Future<void> addDayMacrosTracked(
    DateTime day, {
    double? carbsTracked,
    double? fatTracked,
    double? proteinTracked,
  }) async {}
}

class _FakeGetKcalGoalUsecase extends Fake implements GetKcalGoalUsecase {
  @override
  Future<double> getKcalGoal({
    dynamic userEntity,
    double? totalKcalActivitiesParam,
    double? kcalUserAdjustment,
  }) async => 2000;
}

class _FakeGetMacroGoalUsecase extends Fake implements GetMacroGoalUsecase {
  @override
  Future<double> getCarbsGoal(double totalCalorieGoal) async => 250;
  @override
  Future<double> getFatsGoal(double totalCalorieGoal) async => 60;
  @override
  Future<double> getProteinsGoal(double totalCalorieGoal) async => 100;
}

class _FakeSaveRecipeUseCase extends Fake implements SaveRecipeUseCase {
  RecipeEntity? lastSaved;
  Object? error;

  @override
  Future<RecipeEntity> save(
    RecipeEntity recipe, {
    bool totalWeightOverridden = false,
  }) async {
    if (error != null) throw error!;
    lastSaved = recipe;
    return recipe;
  }
}

class _FakeGetConfigUsecase extends Fake implements GetConfigUsecase {
  ConfigEntity config;
  _FakeGetConfigUsecase(this.config);

  @override
  Future<ConfigEntity> getConfig() async => config;
}

class _FakeGenerateMealNameUsecase extends Fake
    implements GenerateMealNameUsecase {
  String? result;
  Object? error;
  List<String>? lastItemNames;

  @override
  Future<String> generate({
    required String apiKey,
    required String model,
    required List<String> itemNames,
  }) async {
    lastItemNames = itemNames;
    if (error != null) throw error!;
    return result ?? '';
  }
}

final _configuredForAi = ConfigEntity(
  false,
  false,
  false,
  AppThemeEntity.dark,
  openRouterApiKey: 'sk-or-test',
  openRouterModelId: 'openai/gpt-4o',
);

final _notConfiguredForAi = const ConfigEntity(
  false,
  false,
  false,
  AppThemeEntity.dark,
);

final _twoItems = [
  const MagicFoodItemEntity(
    name: 'Sliced Beef',
    kcal: 275,
    grams: 110,
    confidence: MagicConfidence.medium,
    carbsG: 0,
    fatG: 17,
    proteinG: 28,
  ),
  const MagicFoodItemEntity(
    name: 'Wide Rice Noodles',
    kcal: 154,
    grams: 140,
    confidence: MagicConfidence.high,
    carbsG: 35,
    fatG: 0,
    proteinG: 2,
  ),
];

Widget _wrap(
  Widget child, {
  List<MagicFoodItemEntity>? items,
  String? imagePath,
}) {
  final args = ReviewMealScreenArguments(
    items: items ?? _twoItems,
    imagePath: imagePath,
    mealType: AddMealType.breakfastType,
    day: DateTime(2026, 1, 1),
  );
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    initialRoute: NavigationOptions.mainRoute,
    onGenerateRoute: (settings) {
      if (settings.name == NavigationOptions.mainRoute) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('main-screen')),
        );
      }
      return MaterialPageRoute(
        settings: RouteSettings(name: settings.name, arguments: args),
        builder: (_) => child,
      );
    },
  );
}

// Taller than the default test viewport so the item list + both buttons
// mount into the element tree (same fix as magic_screen_test.dart).
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pushReviewScreen(WidgetTester tester) async {
  final context = tester.element(find.text('main-screen'));
  Navigator.of(context).pushNamed(NavigationOptions.reviewMealRoute);
  await tester.pumpAndSettle();
}

void main() {
  group('ReviewMealScreen', () {
    testWidgets('renders items with prefilled grams, kcal and confidence', (
      tester,
    ) async {
      _useTallViewport(tester);
      await tester.pumpWidget(
        _wrap(
          ReviewMealScreen(
            addIntakeUsecase: _FakeAddIntakeUsecase(),
            addTrackedDayUsecase: _FakeAddTrackedDayUsecase(),
            getKcalGoalUsecase: _FakeGetKcalGoalUsecase(),
            getMacroGoalUsecase: _FakeGetMacroGoalUsecase(),
            saveRecipeUseCase: _FakeSaveRecipeUseCase(),
            getConfigUsecase: _FakeGetConfigUsecase(_notConfiguredForAi),
            generateMealNameUsecase: _FakeGenerateMealNameUsecase(),
          ),
        ),
      );
      await _pushReviewScreen(tester);

      expect(find.text('Sliced Beef'), findsOneWidget);
      expect(find.text('Wide Rice Noodles'), findsOneWidget);
      expect(find.text('110'), findsOneWidget);
      expect(find.text('140'), findsOneWidget);
      expect(find.text(S.current.reviewMealConfidenceMedium), findsOneWidget);
      expect(find.text(S.current.reviewMealConfidenceHigh), findsOneWidget);
      // 275 + 154 = 429 total kcal.
      expect(find.text(S.current.reviewMealTotalKcalLabel(429)), findsOneWidget);
    });

    testWidgets('editing grams rescales that item and the total kcal', (
      tester,
    ) async {
      _useTallViewport(tester);
      await tester.pumpWidget(
        _wrap(
          ReviewMealScreen(
            addIntakeUsecase: _FakeAddIntakeUsecase(),
            addTrackedDayUsecase: _FakeAddTrackedDayUsecase(),
            getKcalGoalUsecase: _FakeGetKcalGoalUsecase(),
            getMacroGoalUsecase: _FakeGetMacroGoalUsecase(),
            saveRecipeUseCase: _FakeSaveRecipeUseCase(),
            getConfigUsecase: _FakeGetConfigUsecase(_notConfiguredForAi),
            generateMealNameUsecase: _FakeGenerateMealNameUsecase(),
          ),
          items: [_twoItems.first],
        ),
      );
      await _pushReviewScreen(tester);

      // 275 kcal / 110 g = 2.5 kcal/g. Doubling to 220g -> 550 kcal.
      await tester.enterText(find.byType(TextFormField), '220');
      await tester.pumpAndSettle();

      expect(find.text('550 ${S.current.kcalLabel}'), findsOneWidget);
      expect(find.text(S.current.reviewMealTotalKcalLabel(550)), findsOneWidget);
    });

    testWidgets(
      'Add all persists an intake per item with current grams and returns to main',
      (tester) async {
        _useTallViewport(tester);
        final addIntakeUsecase = _FakeAddIntakeUsecase();
        await tester.pumpWidget(
          _wrap(
            ReviewMealScreen(
              addIntakeUsecase: addIntakeUsecase,
              addTrackedDayUsecase: _FakeAddTrackedDayUsecase(),
              getKcalGoalUsecase: _FakeGetKcalGoalUsecase(),
              getMacroGoalUsecase: _FakeGetMacroGoalUsecase(),
              saveRecipeUseCase: _FakeSaveRecipeUseCase(),
              getConfigUsecase: _FakeGetConfigUsecase(_notConfiguredForAi),
              generateMealNameUsecase: _FakeGenerateMealNameUsecase(),
            ),
          ),
        );
        await _pushReviewScreen(tester);

        await tester.tap(find.text(S.current.reviewMealAddAllButton(2)));
        await tester.pumpAndSettle();

        expect(addIntakeUsecase.added, hasLength(2));
        expect(addIntakeUsecase.added[0].meal.name, 'Sliced Beef');
        expect(addIntakeUsecase.added[0].amount, 110);
        expect(addIntakeUsecase.added[1].meal.name, 'Wide Rice Noodles');
        expect(addIntakeUsecase.added[1].amount, 140);
        // popUntil(mainRoute) should leave the main-screen placeholder as
        // the only route left on the stack.
        expect(find.text('main-screen'), findsOneWidget);
      },
    );

    testWidgets(
      'Save as preset builds a multi-ingredient recipe from current grams',
      (tester) async {
        _useTallViewport(tester);
        final saveRecipeUseCase = _FakeSaveRecipeUseCase();
        await tester.pumpWidget(
          _wrap(
            ReviewMealScreen(
              addIntakeUsecase: _FakeAddIntakeUsecase(),
              addTrackedDayUsecase: _FakeAddTrackedDayUsecase(),
              getKcalGoalUsecase: _FakeGetKcalGoalUsecase(),
              getMacroGoalUsecase: _FakeGetMacroGoalUsecase(),
              saveRecipeUseCase: saveRecipeUseCase,
              getConfigUsecase: _FakeGetConfigUsecase(_notConfiguredForAi),
              generateMealNameUsecase: _FakeGenerateMealNameUsecase(),
            ),
          ),
        );
        await _pushReviewScreen(tester);

        await tester.tap(find.text(S.current.reviewMealSaveAsPresetButton));
        await tester.pumpAndSettle();

        final dialogNameField = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(dialogNameField, 'Beef stir-fry');
        await tester.pumpAndSettle();
        await tester.tap(find.text(S.current.buttonSaveLabel));
        await tester.pumpAndSettle();

        expect(saveRecipeUseCase.lastSaved, isNotNull);
        expect(saveRecipeUseCase.lastSaved!.name, 'Beef stir-fry');
        expect(saveRecipeUseCase.lastSaved!.ingredients, hasLength(2));
        expect(
          saveRecipeUseCase.lastSaved!.ingredients[0].snapshotMeal.name,
          'Sliced Beef',
        );
        expect(saveRecipeUseCase.lastSaved!.ingredients[0].convertedAmountG, 110);
        expect(
          find.text(S.current.reviewMealPresetSavedSnackbar),
          findsOneWidget,
        );
      },
    );

    testWidgets('cancelling the preset dialog does not save anything', (
      tester,
    ) async {
      _useTallViewport(tester);
      final saveRecipeUseCase = _FakeSaveRecipeUseCase();
      await tester.pumpWidget(
        _wrap(
          ReviewMealScreen(
            addIntakeUsecase: _FakeAddIntakeUsecase(),
            addTrackedDayUsecase: _FakeAddTrackedDayUsecase(),
            getKcalGoalUsecase: _FakeGetKcalGoalUsecase(),
            getMacroGoalUsecase: _FakeGetMacroGoalUsecase(),
            saveRecipeUseCase: saveRecipeUseCase,
            getConfigUsecase: _FakeGetConfigUsecase(_notConfiguredForAi),
            generateMealNameUsecase: _FakeGenerateMealNameUsecase(),
          ),
        ),
      );
      await _pushReviewScreen(tester);

      await tester.tap(find.text(S.current.reviewMealSaveAsPresetButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.dialogCancelLabel));
      await tester.pumpAndSettle();

      expect(saveRecipeUseCase.lastSaved, isNull);
    });

    testWidgets(
      'Save as preset pre-fills the dialog with an AI-suggested name',
      (tester) async {
        _useTallViewport(tester);
        final generateMealNameUsecase = _FakeGenerateMealNameUsecase()
          ..result = 'Beef Noodle Stir-Fry';
        final saveRecipeUseCase = _FakeSaveRecipeUseCase();
        await tester.pumpWidget(
          _wrap(
            ReviewMealScreen(
              addIntakeUsecase: _FakeAddIntakeUsecase(),
              addTrackedDayUsecase: _FakeAddTrackedDayUsecase(),
              getKcalGoalUsecase: _FakeGetKcalGoalUsecase(),
              getMacroGoalUsecase: _FakeGetMacroGoalUsecase(),
              saveRecipeUseCase: saveRecipeUseCase,
              getConfigUsecase: _FakeGetConfigUsecase(_configuredForAi),
              generateMealNameUsecase: generateMealNameUsecase,
            ),
          ),
        );
        await _pushReviewScreen(tester);

        await tester.tap(find.text(S.current.reviewMealSaveAsPresetButton));
        await tester.pumpAndSettle();

        expect(
          generateMealNameUsecase.lastItemNames,
          ['Sliced Beef', 'Wide Rice Noodles'],
        );
        final dialogNameField = tester.widget<TextField>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
        );
        expect(dialogNameField.controller!.text, 'Beef Noodle Stir-Fry');

        await tester.tap(find.text(S.current.buttonSaveLabel));
        await tester.pumpAndSettle();

        expect(saveRecipeUseCase.lastSaved?.name, 'Beef Noodle Stir-Fry');
      },
    );

    testWidgets(
      'falls back to the single-item name when name generation fails',
      (tester) async {
        _useTallViewport(tester);
        final generateMealNameUsecase = _FakeGenerateMealNameUsecase()
          ..error = Exception('network down');

        await tester.pumpWidget(
          _wrap(
            ReviewMealScreen(
              addIntakeUsecase: _FakeAddIntakeUsecase(),
              addTrackedDayUsecase: _FakeAddTrackedDayUsecase(),
              getKcalGoalUsecase: _FakeGetKcalGoalUsecase(),
              getMacroGoalUsecase: _FakeGetMacroGoalUsecase(),
              saveRecipeUseCase: _FakeSaveRecipeUseCase(),
              getConfigUsecase: _FakeGetConfigUsecase(_configuredForAi),
              generateMealNameUsecase: generateMealNameUsecase,
            ),
            items: [_twoItems.first],
          ),
        );
        await _pushReviewScreen(tester);

        await tester.tap(find.text(S.current.reviewMealSaveAsPresetButton));
        await tester.pumpAndSettle();

        final dialogNameField = tester.widget<TextField>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
        );
        // Single item -> falls back to that item's own name, same as when
        // no API key is configured at all.
        expect(dialogNameField.controller!.text, 'Sliced Beef');
      },
    );
  });
}
