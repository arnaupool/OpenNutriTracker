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
import 'package:opennutritracker/core/domain/usecase/get_body_measurement_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/features/home/presentation/widgets/body_metrics_summary_card.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _FakeGetBodyMeasurementUsecase extends Fake
    implements GetBodyMeasurementUsecase {
  final List<BodyMeasurementEntity> _entries;
  _FakeGetBodyMeasurementUsecase(this._entries);

  @override
  Future<List<BodyMeasurementEntity>> getAllEntries() async =>
      List.of(_entries);
}

class _FakeGetUserUsecase extends Fake implements GetUserUsecase {
  final UserEntity _user;
  _FakeGetUserUsecase(this._user);

  @override
  Future<UserEntity> getUserData() async => _user;
}

class _FakeConfigRepository extends Fake implements ConfigRepository {
  final bool _usesImperialUnits;
  _FakeConfigRepository({bool usesImperialUnits = false})
    : _usesImperialUnits = usesImperialUnits;

  @override
  Future<ConfigEntity> getConfig() async {
    return ConfigEntity(
      false,
      false,
      false,
      AppThemeEntity.dark,
      usesImperialUnits: _usesImperialUnits,
    );
  }
}

UserEntity _buildUser({double heightCM = 180}) {
  return UserEntity(
    birthday: DateTime(1990, 1, 1),
    heightCM: heightCM,
    weightKG: 84,
    gender: UserGenderEntity.male,
    goal: UserWeightGoalEntity.loseWeight,
    pal: UserPALEntity.lowActive,
    weeklyWeightGoalKg: -0.5,
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

Widget _buildCard({
  required List<BodyMeasurementEntity> entries,
  UserEntity? user,
}) {
  return BodyMetricsSummaryCard(
    getBodyMeasurementUsecase: _FakeGetBodyMeasurementUsecase(entries),
    getUserUsecase: _FakeGetUserUsecase(user ?? _buildUser()),
    configRepository: _FakeConfigRepository(),
  );
}

void main() {
  group('BodyMetricsSummaryCard', () {
    testWidgets('shows the insufficient-data message with no entries', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_buildCard(entries: const [])));
      await tester.pumpAndSettle();

      expect(
        find.text(S.current.homeBodyMetricsInsufficientData),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows waist, waist-to-height, and waist-to-hip from the latest '
      'entry (sorted by date, not insertion order)',
      (tester) async {
        final older = BodyMeasurementEntity(
          date: DateTime(2026, 1, 1),
          waistCm: 100,
          hipsCm: 100,
        );
        final latest = BodyMeasurementEntity(
          date: DateTime(2026, 6, 1),
          waistCm: 90,
          hipsCm: 100,
        );

        await tester.pumpWidget(
          _wrap(
            _buildCard(
              entries: [older, latest],
              user: _buildUser(heightCM: 180),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(S.current.homeBodyMetricsInsufficientData),
          findsNothing,
        );
        // Latest waist (90 cm), not the older entry's (100 cm).
        expect(find.text('90.0 ${S.current.cmLabel}'), findsOneWidget);
        // waist-to-height = 90 / 180 = 0.50, waist-to-hip = 90 / 100 = 0.90.
        expect(find.text('0.50'), findsOneWidget);
        expect(find.text('0.90'), findsOneWidget);
      },
    );

    testWidgets('shows a dash for a ratio when its input is missing', (
      tester,
    ) async {
      final entry = BodyMeasurementEntity(date: DateTime(2026, 6, 1), waistCm: 90);

      await tester.pumpWidget(
        _wrap(_buildCard(entries: [entry], user: _buildUser())),
      );
      await tester.pumpAndSettle();

      expect(find.text('—'), findsOneWidget);
    });
  });
}
