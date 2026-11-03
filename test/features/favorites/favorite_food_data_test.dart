import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/custom_activity_template_dbo.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/data/dbo/body_measurement_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/data/repository/body_measurement_repository.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/custom_activity_template_repository.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/data/repository/user_activity_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/sync/sync_crypto.dart';
import 'package:opennutritracker/core/sync/sync_engine.dart';
import 'package:opennutritracker/core/sync/sync_state_store.dart';
import 'package:opennutritracker/core/sync/synced_box.dart';
import 'package:opennutritracker/features/favorites/data/favorite_food_data_source.dart';
import 'package:opennutritracker/features/favorites/data/favorite_food_dbo.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_repository.dart';
import 'package:opennutritracker/features/settings/domain/usecase/export_data_usecase.dart';
import 'package:opennutritracker/features/settings/domain/usecase/import_data_usecase.dart';

import '../../helpers/fake_sync_server.dart';
import '../../helpers/hive_test_setup.dart';

MealNutrimentsDBO _milk() => MealNutrimentsDBO(
  energyKcal100: 47,
  carbohydrates100: 4.8,
  fat100: 1.6,
  proteins100: 3.2,
  sugars100: 4.8,
  saturatedFat100: 1,
  fiber100: 0,
  calcium100: 120,
);

FavoriteFoodDBO _leche({String id = 'f1', String name = 'Leche', DateTime? at}) => FavoriteFoodDBO(
  id: id,
  name: name,
  brand: 'Hacendado',
  nutriments: _milk(),
  unit: 'ml',
  portionName: 'vaso',
  portionQuantity: 250,
  barcodes: const ['8410297112345', '8410297999999'],
  originSource: 'off',
  originId: '8410297112345',
  createdAt: at ?? DateTime(2026, 11, 3, 9),
  modifiedAt: at ?? DateTime(2026, 11, 3, 9),
);

class _Device {
  final Box<FavoriteFoodDBO> box;
  final Box<dynamic> stateBox;
  final SyncEngine engine;

  _Device(this.box, this.stateBox, this.engine);

  static int _n = 0;

  static Future<_Device> create() async {
    final id = _n++;
    final box = await Hive.openBox<FavoriteFoodDBO>('fav$id', bytes: Uint8List(0));
    final stateBox = await Hive.openBox<dynamic>('favstate$id', bytes: Uint8List(0));
    final engine = SyncEngine(
      boxes: [
        SyncedBox<FavoriteFoodDBO>(
          name: 'FavoriteFoodBox',
          box: box,
          identityOf: (_, key) => key?.toString(),
          toJson: (v) => v.toJson(),
          fromJson: FavoriteFoodDBO.fromJson,
          naturalKey: true,
        ),
      ],
    );
    return _Device(box, stateBox, engine);
  }

  SyncTarget target(FakeSyncServer server, Uint8List key) =>
      SyncTarget(remote: server.remote('u1'), state: SyncStateStore.account(stateBox, 'u1'), key: key);
}

class _Activity extends Fake implements UserActivityRepository {
  @override
  Future<List<UserActivityDBO>> getAllUserActivityDBO() async => [];

  @override
  Future<void> addAllUserActivityDBOs(List<UserActivityDBO> userActivityDBOs) async {}
}

class _Intake extends Fake implements IntakeRepository {
  @override
  Future<List<IntakeDBO>> getAllIntakesDBO() async => [];

  @override
  Future<void> addAllIntakeDBOs(List<IntakeDBO> intakeDBOs) async {}
}

class _Tracked extends Fake implements TrackedDayRepository {
  @override
  Future<List<TrackedDayDBO>> getAllTrackedDaysDBO() async => [];

  @override
  Future<void> addAllTrackedDays(List<TrackedDayDBO> trackedDaysDBO) async {}
}

class _Recipes extends Fake implements RecipeRepository {
  @override
  List<RecipeDBO> getAllRecipesDBO() => [];

  @override
  Future<void> addAllRecipeDBOs(List<RecipeDBO> recipes) async {}
}

class _CustomMeals extends Fake implements CustomMealDataSource {
  @override
  List<MealDBO> getAllCustomMeals() => [];
}

class _Weight extends Fake implements WeightLogRepository {
  @override
  Future<List<WeightLogDBO>> getAllEntriesDBO() async => [];

  @override
  Future<void> addAllEntries(List<WeightLogDBO> entries) async {}
}

class _Templates extends Fake implements CustomActivityTemplateRepository {
  @override
  Future<List<CustomActivityTemplateDBO>> allTemplateDBOs() async => [];

  @override
  Future<void> addAllTemplateDBOs(List<CustomActivityTemplateDBO> templates) async {}
}

class _Body extends Fake implements BodyMeasurementRepository {
  @override
  Future<List<BodyMeasurementDBO>> getAllEntriesDBO() async => [];

  @override
  Future<void> addAllEntries(List<BodyMeasurementDBO> entries) async {}
}

class _User extends Fake implements UserRepository {}

class _Config extends Fake implements ConfigRepository {}

void main() {
  late Directory dir;

  setUpAll(() {
    registerHiveAdaptersOnce();
    if (!Hive.isAdapterRegistered(FavoriteFoodDBO.hiveTypeId)) {
      Hive.registerAdapter(FavoriteFoodDBOAdapter());
    }
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fav');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('the Hive adapter round-trips every field through a closed and reopened box', () async {
    var box = await Hive.openBox<FavoriteFoodDBO>('favs');
    await box.put('f1', _leche());
    await box.put(
      'f2',
      FavoriteFoodDBO(
        id: 'f2',
        name: 'Hecho a mano',
        nutriments: _milk(),
        createdAt: DateTime(2026, 11, 3),
        modifiedAt: DateTime(2026, 11, 4),
      ),
    );
    await box.close();
    box = await Hive.openBox<FavoriteFoodDBO>('favs');
    final a = box.get('f1')!;
    expect(a.toJson(), _leche().toJson());
    expect(a.barcodes, ['8410297112345', '8410297999999']);
    expect(a.nutriments.calcium100, 120);
    final b = box.get('f2')!;
    expect(b.unit, 'g');
    expect(b.brand, isNull);
    expect(b.portionQuantity, isNull);
    expect(b.barcodes, isEmpty);
    expect(b.originSource, isNull);
  });

  test('JSON round trip keeps the record', () {
    final json = jsonDecode(jsonEncode(_leche().toJson())) as Map<String, dynamic>;
    expect(FavoriteFoodDBO.fromJson(json).toJson(), _leche().toJson());
  });

  test('a favorite syncs between two devices: create, edit, delete', () async {
    final server = FakeSyncServer();
    final key = SyncCrypto.generateKey();
    final phone = await _Device.create();
    final desktop = await _Device.create();
    DateTime at(int m) => DateTime.utc(2026, 11, 3, 12, m);

    await phone.box.put('f1', _leche());
    await phone.engine.sync(phone.target(server, key), now: at(0));
    await desktop.engine.sync(desktop.target(server, key), now: at(1));
    expect(desktop.box.get('f1')!.name, 'Leche');
    expect(desktop.box.get('f1')!.barcodes.length, 2);

    await desktop.box.put('f1', _leche(name: 'Leche entera', at: DateTime(2026, 11, 3, 10)));
    await desktop.engine.sync(desktop.target(server, key), now: at(2));
    await phone.engine.sync(phone.target(server, key), now: at(3));
    expect(phone.box.get('f1')!.name, 'Leche entera');

    await phone.box.delete('f1');
    await phone.engine.sync(phone.target(server, key), now: at(4));
    final tombstones = server.rowsOf('u1').where((r) => r.box != SyncEngine.keyCheckBox && r.deleted);
    expect(tombstones, hasLength(1));
    await desktop.engine.sync(desktop.target(server, key), now: at(5));
    expect(desktop.box.get('f1'), isNull);
  });

  test('favorites survive an export zip and import, newer wins', () async {
    final source = FavoriteFoodRepository(FavoriteFoodDataSource(await Hive.openBox<FavoriteFoodDBO>('src')));
    await FavoriteFoodDataSource(Hive.box<FavoriteFoodDBO>('src')).save(_leche());
    final export = ExportDataUsecase(
      _Activity(),
      _Intake(),
      _Tracked(),
      _Recipes(),
      _CustomMeals(),
      _Weight(),
      _Templates(),
      _Body(),
      _User(),
      _Config(),
      source,
    );
    final zip = await export.buildZipBytes();
    expect(ZipDecoder().decodeBytes(zip).findFile('favorite_foods.json'), isNotNull);

    final target = FavoriteFoodRepository(FavoriteFoodDataSource(await Hive.openBox<FavoriteFoodDBO>('dst')));
    final import = ImportDataUsecase(
      _Activity(),
      _Intake(),
      _Tracked(),
      _Recipes(),
      _Weight(),
      _Templates(),
      _Body(),
      _User(),
      _Config(),
      target,
    );
    expect(await import.importFromZipBytes(zip), isTrue);
    expect(target.getById('f1')!.toDBO().toJson(), _leche().toJson());

    // Importing the same zip again changes nothing; a newer copy replaces,
    // an older one does not.
    final list = [_leche().toJson()];
    expect(await target.importJson(list), 0);
    expect(await target.importJson([_leche(name: 'Leche nueva', at: DateTime(2026, 11, 5)).toJson()]), 1);
    expect(target.getById('f1')!.name, 'Leche nueva');
    expect(await target.importJson([_leche(name: 'Vieja', at: DateTime(2026, 11, 1)).toJson()]), 0);
    expect(target.getById('f1')!.name, 'Leche nueva');
  });
}
