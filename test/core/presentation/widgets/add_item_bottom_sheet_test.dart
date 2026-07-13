import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_weight_log_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/add_item_bottom_sheet.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _FakeGetUserUsecase extends Fake implements GetUserUsecase {
  UserEntity user;
  _FakeGetUserUsecase(this.user);

  @override
  Future<UserEntity> getUserData() async => user;
}

class _FakeConfigRepository extends Fake implements ConfigRepository {
  @override
  Future<ConfigEntity> getConfig() async {
    return ConfigEntity(false, false, false, AppThemeEntity.dark);
  }
}

class _FakeAddWeightLogUsecase extends Fake implements AddWeightLogUsecase {
  WeightLogEntity? lastEntry;

  @override
  Future<void> addEntry(WeightLogEntity entry) async {
    lastEntry = entry;
  }
}

class _FakeProfileBloc extends Fake implements ProfileBloc {
  UserEntity? lastUpdated;

  @override
  Future<void> updateUser(UserEntity userEntity) async {
    lastUpdated = userEntity;
  }
}

UserEntity _buildUser({double weightKG = 84.0}) {
  return UserEntity(
    birthday: DateTime(1990, 1, 1),
    heightCM: 178,
    weightKG: weightKG,
    gender: UserGenderEntity.male,
    goal: UserWeightGoalEntity.loseWeight,
    pal: UserPALEntity.lowActive,
  );
}

// #277: the Show Activity Tracking toggle in Settings has been wired to
// hide every activity-related surface in the app. AddItemBottomSheet is
// the FAB's add-something menu — when the toggle is off, the Activity
// row at the top should disappear so the meal options are all that's on
// offer. Locking the behaviour in here so a future refactor that drops
// the conditional or its default trips the test instead of slipping past
// review.

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [S.delegate],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets(
    'shows the Activity tile when showActivityTracking is true',
    (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(
        AddItemBottomSheet(
          day: DateTime(2026, 1, 1),
          showActivityTracking: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(S.current.activityLabel), findsOneWidget);
      expect(find.text(S.current.weightLabel), findsOneWidget);
      expect(
        find.text(S.current.profileBodyMeasurementsTitle),
        findsOneWidget,
      );
      expect(find.text(S.current.breakfastLabel), findsOneWidget);
    },
  );

  testWidgets(
    'hides the Activity tile when showActivityTracking is false',
    (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(
        AddItemBottomSheet(
          day: DateTime(2026, 1, 1),
          showActivityTracking: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(S.current.activityLabel), findsNothing);
      // Weight and meal tiles still render so the sheet stays useful.
      expect(find.text(S.current.weightLabel), findsOneWidget);
      expect(find.text(S.current.breakfastLabel), findsOneWidget);
      expect(find.text(S.current.lunchLabel), findsOneWidget);
      expect(find.text(S.current.dinnerLabel), findsOneWidget);
      expect(find.text(S.current.snackLabel), findsOneWidget);
    },
  );

  testWidgets(
    'defaults to showing the Activity tile when the flag is omitted',
    (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(
        AddItemBottomSheet(day: DateTime(2026, 1, 1)),
      ));
      await tester.pumpAndSettle();

      expect(find.text(S.current.activityLabel), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Weight closes the sheet, opens the weight dialog, and '
    'confirming logs a dated entry + refreshes via ProfileBloc',
    (tester) async {
      final fakeGetUserUsecase = _FakeGetUserUsecase(_buildUser());
      final fakeConfigRepository = _FakeConfigRepository();
      final fakeAddWeightLogUsecase = _FakeAddWeightLogUsecase();
      final fakeProfileBloc = _FakeProfileBloc();

      // The default test surface is shorter than the sheet's 6 tiles +
      // dividers, which would overflow the (non-scrolling) Column.
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.delegate.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (context) => AddItemBottomSheet(
                      day: DateTime(2026, 7, 13),
                      getUserUsecase: fakeGetUserUsecase,
                      configRepository: fakeConfigRepository,
                      addWeightLogUsecase: fakeAddWeightLogUsecase,
                      profileBloc: fakeProfileBloc,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.weightLabel));
      await tester.pumpAndSettle();

      // The sheet is gone and the weight-entry dialog is up.
      expect(find.text(S.current.weightLabel), findsNothing);
      expect(find.text(S.current.selectWeightDialogLabel), findsOneWidget);

      await tester.tap(find.text(S.current.dialogOKLabel));
      await tester.pumpAndSettle();

      expect(fakeAddWeightLogUsecase.lastEntry?.date, DateTime(2026, 7, 13));
      expect(fakeAddWeightLogUsecase.lastEntry?.weightKg, closeTo(84.0, 0.01));
      expect(fakeProfileBloc.lastUpdated, isNotNull);
    },
  );

  testWidgets(
    'tapping Body Measurements closes the sheet and navigates to the '
    'Body Measurements route',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.delegate.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (context) =>
                        AddItemBottomSheet(day: DateTime(2026, 7, 13)),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          routes: {
            NavigationOptions.bodyMeasurementsRoute: (context) =>
                const Scaffold(body: Text('Body measurements screen')),
          },
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.profileBodyMeasurementsTitle));
      await tester.pumpAndSettle();

      expect(
        find.text(S.current.profileBodyMeasurementsTitle),
        findsNothing,
      );
      expect(find.text('Body measurements screen'), findsOneWidget);
    },
  );
}
