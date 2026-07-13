import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/domain/entity/body_measurement_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_body_measurement_usecase.dart';
import 'package:opennutritracker/features/profile/presentation/progress_photo_compare_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async => '.';
}

class _FakeGetBodyMeasurementUsecase extends Fake
    implements GetBodyMeasurementUsecase {
  final List<BodyMeasurementEntity> _entries;
  _FakeGetBodyMeasurementUsecase(this._entries);

  @override
  Future<List<BodyMeasurementEntity>> getAllEntries() async =>
      List.of(_entries);
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
    home: child,
  );
}

void main() {
  setUp(() {
    PathProviderPlatform.instance = _FakePathProvider();
  });

  group('ProgressPhotoCompareScreen', () {
    testWidgets(
      'shows the empty-state copy when fewer than two entries have a '
      'photo for the selected angle',
      (tester) async {
        final entries = [
          BodyMeasurementEntity(
            date: DateTime(2026, 7, 1),
            frontPhotoPath: 'progress_photos/2026-07-01_front.webp',
          ),
        ];

        await tester.pumpWidget(
          _wrap(
            ProgressPhotoCompareScreen(
              getUsecase: _FakeGetBodyMeasurementUsecase(entries),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(S.current.bodyMeasurementsCompareEmptyLabel),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'lets the user pick a before and after date, then reveals Share',
      (tester) async {
        final entries = [
          BodyMeasurementEntity(
            date: DateTime(2026, 7, 1),
            frontPhotoPath: 'progress_photos/2026-07-01_front.webp',
          ),
          BodyMeasurementEntity(
            date: DateTime(2026, 7, 15),
            frontPhotoPath: 'progress_photos/2026-07-15_front.webp',
          ),
        ];

        await tester.pumpWidget(
          _wrap(
            ProgressPhotoCompareScreen(
              getUsecase: _FakeGetBodyMeasurementUsecase(entries),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // No share action until both dates are picked.
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.identifier == 'compare-share',
          ),
          findsNothing,
        );

        final beforeButton = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.identifier == 'compare-before-button',
        );
        await tester.tap(beforeButton);
        await tester.pumpAndSettle();

        final localeTag = 'en_US';
        final julFirst = DateFormat.yMMMd(localeTag).format(DateTime(2026, 7, 1));
        await tester.tap(find.text(julFirst).last);
        await tester.pumpAndSettle();

        final afterButton = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.identifier == 'compare-after-button',
        );
        await tester.tap(afterButton);
        await tester.pumpAndSettle();

        final julFifteenth =
            DateFormat.yMMMd(localeTag).format(DateTime(2026, 7, 15));
        await tester.tap(find.text(julFifteenth).last);
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.identifier == 'compare-share',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'switching the angle chip clears the before/after selection',
      (tester) async {
        final entries = [
          BodyMeasurementEntity(
            date: DateTime(2026, 7, 1),
            frontPhotoPath: 'progress_photos/2026-07-01_front.webp',
            sidePhotoPath: 'progress_photos/2026-07-01_side.webp',
          ),
          BodyMeasurementEntity(
            date: DateTime(2026, 7, 15),
            frontPhotoPath: 'progress_photos/2026-07-15_front.webp',
            sidePhotoPath: 'progress_photos/2026-07-15_side.webp',
          ),
        ];

        await tester.pumpWidget(
          _wrap(
            ProgressPhotoCompareScreen(
              getUsecase: _FakeGetBodyMeasurementUsecase(entries),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final beforeButton = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.identifier == 'compare-before-button',
        );
        await tester.tap(beforeButton);
        await tester.pumpAndSettle();
        const localeTag = 'en_US';
        final julFirst = DateFormat.yMMMd(localeTag).format(DateTime(2026, 7, 1));
        await tester.tap(find.text(julFirst).last);
        await tester.pumpAndSettle();

        // Before date now shows on the button instead of the placeholder.
        expect(find.text('—'), findsOneWidget);

        await tester.tap(find.text(S.current.bodyMeasurementsPhotoSideLabel));
        await tester.pumpAndSettle();

        // Switching angles resets both slots back to the placeholder.
        expect(find.text('—'), findsNWidgets(2));
      },
    );
  });
}
