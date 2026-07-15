import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/scanner/data/product_not_found_exception.dart';
import 'package:opennutritracker/features/scanner/domain/usecase/search_product_by_barcode_usecase.dart';
import 'package:opennutritracker/features/scanner/presentation/scan_label_screen.dart';
import 'package:opennutritracker/features/scanner/presentation/scanner_bloc.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// FR-04 regression coverage: a genuine "not found" offers the AI-label
/// fallback instead of the plain Retry-only ErrorDialog dead end, but only
/// in the normal logging flow — pick mode has nowhere to send day/intake
/// type, so it keeps the existing dialog.
class _FakeSearchUseCase implements SearchProductByBarcodeUseCase {
  final Object error;
  _FakeSearchUseCase(this.error);

  @override
  Future<MealEntity> searchProductByBarcode(String barcode) async {
    throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetConfigUsecase implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(true, true, false, AppThemeEntity.system);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

Widget _wrap(
  Widget home, {
  required List<Object?> pushedScanLabelArgs,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    onGenerateRoute: (settings) {
      if (settings.name == NavigationOptions.scanLabelRoute) {
        pushedScanLabelArgs.add(settings.arguments);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('scan-label')),
        );
      }
      return null;
    },
    home: home,
  );
}

void main() {
  final getIt = GetIt.instance;

  tearDown(() async {
    if (getIt.isRegistered<ScannerBloc>()) {
      await getIt.unregister<ScannerBloc>();
    }
  });

  group('ScannerScreen not-found fallback (logging flow)', () {
    setUp(() {
      getIt.registerFactory<ScannerBloc>(
        () => ScannerBloc(
          _FakeSearchUseCase(ProductNotFoundException()),
          _FakeGetConfigUsecase(),
        ),
      );
    });

    testWidgets('offers "Photograph label" instead of the plain error dialog', (
      tester,
    ) async {
      final pushed = <Object?>[];
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      settings: RouteSettings(
                        arguments: ScannerScreenArguments(
                          DateTime(2026, 5, 21),
                          IntakeTypeEntity.breakfast,
                          initialBarcode: '0000000000000',
                        ),
                      ),
                      builder: (_) => const ScannerScreen(),
                    ),
                  ),
                  child: const Text('open scanner'),
                ),
              ),
            ),
          ),
          pushedScanLabelArgs: pushed,
        ),
      );

      await tester.tap(find.text('open scanner'));
      await tester.pumpAndSettle();

      expect(find.text(S.current.scannerPhotographLabelButton), findsOneWidget);
      // The fallback still offers a way back to the camera underneath the
      // primary CTA — re-submitting the identical barcode would just fail
      // identically every time (a 404 is deterministic), so this is "Scan
      // again" rather than the network-error "Retry" used elsewhere.
      expect(find.text(S.current.scannerScanAgainButton), findsOneWidget);

      await tester.tap(find.text(S.current.scannerPhotographLabelButton));
      await tester.pumpAndSettle();

      expect(find.text('scan-label'), findsOneWidget);
      expect(pushed, hasLength(1));
      final args = pushed.single as ScanLabelScreenArguments;
      expect(args.barcode, '0000000000000');
      expect(args.day, DateTime(2026, 5, 21));
      expect(args.intakeTypeEntity, IntakeTypeEntity.breakfast);
    });
  });

  group('ScannerScreen not-found fallback (pick mode)', () {
    setUp(() {
      getIt.registerFactory<ScannerBloc>(
        () => ScannerBloc(
          _FakeSearchUseCase(ProductNotFoundException()),
          _FakeGetConfigUsecase(),
        ),
      );
    });

    testWidgets('keeps the plain error dialog — nowhere to send the fallback', (
      tester,
    ) async {
      final pushed = <Object?>[];
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      settings: RouteSettings(
                        arguments: ScannerScreenArguments.pick(
                          initialBarcode: '0000000000000',
                        ),
                      ),
                      builder: (_) => const ScannerScreen(),
                    ),
                  ),
                  child: const Text('open scanner'),
                ),
              ),
            ),
          ),
          pushedScanLabelArgs: pushed,
        ),
      );

      await tester.tap(find.text('open scanner'));
      await tester.pumpAndSettle();

      expect(find.text(S.current.errorProductNotFound), findsOneWidget);
      expect(find.text(S.current.scannerPhotographLabelButton), findsNothing);
    });
  });

  group('ScannerScreen generic error (logging flow)', () {
    setUp(() {
      getIt.registerFactory<ScannerBloc>(
        () => ScannerBloc(
          _FakeSearchUseCase(Exception('network down')),
          _FakeGetConfigUsecase(),
        ),
      );
    });

    testWidgets('keeps the plain error dialog for a non-404 failure', (
      tester,
    ) async {
      final pushed = <Object?>[];
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      settings: RouteSettings(
                        arguments: ScannerScreenArguments(
                          DateTime(2026, 5, 21),
                          IntakeTypeEntity.breakfast,
                          initialBarcode: '0000000000000',
                        ),
                      ),
                      builder: (_) => const ScannerScreen(),
                    ),
                  ),
                  child: const Text('open scanner'),
                ),
              ),
            ),
          ),
          pushedScanLabelArgs: pushed,
        ),
      );

      await tester.tap(find.text('open scanner'));
      await tester.pumpAndSettle();

      expect(find.text(S.current.errorFetchingProductData), findsOneWidget);
      expect(find.text(S.current.scannerPhotographLabelButton), findsNothing);
    });
  });
}
