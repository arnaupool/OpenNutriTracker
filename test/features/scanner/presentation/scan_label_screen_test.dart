import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/scanner/domain/entity/scanned_label_entity.dart';
import 'package:opennutritracker/features/scanner/domain/usecase/analyze_label_with_ai_usecase.dart';
import 'package:opennutritracker/features/scanner/presentation/scan_label_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _FakeGetConfigUsecase extends Fake implements GetConfigUsecase {
  ConfigEntity config;
  _FakeGetConfigUsecase(this.config);

  @override
  Future<ConfigEntity> getConfig() async => config;
}

class _FakeAnalyzeLabelWithAiUsecase extends Fake
    implements AnalyzeLabelWithAiUsecase {
  ScannedLabelEntity? result;
  Object? error;

  @override
  Future<ScannedLabelEntity> analyze({
    required String apiKey,
    required String model,
    required String base64Image,
    String imageMimeType = 'image/jpeg',
  }) async {
    if (error != null) throw error!;
    return result!;
  }
}

/// Returns a canned [XFile] pointing at a real temp file — the screen
/// reads the bytes via `XFile.readAsBytes()` (cross-platform, works the
/// same on web where the path is a blob: URL), so the picked path must
/// still resolve to something that actually exists on disk here.
class _FakeImagePickerPlatform extends ImagePickerPlatform {
  final String path;
  _FakeImagePickerPlatform(this.path);

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile(path);
}

Widget _wrap(Widget child, {required List<Object?> pushedEditMealArgs}) {
  final args = ScanLabelScreenArguments(
    barcode: '5449000000996',
    day: DateTime(2026, 1, 1),
    intakeTypeEntity: IntakeTypeEntity.breakfast,
  );
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    onGenerateRoute: (settings) {
      if (settings.name == NavigationOptions.editMealRoute) {
        pushedEditMealArgs.add(settings.arguments);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('edit-meal')),
        );
      }
      return MaterialPageRoute(
        settings: RouteSettings(name: '/', arguments: args),
        builder: (_) => child,
      );
    },
    initialRoute: '/',
  );
}

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Taps the camera button and waits for the pick to land. `_onPickImage`
/// does a genuine `XFile.readAsBytes()` — real OS-driven I/O whose
/// completion doesn't reliably interleave with plain `tester.pump()`
/// calls, which only drain Flutter-scheduled frame work, not arbitrary
/// real-world async completions. Wrapping the tap in `runAsync` lets the
/// real Future actually resolve; the trailing `pump()` then flushes the
/// resulting setState into the tree.
Future<void> _tapCameraAndWait(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.tap(find.text(S.current.magicCameraButton));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();
  await tester.pump();
}

/// Taps Analyze and waits for it to finish — pumpAndSettle never settles
/// while the Analyze button's indeterminate CircularProgressIndicator is
/// still animating.
Future<void> _tapAnalyzeAndWait(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.tap(find.text(S.current.scanLabelAnalyzeButton));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();
  await tester.pump();
}

// A minimal valid 1x1 transparent PNG — Image.memory needs real decodable
// bytes; garbage bytes make the codec error in a way that keeps
// pumpAndSettle from ever settling under the test binding.
final _tinyPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

void main() {
  late File tempImageFile;

  setUp(() {
    tempImageFile = File(
      '${Directory.systemTemp.path}/scan_label_screen_test_${DateTime.now().microsecondsSinceEpoch}.jpg',
    )..writeAsBytesSync(_tinyPngBytes);
    ImagePickerPlatform.instance = _FakeImagePickerPlatform(
      tempImageFile.path,
    );
  });

  tearDown(() {
    // Windows can still hold a lock on the file via the image cache when
    // the test ends — deletion is best-effort cleanup, not a correctness
    // check, so a failure here must not fail the test.
    try {
      if (tempImageFile.existsSync()) tempImageFile.deleteSync();
    } catch (_) {}
  });

  group('ScanLabelScreen', () {
    testWidgets('Analyze is disabled until a photo is picked', (
      tester,
    ) async {
      _useTallViewport(tester);
      final config = ConfigEntity(
        false,
        false,
        false,
        AppThemeEntity.dark,
        openRouterApiKey: 'sk-or-test',
        openRouterModelId: 'openai/gpt-4o',
      );
      final pushed = <Object?>[];
      await tester.pumpWidget(
        _wrap(
          ScanLabelScreen(
            getConfigUsecase: _FakeGetConfigUsecase(config),
            analyzeLabelWithAiUsecase: _FakeAnalyzeLabelWithAiUsecase(),
          ),
          pushedEditMealArgs: pushed,
        ),
      );
      await tester.pumpAndSettle();

      final analyzeButtonBefore = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(analyzeButtonBefore.onPressed, isNull);

      await _tapCameraAndWait(tester);

      final analyzeButtonAfter = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(analyzeButtonAfter.onPressed, isNotNull);
    });

    testWidgets(
      'a successful analysis navigates to EditMealScreen with a custom '
      'MealEntity keyed by the scanned barcode',
      (tester) async {
        _useTallViewport(tester);
        final config = ConfigEntity(
          false,
          false,
          false,
          AppThemeEntity.dark,
          openRouterApiKey: 'sk-or-test',
          openRouterModelId: 'openai/gpt-4o',
        );
        final analyzeUsecase = _FakeAnalyzeLabelWithAiUsecase()
          ..result = const ScannedLabelEntity(
            name: 'Greek Yoghurt',
            brand: 'Fage',
            servingSize: '170g',
            kcal100: 97,
            carbs100: 4,
            fat100: 5,
            protein100: 9,
            sugars100: 4,
            saturatedFat100: 3.3,
            fiber100: 0,
            sodiumMg100: 45,
          );
        final pushed = <Object?>[];

        await tester.pumpWidget(
          _wrap(
            ScanLabelScreen(
              getConfigUsecase: _FakeGetConfigUsecase(config),
              analyzeLabelWithAiUsecase: analyzeUsecase,
            ),
            pushedEditMealArgs: pushed,
          ),
        );
        await tester.pumpAndSettle();

        await _tapCameraAndWait(tester);
        await _tapAnalyzeAndWait(tester);

        expect(find.text('edit-meal'), findsOneWidget);
        expect(pushed, hasLength(1));
        final editArgs = pushed.single as EditMealScreenArguments;
        expect(editArgs.day, DateTime(2026, 1, 1));
        expect(editArgs.intakeTypeEntity, IntakeTypeEntity.breakfast);
        final meal = editArgs.mealEntity;
        expect(meal.code, '5449000000996');
        expect(meal.name, 'Greek Yoghurt');
        expect(meal.brands, 'Fage');
        expect(meal.source, MealSourceEntity.custom);
        expect(meal.nutriments.energyKcal100, 97);
        expect(meal.nutriments.carbohydrates100, 4);
        expect(meal.nutriments.sodium100, 45);
      },
    );

    testWidgets('shows an error when no API key is configured', (
      tester,
    ) async {
      _useTallViewport(tester);
      final config = const ConfigEntity(false, false, false, AppThemeEntity.dark);
      final pushed = <Object?>[];

      await tester.pumpWidget(
        _wrap(
          ScanLabelScreen(
            getConfigUsecase: _FakeGetConfigUsecase(config),
            analyzeLabelWithAiUsecase: _FakeAnalyzeLabelWithAiUsecase(),
          ),
          pushedEditMealArgs: pushed,
        ),
      );
      await tester.pumpAndSettle();

      await _tapCameraAndWait(tester);
      await tester.tap(find.text(S.current.scanLabelAnalyzeButton));
      await tester.pumpAndSettle();

      expect(find.text(S.current.magicNoApiKeyError), findsOneWidget);
      expect(pushed, isEmpty);
    });

    testWidgets('shows an error when analysis throws', (tester) async {
      _useTallViewport(tester);
      final config = ConfigEntity(
        false,
        false,
        false,
        AppThemeEntity.dark,
        openRouterApiKey: 'sk-or-test',
        openRouterModelId: 'openai/gpt-4o',
      );
      final analyzeUsecase = _FakeAnalyzeLabelWithAiUsecase()
        ..error = const LabelAnalysisException('boom');
      final pushed = <Object?>[];

      await tester.pumpWidget(
        _wrap(
          ScanLabelScreen(
            getConfigUsecase: _FakeGetConfigUsecase(config),
            analyzeLabelWithAiUsecase: analyzeUsecase,
          ),
          pushedEditMealArgs: pushed,
        ),
      );
      await tester.pumpAndSettle();

      await _tapCameraAndWait(tester);
      await _tapAnalyzeAndWait(tester);

      expect(find.text(S.current.scanLabelAnalysisFailedError), findsOneWidget);
      expect(pushed, isEmpty);
    });
  });
}
