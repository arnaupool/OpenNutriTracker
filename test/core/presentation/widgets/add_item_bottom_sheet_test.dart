import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_weight_log_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/add_item_bottom_sheet.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
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

Widget _wrapWithMaterial(Widget child, {List<NavigatorObserver> observers = const []}) {
  return MaterialApp(
    key: UniqueKey(),
    localizationsDelegates: const [S.delegate],
    supportedLocales: S.delegate.supportedLocales,
    navigatorObservers: observers,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showModalBottomSheet<void>(context: context, builder: (_) => child),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    onGenerateRoute: (settings) =>
        MaterialPageRoute(settings: settings, builder: (_) => Scaffold(body: Text('dest:${settings.name}'))),
  );
}

class _PushObserver extends NavigatorObserver {
  final List<RouteSettings> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed.add(route.settings);
}

void main() {
  testWidgets('lists exactly Weight, Body measurements, Search, Scan, AI in that order', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_wrapWithMaterial(AddItemBottomSheet(day: DateTime(2026, 1, 1))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final labels = [
      S.current.weightLabel,
      S.current.profileBodyMeasurementsTitle,
      S.current.addItemMenuSearchLabel,
      S.current.addItemMenuScanProductLabel,
      S.current.addItemMenuMagicLabel,
    ];
    final ys = [for (final l in labels) tester.getTopLeft(find.text(l)).dy];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(find.byType(ListTile), findsNWidgets(5));
    for (final removed in [
      S.current.activityLabel,
      S.current.breakfastLabel,
      S.current.lunchLabel,
      S.current.dinnerLabel,
      S.current.snackLabel,
    ]) {
      expect(find.text(removed), findsNothing);
    }
  });

  for (final c in [
    (DateTime(2026, 1, 1, 8, 0), IntakeTypeEntity.breakfast),
    (DateTime(2026, 1, 1, 12, 30), IntakeTypeEntity.lunch),
    (DateTime(2026, 1, 1, 17, 0), IntakeTypeEntity.snack),
    (DateTime(2026, 1, 1, 21, 0), IntakeTypeEntity.dinner),
  ]) {
    testWidgets('Search, Scan and AI use the meal for ${c.$1.hour}:${c.$1.minute}', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await S.load(const Locale('en'));
      final day = DateTime(2026, 1, 1, 9);
      for (final (label, route) in [
        (S.current.addItemMenuSearchLabel, NavigationOptions.addMealRoute),
        (S.current.addItemMenuScanProductLabel, NavigationOptions.scannerRoute),
        (S.current.addItemMenuMagicLabel, NavigationOptions.magicRoute),
      ]) {
        final observer = _PushObserver();
        await tester.pumpWidget(
          _wrapWithMaterial(AddItemBottomSheet(day: day, now: () => c.$1), observers: [observer]),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        final pushed = observer.pushed.last;
        expect(pushed.name, route);
        if (pushed.arguments is AddMealScreenArguments) {
          final args = pushed.arguments as AddMealScreenArguments;
          expect(args.mealType.getIntakeType(), c.$2);
          expect(args.day, day);
        } else {
          final args = pushed.arguments as ScannerScreenArguments;
          expect(args.intakeTypeEntity, c.$2);
          expect(args.day, day);
        }
      }
    });
  }

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
