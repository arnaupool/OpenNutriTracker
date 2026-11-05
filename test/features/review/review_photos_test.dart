import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/domain/entity/body_measurement_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_body_measurement_usecase.dart';
import 'package:opennutritracker/features/profile/presentation/body_measurements_screen.dart';
import 'package:opennutritracker/features/review/domain/review_photos.dart';
import 'package:opennutritracker/features/review/presentation/review_photos_tab.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async => '.';
}

class _FakeGetBodyMeasurementUsecase extends Fake implements GetBodyMeasurementUsecase {
  final List<BodyMeasurementEntity> _entries;
  _FakeGetBodyMeasurementUsecase(this._entries);

  @override
  Future<List<BodyMeasurementEntity>> getAllEntries() async => List.of(_entries);
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
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );
}

String _fmt(DateTime d) => DateFormat.yMMMd('en').format(d);

void main() {
  final entries = [
    BodyMeasurementEntity(date: DateTime(2026, 3, 1), frontPhotoPath: 'f1', sidePhotoPath: 's1'),
    BodyMeasurementEntity(date: DateTime(2026, 5, 1), frontPhotoPath: 'f2'),
    BodyMeasurementEntity(date: DateTime(2026, 7, 1), frontPhotoPath: 'f3', sidePhotoPath: 's3'),
    BodyMeasurementEntity(date: DateTime(2026, 6, 1)),
  ];

  group('ReviewPhotos', () {
    test('forAngle keeps entries with a photo, newest first', () {
      final front = ReviewPhotos.forAngle(entries, ProgressPhotoAngle.front.pathFor);
      expect(front.map((p) => p.date), [DateTime(2026, 7, 1), DateTime(2026, 5, 1), DateTime(2026, 3, 1)]);
      final back = ReviewPhotos.forAngle(entries, ProgressPhotoAngle.back.pathFor);
      expect(back, isEmpty);
    });

    test('defaultPair is oldest then newest, null below two photos', () {
      final front = ReviewPhotos.forAngle(entries, ProgressPhotoAngle.front.pathFor);
      final pair = ReviewPhotos.defaultPair(front)!;
      expect(pair.$1.date, DateTime(2026, 3, 1));
      expect(pair.$2.date, DateTime(2026, 7, 1));
      expect(ReviewPhotos.defaultPair(front.take(1).toList()), isNull);
      expect(ReviewPhotos.defaultPair(const []), isNull);
    });

    test('daysBetween counts calendar days', () {
      expect(
        ReviewPhotos.daysBetween(ReviewPhoto(DateTime(2026, 3, 1), 'a'), ReviewPhoto(DateTime(2026, 7, 5), 'b')),
        126,
      );
    });
  });

  group('ReviewPhotosTab', () {
    setUp(() {
      PathProviderPlatform.instance = _FakePathProvider();
    });

    Future<void> pump(WidgetTester tester, List<BodyMeasurementEntity> data) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(ReviewPhotosTab(getUsecase: _FakeGetBodyMeasurementUsecase(data))));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('defaults to oldest as before and newest as after', (tester) async {
      await pump(tester, entries);
      expect(tester.widget<Text>(find.byKey(const Key('review-photos-before-date'))).data, _fmt(DateTime(2026, 3, 1)));
      expect(tester.widget<Text>(find.byKey(const Key('review-photos-after-date'))).data, _fmt(DateTime(2026, 7, 1)));
      expect(find.text('Before'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
    });

    testWidgets('switching angle changes the photos listed', (tester) async {
      await pump(tester, entries);
      await tester.tap(find.text('Side'));
      await tester.pump();
      // Side photos exist on Mar 1 and Jul 1 only; open the picker for "after".
      await tester.tap(find.text('Change').last);
      await tester.pumpAndSettle();
      expect(find.text(_fmt(DateTime(2026, 5, 1))), findsNothing);
      expect(find.text(_fmt(DateTime(2026, 3, 1))), findsWidgets);
      expect(find.text(_fmt(DateTime(2026, 7, 1))), findsWidgets);
    });

    testWidgets('picking a photo from the sheet sets that side', (tester) async {
      await pump(tester, entries);
      await tester.tap(find.text('Change').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_fmt(DateTime(2026, 5, 1))).last);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('review-photos-after-date'))).data, _fmt(DateTime(2026, 5, 1)));
    });

    testWidgets('shows the empty state when the angle has no photos', (tester) async {
      await pump(tester, entries);
      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(find.text(S.current.reviewPhotosEmpty), findsOneWidget);
      expect(find.text('Before'), findsNothing);
    });

    testWidgets('with a single photo shows it and asks for a second one', (tester) async {
      await pump(tester, [BodyMeasurementEntity(date: DateTime(2026, 3, 1), frontPhotoPath: 'f1')]);
      expect(find.text(S.current.reviewPhotosNeedSecond), findsOneWidget);
      expect(find.text(_fmt(DateTime(2026, 3, 1))), findsOneWidget);
    });
  });
}
