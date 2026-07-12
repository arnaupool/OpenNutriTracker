import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/open_router_model_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_open_router_models_usecase.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/open_router_settings_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _FakeConfigRepository extends Fake implements ConfigRepository {
  ConfigEntity config;
  String? savedApiKey;
  String? savedModelId;

  _FakeConfigRepository(this.config);

  @override
  Future<ConfigEntity> getConfig() async => config;

  @override
  Future<void> setConfigOpenRouterApiKey(String? value) async {
    savedApiKey = value;
  }

  @override
  Future<void> setConfigOpenRouterModelId(String? value) async {
    savedModelId = value;
  }
}

class _FakeGetOpenRouterModelsUsecase extends Fake
    implements GetOpenRouterModelsUsecase {
  List<OpenRouterModelEntity>? models;
  Object? error;

  @override
  Future<List<OpenRouterModelEntity>> getModels() async {
    if (error != null) throw error!;
    return models ?? const [];
  }
}

const _models = [
  OpenRouterModelEntity(
    id: 'openai/gpt-4o',
    name: 'GPT-4o',
    supportsImages: true,
  ),
  OpenRouterModelEntity(
    id: 'meta-llama/llama-3-8b',
    name: 'Llama 3 8B',
    supportsImages: false,
  ),
];

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: child,
  );
}

void main() {
  group('OpenRouterSettingsScreen', () {
    testWidgets(
      'loads with the stored API key pre-filled and the model catalog '
      'listed, highlighting the previously selected model',
      (tester) async {
        final configRepository = _FakeConfigRepository(
          ConfigEntity(
            false,
            false,
            false,
            AppThemeEntity.dark,
            openRouterApiKey: 'sk-or-existing',
            openRouterModelId: 'meta-llama/llama-3-8b',
          ),
        );
        final modelsUsecase = _FakeGetOpenRouterModelsUsecase()
          ..models = _models;

        await tester.pumpWidget(
          _wrap(
            OpenRouterSettingsScreen(
              getConfigUsecase: GetConfigUsecase(configRepository),
              getOpenRouterModelsUsecase: modelsUsecase,
              configRepository: configRepository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final apiKeyField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(apiKeyField.controller?.text, 'sk-or-existing');

        expect(find.text('GPT-4o'), findsOneWidget);
        expect(find.text('Llama 3 8B'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      },
    );

    testWidgets('tapping a model selects it and persists the choice', (
      tester,
    ) async {
      final configRepository = _FakeConfigRepository(
        const ConfigEntity(false, false, false, AppThemeEntity.dark),
      );
      final modelsUsecase = _FakeGetOpenRouterModelsUsecase()..models = _models;

      await tester.pumpWidget(
        _wrap(
          OpenRouterSettingsScreen(
            getConfigUsecase: GetConfigUsecase(configRepository),
            getOpenRouterModelsUsecase: modelsUsecase,
            configRepository: configRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('GPT-4o'));
      await tester.pumpAndSettle();

      expect(configRepository.savedModelId, 'openai/gpt-4o');
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('search filters the model list by name and id', (tester) async {
      final configRepository = _FakeConfigRepository(
        const ConfigEntity(false, false, false, AppThemeEntity.dark),
      );
      final modelsUsecase = _FakeGetOpenRouterModelsUsecase()..models = _models;

      await tester.pumpWidget(
        _wrap(
          OpenRouterSettingsScreen(
            getConfigUsecase: GetConfigUsecase(configRepository),
            getOpenRouterModelsUsecase: modelsUsecase,
            configRepository: configRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'llama');
      await tester.pumpAndSettle();

      expect(find.text('GPT-4o'), findsNothing);
      expect(find.text('Llama 3 8B'), findsOneWidget);
    });

    testWidgets('saving the API key persists the trimmed value and shows a '
        'confirmation snackbar', (tester) async {
      final configRepository = _FakeConfigRepository(
        const ConfigEntity(false, false, false, AppThemeEntity.dark),
      );
      final modelsUsecase = _FakeGetOpenRouterModelsUsecase()..models = _models;

      await tester.pumpWidget(
        _wrap(
          OpenRouterSettingsScreen(
            getConfigUsecase: GetConfigUsecase(configRepository),
            getOpenRouterModelsUsecase: modelsUsecase,
            configRepository: configRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '  sk-or-new  ');
      await tester.tap(find.text(S.current.buttonSaveLabel));
      await tester.pumpAndSettle();

      expect(configRepository.savedApiKey, 'sk-or-new');
      expect(
        find.text(S.current.openRouterApiKeySavedSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('shows an error state with retry when the catalog fetch '
        'fails, and recovers on retry', (tester) async {
      final configRepository = _FakeConfigRepository(
        const ConfigEntity(false, false, false, AppThemeEntity.dark),
      );
      final modelsUsecase = _FakeGetOpenRouterModelsUsecase()
        ..error = Exception('network down');

      await tester.pumpWidget(
        _wrap(
          OpenRouterSettingsScreen(
            getConfigUsecase: GetConfigUsecase(configRepository),
            getOpenRouterModelsUsecase: modelsUsecase,
            configRepository: configRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(S.current.openRouterModelsLoadError), findsOneWidget);

      modelsUsecase
        ..error = null
        ..models = _models;
      await tester.tap(find.text(S.current.retryLabel));
      await tester.pumpAndSettle();

      expect(find.text('GPT-4o'), findsOneWidget);
    });
  });
}
