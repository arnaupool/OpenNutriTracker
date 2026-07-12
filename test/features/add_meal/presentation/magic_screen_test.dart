import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/open_router_model_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_open_router_models_usecase.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/magic_food_item_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/analyze_meal_with_ai_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/magic_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/review_meal_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

const _models = [
  OpenRouterModelEntity(
    id: 'openai/gpt-4o',
    name: 'OpenAI: GPT-4o',
    supportsImages: true,
  ),
  OpenRouterModelEntity(
    id: 'meta-llama/llama-guard-4',
    name: 'Meta: Llama Guard 4',
    supportsImages: false,
  ),
];

class _FakeGetOpenRouterModelsUsecase extends Fake
    implements GetOpenRouterModelsUsecase {
  List<OpenRouterModelEntity> models = _models;
  Object? error;

  @override
  Future<List<OpenRouterModelEntity>> getModels() async {
    if (error != null) throw error!;
    return models;
  }
}

class _FakeGetConfigUsecase extends Fake implements GetConfigUsecase {
  ConfigEntity config;
  _FakeGetConfigUsecase(this.config);

  @override
  Future<ConfigEntity> getConfig() async => config;
}

class _FakeAnalyzeMealWithAiUsecase extends Fake
    implements AnalyzeMealWithAiUsecase {
  List<MagicFoodItemEntity>? result;
  Object? error;
  bool? lastMealBreakdown;
  String? lastDescription;

  @override
  Future<List<MagicFoodItemEntity>> analyze({
    required String apiKey,
    required String model,
    required bool mealBreakdown,
    String? description,
    String? base64Image,
    String imageMimeType = 'image/jpeg',
  }) async {
    lastMealBreakdown = mealBreakdown;
    lastDescription = description;
    if (error != null) throw error!;
    return result ?? const [];
  }
}

class _SpyNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

Widget _wrap(Widget child, {NavigatorObserver? observer}) {
  final args = AddMealScreenArguments(
    AddMealType.breakfastType,
    DateTime(2026, 1, 1),
  );
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    navigatorObservers: observer == null ? const [] : [observer],
    onGenerateRoute: (settings) {
      if (settings.name == '/') {
        return MaterialPageRoute(
          settings: RouteSettings(name: '/', arguments: args),
          builder: (_) => child,
        );
      }
      // The review meal route just needs to exist so pushNamed resolves —
      // this test only cares about which route/arguments got pushed.
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => Scaffold(body: Text('dest:${settings.name}')),
      );
    },
    initialRoute: '/',
  );
}

// The full screen (photo picker + buttons + description + toggle +
// provider/model dropdowns + Analyze) is taller than the default test
// viewport, so widgets past the fold wouldn't otherwise mount into the
// element tree for find.text to see (same fix as strategy_page_test.dart).
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  // image_picker needs a platform implementation registered under test.
  ImagePickerPlatform.instance = _NoOpImagePickerPlatform();

  group('MagicScreen', () {
    testWidgets('loads the model catalog and preselects the configured model', (
      tester,
    ) async {
      _useTallViewport(tester);
      final config = ConfigEntity(
        false,
        false,
        false,
        AppThemeEntity.dark,
        openRouterApiKey: 'sk-or-test',
        openRouterModelId: 'meta-llama/llama-guard-4',
      );
      await tester.pumpWidget(
        _wrap(
          MagicScreen(
            getOpenRouterModelsUsecase: _FakeGetOpenRouterModelsUsecase(),
            getConfigUsecase: _FakeGetConfigUsecase(config),
            analyzeMealWithAiUsecase: _FakeAnalyzeMealWithAiUsecase(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Meta'), findsOneWidget);
      expect(find.text('Llama Guard 4'), findsOneWidget);
    });

    testWidgets('Analyze is disabled until there is text or a photo', (
      tester,
    ) async {
      _useTallViewport(tester);
      final config = ConfigEntity(
        false,
        false,
        false,
        AppThemeEntity.dark,
        openRouterApiKey: 'sk-or-test',
      );
      await tester.pumpWidget(
        _wrap(
          MagicScreen(
            getOpenRouterModelsUsecase: _FakeGetOpenRouterModelsUsecase(),
            getConfigUsecase: _FakeGetConfigUsecase(config),
            analyzeMealWithAiUsecase: _FakeAnalyzeMealWithAiUsecase(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final analyzeButtonBefore = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(analyzeButtonBefore.onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'a bowl of oatmeal');
      await tester.pumpAndSettle();

      final analyzeButtonAfter = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(analyzeButtonAfter.onPressed, isNotNull);
    });

    testWidgets(
      'analyzing with results navigates to Review meal with the same args',
      (tester) async {
        _useTallViewport(tester);
        final config = ConfigEntity(
          false,
          false,
          false,
          AppThemeEntity.dark,
          openRouterApiKey: 'sk-or-test',
        );
        final analyzeUsecase = _FakeAnalyzeMealWithAiUsecase()
          ..result = const [
            MagicFoodItemEntity(
              name: 'Oatmeal',
              kcal: 300,
              grams: 250,
              confidence: MagicConfidence.high,
              carbsG: 50,
              fatG: 6,
              proteinG: 10,
            ),
          ];
        final observer = _SpyNavigatorObserver();

        await tester.pumpWidget(
          _wrap(
            MagicScreen(
              getOpenRouterModelsUsecase: _FakeGetOpenRouterModelsUsecase(),
              getConfigUsecase: _FakeGetConfigUsecase(config),
              analyzeMealWithAiUsecase: analyzeUsecase,
            ),
            observer: observer,
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'a bowl of oatmeal');
        await tester.pumpAndSettle();
        await tester.tap(find.text(S.current.magicAnalyzeButton));
        await tester.pumpAndSettle();

        expect(analyzeUsecase.lastDescription, 'a bowl of oatmeal');
        expect(analyzeUsecase.lastMealBreakdown, isFalse);

        final pushed = observer.pushed.last.settings;
        expect(pushed.name, NavigationOptions.reviewMealRoute);
        final reviewArgs = pushed.arguments as ReviewMealScreenArguments;
        expect(reviewArgs.items, hasLength(1));
        expect(reviewArgs.items.single.name, 'Oatmeal');
        expect(reviewArgs.mealType, AddMealType.breakfastType);
      },
    );

    testWidgets('shows an error when no API key is configured', (tester) async {
      _useTallViewport(tester);
      final config = const ConfigEntity(
        false,
        false,
        false,
        AppThemeEntity.dark,
      );
      await tester.pumpWidget(
        _wrap(
          MagicScreen(
            getOpenRouterModelsUsecase: _FakeGetOpenRouterModelsUsecase(),
            getConfigUsecase: _FakeGetConfigUsecase(config),
            analyzeMealWithAiUsecase: _FakeAnalyzeMealWithAiUsecase(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'a bowl of oatmeal');
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.magicAnalyzeButton));
      await tester.pumpAndSettle();

      expect(find.text(S.current.magicNoApiKeyError), findsOneWidget);
    });

    testWidgets('shows an error when analysis throws', (tester) async {
      _useTallViewport(tester);
      final config = ConfigEntity(
        false,
        false,
        false,
        AppThemeEntity.dark,
        openRouterApiKey: 'sk-or-test',
      );
      final analyzeUsecase = _FakeAnalyzeMealWithAiUsecase()
        ..error = const MagicAnalysisException('boom');

      await tester.pumpWidget(
        _wrap(
          MagicScreen(
            getOpenRouterModelsUsecase: _FakeGetOpenRouterModelsUsecase(),
            getConfigUsecase: _FakeGetConfigUsecase(config),
            analyzeMealWithAiUsecase: analyzeUsecase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'a bowl of oatmeal');
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.magicAnalyzeButton));
      await tester.pumpAndSettle();

      expect(find.text(S.current.magicAnalysisFailedError), findsOneWidget);
    });

    testWidgets('shows an error when the model found no food', (tester) async {
      _useTallViewport(tester);
      final config = ConfigEntity(
        false,
        false,
        false,
        AppThemeEntity.dark,
        openRouterApiKey: 'sk-or-test',
      );
      final analyzeUsecase = _FakeAnalyzeMealWithAiUsecase()..result = const [];

      await tester.pumpWidget(
        _wrap(
          MagicScreen(
            getOpenRouterModelsUsecase: _FakeGetOpenRouterModelsUsecase(),
            getConfigUsecase: _FakeGetConfigUsecase(config),
            analyzeMealWithAiUsecase: analyzeUsecase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'a bowl of oatmeal');
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.magicAnalyzeButton));
      await tester.pumpAndSettle();

      expect(find.text(S.current.magicEmptyResultError), findsOneWidget);
    });

    testWidgets('meal-breakdown toggle is passed through to the usecase', (
      tester,
    ) async {
      _useTallViewport(tester);
      final config = ConfigEntity(
        false,
        false,
        false,
        AppThemeEntity.dark,
        openRouterApiKey: 'sk-or-test',
      );
      final analyzeUsecase = _FakeAnalyzeMealWithAiUsecase();

      await tester.pumpWidget(
        _wrap(
          MagicScreen(
            getOpenRouterModelsUsecase: _FakeGetOpenRouterModelsUsecase(),
            getConfigUsecase: _FakeGetConfigUsecase(config),
            analyzeMealWithAiUsecase: analyzeUsecase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.magicMealBreakdownLabel));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'rice and chicken');
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.magicAnalyzeButton));
      await tester.pumpAndSettle();

      expect(analyzeUsecase.lastMealBreakdown, isTrue);
    });
  });
}

/// Minimal no-op platform so `ImagePicker()` can be constructed under test
/// without a real camera/gallery — none of these tests actually invoke
/// pickImage, they only need the widget tree to build.
class _NoOpImagePickerPlatform extends ImagePickerPlatform {}
