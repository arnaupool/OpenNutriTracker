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
  });
}
