import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/body_measurement_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_body_measurement_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/delete_body_measurement_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_body_measurement_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/features/profile/presentation/body_measurements_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Stub so `UserImageStorage.absolutePath` (used by the entry thumbnails
/// and the photo pickers) resolves against a real temp dir instead of
/// throwing `MissingPluginException` in the test binding.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

class _FakeGetBodyMeasurementUsecase extends Fake
    implements GetBodyMeasurementUsecase {
  final List<BodyMeasurementEntity> _entries;
  _FakeGetBodyMeasurementUsecase(this._entries);

  @override
  Future<List<BodyMeasurementEntity>> getAllEntries() async =>
      List.of(_entries);
}

class _FakeAddBodyMeasurementUsecase extends Fake
    implements AddBodyMeasurementUsecase {
  BodyMeasurementEntity? lastAdded;

  @override
  Future<void> addEntry(BodyMeasurementEntity entry) async {
    lastAdded = entry;
  }
}

class _FakeDeleteBodyMeasurementUsecase extends Fake
    implements DeleteBodyMeasurementUsecase {
  DateTime? lastDeleted;

  @override
  Future<void> deleteEntry(DateTime date) async {
    lastDeleted = date;
  }
}

class _FakeConfigRepository extends Fake implements ConfigRepository {
  final bool usesImperialUnits;
  _FakeConfigRepository({this.usesImperialUnits = false});

  @override
  Future<ConfigEntity> getConfig() async {
    return ConfigEntity(false, false, usesImperialUnits, AppThemeEntity.dark);
  }
}

class _FakeGetUserUsecase extends Fake implements GetUserUsecase {
  final UserEntity user;
  _FakeGetUserUsecase(this.user);

  @override
  Future<UserEntity> getUserData() async => user;
}

UserEntity _buildUser({double heightCM = 180}) {
  return UserEntity(
    birthday: DateTime(1990, 1, 1),
    heightCM: heightCM,
    weightKG: 80,
    gender: UserGenderEntity.male,
    goal: UserWeightGoalEntity.loseWeight,
    pal: UserPALEntity.lowActive,
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

Widget _buildScreen({
  required List<BodyMeasurementEntity> entries,
  AddBodyMeasurementUsecase? addUsecase,
  DeleteBodyMeasurementUsecase? deleteUsecase,
  bool usesImperialUnits = false,
  UserEntity? user,
}) {
  return BodyMeasurementsScreen(
    getUsecase: _FakeGetBodyMeasurementUsecase(entries),
    addUsecase: addUsecase ?? _FakeAddBodyMeasurementUsecase(),
    deleteUsecase: deleteUsecase ?? _FakeDeleteBodyMeasurementUsecase(),
    configRepository: _FakeConfigRepository(
      usesImperialUnits: usesImperialUnits,
    ),
    getUserUsecase: _FakeGetUserUsecase(user ?? _buildUser()),
  );
}

void main() {
  late Directory tempDocsDir;

  setUp(() async {
    tempDocsDir = await Directory.systemTemp.createTemp('ont_bm_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDocsDir.path);
  });

  tearDown(() async {
    if (await tempDocsDir.exists()) {
      await tempDocsDir.delete(recursive: true);
    }
  });

  group('BodyMeasurementsScreen', () {
    testWidgets('shows the empty-state copy with no entries', (tester) async {
      await tester.pumpWidget(_wrap(_buildScreen(entries: const [])));
      await tester.pumpAndSettle();

      expect(find.text(S.current.bodyMeasurementsNoEntries), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets(
      'defaults to the Waist metric and shows the chart empty-state with '
      'only one waist reading',
      (tester) async {
        final entries = [
          BodyMeasurementEntity(date: DateTime(2026, 7, 1), waistCm: 82.0),
        ];

        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_wrap(_buildScreen(entries: entries)));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('bodyMeasurementsChartEmptyState')),
          findsOneWidget,
        );
        expect(find.byType(LineChart), findsNothing);
      },
    );

    testWidgets('renders the trend chart once a metric has two readings', (
      tester,
    ) async {
      final entries = [
        BodyMeasurementEntity(date: DateTime(2026, 7, 1), waistCm: 83.0),
        BodyMeasurementEntity(date: DateTime(2026, 7, 8), waistCm: 82.0),
      ];

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(_buildScreen(entries: entries)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bodyMeasurementsChart')), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets(
      'switching the metric chip re-plots a different measurement series',
      (tester) async {
        final entries = [
          BodyMeasurementEntity(
            date: DateTime(2026, 7, 1),
            waistCm: 83.0,
            neckCm: 38.0,
          ),
          BodyMeasurementEntity(
            date: DateTime(2026, 7, 8),
            waistCm: 82.0,
            // Only one neck reading -> switching to Neck should show the
            // chart empty-state instead of a line.
          ),
        ];

        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_wrap(_buildScreen(entries: entries)));
        await tester.pumpAndSettle();

        expect(find.byType(LineChart), findsOneWidget);

        await tester.tap(find.text(S.current.bodyMeasurementsNeckLabel));
        await tester.pumpAndSettle();

        expect(find.byType(LineChart), findsNothing);
        expect(
          find.byKey(const Key('bodyMeasurementsChartEmptyState')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'computes waist-to-height and waist-to-hip from the latest entry, '
      'and shows a dash when a ratio cannot be computed',
      (tester) async {
        final entries = [
          BodyMeasurementEntity(
            date: DateTime(2026, 7, 1),
            waistCm: 90.0,
            // No hips logged -> waist-to-hip should read as "—".
          ),
        ];

        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Height 180cm, waist 90cm -> waist-to-height ratio 0.50.
        await tester.pumpWidget(
          _wrap(
            _buildScreen(entries: entries, user: _buildUser(heightCM: 180)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('0.50'), findsOneWidget);
        expect(find.text('—'), findsOneWidget);
      },
    );

    testWidgets(
      'Add entry parses only the filled-in fields and leaves the rest null',
      (tester) async {
        final fakeAdd = _FakeAddBodyMeasurementUsecase();

        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrap(_buildScreen(entries: const [], addUsecase: fakeAdd)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        final waistField = find.descendant(
          of: find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.identifier == 'body-measurements-field-waist',
          ),
          matching: find.byType(TextField),
        );
        await tester.enterText(waistField, '81.5');

        final hipsField = find.descendant(
          of: find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.identifier == 'body-measurements-field-hips',
          ),
          matching: find.byType(TextField),
        );
        await tester.enterText(hipsField, '97');

        await tester.tap(find.text(S.current.dialogOKLabel));
        await tester.pumpAndSettle();

        expect(fakeAdd.lastAdded?.waistCm, equals(81.5));
        expect(fakeAdd.lastAdded?.hipsCm, equals(97.0));
        expect(fakeAdd.lastAdded?.neckCm, isNull);
        expect(fakeAdd.lastAdded?.chestCm, isNull);
      },
    );

    testWidgets('deleting an entry calls the delete usecase with its date', (
      tester,
    ) async {
      final fakeDelete = _FakeDeleteBodyMeasurementUsecase();
      final entries = [
        BodyMeasurementEntity(date: DateTime(2026, 7, 1), waistCm: 83.0),
      ];

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(_buildScreen(entries: entries, deleteUsecase: fakeDelete)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(fakeDelete.lastDeleted, equals(DateTime(2026, 7, 1)));
    });

    testWidgets(
      'Add entry shows a Front/Side/Back photo picker for each angle',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_wrap(_buildScreen(entries: const [])));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        expect(
          find.text(S.current.bodyMeasurementsPhotoFrontLabel),
          findsOneWidget,
        );
        expect(
          find.text(S.current.bodyMeasurementsPhotoSideLabel),
          findsOneWidget,
        );
        expect(
          find.text(S.current.bodyMeasurementsPhotoBackLabel),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.identifier ==
                    'body-measurements-photo-picker-front',
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.identifier ==
                    'body-measurements-photo-picker-side',
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.identifier ==
                    'body-measurements-photo-picker-back',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'hides the Compare action when no entry has a photo',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final noPhotoEntries = [
          BodyMeasurementEntity(date: DateTime(2026, 7, 1), waistCm: 83.0),
        ];
        await tester.pumpWidget(_wrap(_buildScreen(entries: noPhotoEntries)));
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.identifier == 'body-measurements-compare',
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'shows the Compare action once an entry has a photo, and tapping '
      'it opens the compare screen',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final withPhotoEntries = [
          BodyMeasurementEntity(
            date: DateTime(2026, 7, 1),
            waistCm: 83.0,
            frontPhotoPath: 'progress_photos/2026-07-01_front.webp',
          ),
        ];
        await tester.pumpWidget(_wrap(_buildScreen(entries: withPhotoEntries)));
        await tester.pumpAndSettle();

        final compareButton = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.identifier == 'body-measurements-compare',
        );
        expect(compareButton, findsOneWidget);

        await tester.tap(compareButton);
        await tester.pumpAndSettle();

        expect(
          find.text(S.current.bodyMeasurementsCompareTitle),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'an entry with a logged photo renders without throwing, even when '
      'the underlying file is missing',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final entries = [
          BodyMeasurementEntity(
            date: DateTime(2026, 7, 1),
            waistCm: 83.0,
            frontPhotoPath: 'progress_photos/2026-07-01_front.webp',
          ),
        ];
        await tester.pumpWidget(_wrap(_buildScreen(entries: entries)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tapping an entry thumbnail opens the full-screen photo viewer',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const relativePath = 'progress_photos/2026-07-01_front.webp';
        final entries = [
          BodyMeasurementEntity(
            date: DateTime(2026, 7, 1),
            waistCm: 83.0,
            frontPhotoPath: relativePath,
          ),
        ];
        // A real (if tiny/invalid) file must exist for imageProvider() to
        // resolve to a FileImage instead of null — it now checks existence
        // upfront rather than deferring to Image's own errorBuilder.
        final photoFile = File('${tempDocsDir.path}/$relativePath');
        await photoFile.create(recursive: true);
        await photoFile.writeAsBytes([1, 2, 3, 4]);

        await tester.pumpWidget(_wrap(_buildScreen(entries: entries)));
        await tester.pumpAndSettle();

        final thumbnailImage = find.descendant(
          of: find.byType(ListTile),
          matching: find.byType(Image),
        );
        expect(thumbnailImage, findsOneWidget);

        // The thumbnail's own GestureDetector is the nearest ancestor; a
        // second, further one belongs to the enclosing Scrollable.
        final thumbnailGesture = find
            .ancestor(
              of: thumbnailImage,
              matching: find.byType(GestureDetector),
            )
            .first;

        await tester.tap(thumbnailGesture);
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.identifier == 'progress-photo-viewer',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(S.current.bodyMeasurementsPhotoFrontLabel),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
