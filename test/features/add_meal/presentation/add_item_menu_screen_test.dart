import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_item_menu_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _SpyNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

Widget _wrap(_SpyNavigatorObserver observer) {
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
    navigatorObservers: [observer],
    onGenerateRoute: (settings) {
      if (settings.name == '/') {
        return MaterialPageRoute(
          settings: RouteSettings(name: '/', arguments: args),
          builder: (_) => const AddItemMenuScreen(),
        );
      }
      // Every destination route just renders a placeholder — this test only
      // cares about which route name and arguments got pushed.
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => Scaffold(body: Text('dest:${settings.name}')),
      );
    },
    initialRoute: '/',
  );
}

void main() {
  group('AddItemMenuScreen', () {
    testWidgets('renders all 5 reference menu options', (tester) async {
      await tester.pumpWidget(_wrap(_SpyNavigatorObserver()));
      await tester.pumpAndSettle();

      expect(find.text(S.current.addItemMenuMagicLabel), findsOneWidget);
      expect(find.text(S.current.addItemMenuSearchLabel), findsOneWidget);
      expect(find.text(S.current.addItemMenuScanProductLabel), findsOneWidget);
      expect(find.text(S.current.addItemMenuRecentlyLabel), findsOneWidget);
      expect(find.text(S.current.addItemMenuPresetsLabel), findsOneWidget);
    });

    testWidgets('tapping Magic pushes the magic route with the same args', (
      tester,
    ) async {
      final observer = _SpyNavigatorObserver();
      await tester.pumpWidget(_wrap(observer));
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.addItemMenuMagicLabel));
      await tester.pumpAndSettle();

      final pushed = observer.pushed.last.settings;
      expect(pushed.name, NavigationOptions.magicRoute);
      expect(
        (pushed.arguments as AddMealScreenArguments).mealType,
        AddMealType.breakfastType,
      );
    });

    testWidgets('tapping Search pushes the existing addMeal search route', (
      tester,
    ) async {
      final observer = _SpyNavigatorObserver();
      await tester.pumpWidget(_wrap(observer));
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.addItemMenuSearchLabel));
      await tester.pumpAndSettle();

      expect(
        observer.pushed.last.settings.name,
        NavigationOptions.addMealRoute,
      );
    });

    testWidgets(
      'tapping Scan Product pushes the scanner route with barcode args',
      (tester) async {
        final observer = _SpyNavigatorObserver();
        await tester.pumpWidget(_wrap(observer));
        await tester.pumpAndSettle();

        await tester.tap(find.text(S.current.addItemMenuScanProductLabel));
        await tester.pumpAndSettle();

        final pushed = observer.pushed.last.settings;
        expect(pushed.name, NavigationOptions.scannerRoute);
        expect(
          (pushed.arguments as ScannerScreenArguments).intakeTypeEntity,
          IntakeTypeEntity.breakfast,
        );
      },
    );

    testWidgets('tapping Recently pushes the recently route', (tester) async {
      final observer = _SpyNavigatorObserver();
      await tester.pumpWidget(_wrap(observer));
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.addItemMenuRecentlyLabel));
      await tester.pumpAndSettle();

      expect(
        observer.pushed.last.settings.name,
        NavigationOptions.recentlyRoute,
      );
    });

    testWidgets('tapping Presets pushes the presets route', (tester) async {
      final observer = _SpyNavigatorObserver();
      await tester.pumpWidget(_wrap(observer));
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.addItemMenuPresetsLabel));
      await tester.pumpAndSettle();

      expect(
        observer.pushed.last.settings.name,
        NavigationOptions.presetsRoute,
      );
    });
  });
}
