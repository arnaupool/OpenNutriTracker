// Live check of device sync against the real backup Supabase project
// (FAS-01): real DBO types, real encryption, real RLS. Skipped unless
// SYNC_LIVE_URL and SYNC_LIVE_KEY (the anon / publishable key) are set:
//
//   SYNC_LIVE_URL=https://<ref>.supabase.co SYNC_LIVE_KEY=sb_publishable_... \
//     flutter test test/live/sync_live_test.dart
//
// It writes rows under a random token; delete them afterwards with
// `delete from public.sync_records where token = '<printed token>'`.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/dbo/fasting_session_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/sync/sync_boxes.dart';
import 'package:opennutritracker/core/sync/sync_crypto.dart';
import 'package:opennutritracker/core/sync/sync_engine.dart';
import 'package:opennutritracker/core/sync/sync_pairing.dart';
import 'package:opennutritracker/core/sync/sync_remote.dart';
import 'package:opennutritracker/core/sync/sync_state_store.dart';
import 'package:opennutritracker/core/utils/cloud_backup_token_service.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_entry_dbo.dart';
import 'package:opennutritracker/hive_registrar.g.dart';

final _url = Platform.environment['SYNC_LIVE_URL'];
final _key = Platform.environment['SYNC_LIVE_KEY'];

var _deviceCount = 0;

Future<(HiveDBProvider, SyncEngine, SyncStateStore)> _device(SyncRemote remote) async {
  final n = _deviceCount++;
  Future<Box<T>> open<T>(String name) => Hive.openBox<T>('$name$n', bytes: Uint8List(0));
  final db = HiveDBProvider()
    ..configBox = await open('config')
    ..userBox = await open('user')
    ..intakeBox = await open('intake')
    ..userActivityBox = await open('activity')
    ..trackedDayBox = await open('tracked')
    ..customMealBox = await open('custom')
    ..recipeBox = await open('recipe')
    ..customActivityTemplateBox = await open('template')
    ..weightLogBox = await open('weight')
    ..waterIntakeBox = await open('water')
    ..fastingBox = await open('fasting')
    ..bodyMeasurementBox = await open('body')
    ..mealPlanBox = await open('plan')
    ..dietPlanBox = await open('diet_plan');
  final state = SyncStateStore(await open<dynamic>('state'));
  return (db, SyncEngine(boxes: buildSyncedBoxes(db), remote: remote, state: state), state);
}

IntakeDBO _intake(String id, DateTime when, double kcal) => IntakeDBO(
  id: id,
  unit: 'g',
  amount: 150,
  type: IntakeTypeDBO.lunch,
  dateTime: when,
  meal: MealDBO(
    code: null,
    name: 'Paella',
    brands: null,
    thumbnailImageUrl: null,
    mainImageUrl: null,
    url: null,
    mealQuantity: '100',
    mealUnit: 'g',
    servingQuantity: null,
    servingUnit: null,
    servingSize: null,
    source: MealSourceDBO.custom,
    nutriments: MealNutrimentsDBO(
      energyKcal100: kcal,
      carbohydrates100: 20,
      fat100: 5,
      proteins100: 8,
      sugars100: null,
      saturatedFat100: null,
      fiber100: null,
    ),
  ),
);

void main() {
  final skip = _url == null || _key == null ? 'set SYNC_LIVE_URL and SYNC_LIVE_KEY to run' : null;

  setUpAll(() {
    Hive.registerAdapters();
    Hive.registerAdapter(MealPlanEntryDBOAdapter());
  });

  test('two devices sync real records through Supabase', () async {
    final remote = SupabaseSyncRemote(_url!, _key!);
    final pairing = SyncPairing(CloudBackupTokenService.generateToken(), SyncCrypto.generateKey());
    // ignore: avoid_print
    print('live token: ${pairing.token}');

    final (phone, phoneEngine, _) = await _device(remote);
    await phone.intakeBox.add(_intake('i1', DateTime(2026, 10, 22, 13, 30), 180));
    await phone.weightLogBox.put('2026-10-22', WeightLogDBO(date: DateTime(2026, 10, 22), weightKg: 80.4));
    await phone.fastingBox.put(
      'f1',
      FastingSessionDBO(
        id: 'f1',
        startedAt: DateTime(2026, 10, 21, 20),
        targetDurationMinutes: 960,
        completedAt: DateTime(2026, 10, 22, 12, 5),
      ),
    );
    final up = await phoneEngine.sync(pairing);
    expect(up.pushed, 3);

    final (desktop, desktopEngine, desktopState) = await _device(remote);
    await desktopState.setJoining(true);
    final down = await desktopEngine.sync(pairing);
    expect(down.pulled, 3);
    expect(down.unreadable, 0);
    final intake = desktop.intakeBox.values.single;
    expect(intake.meal.name, 'Paella');
    expect(intake.meal.nutriments.energyKcal100, 180);
    expect(desktop.weightLogBox.get('2026-10-22')!.weightKg, 80.4);
    expect(desktop.fastingBox.get('f1')!.completedAt, DateTime(2026, 10, 22, 12, 5));

    // Edit on the desktop, delete on the phone, and meet in the middle.
    await desktop.weightLogBox.put('2026-10-22', WeightLogDBO(date: DateTime(2026, 10, 22), weightKg: 80.1));
    await desktopEngine.sync(pairing);
    await phone.intakeBox.clear();
    await phoneEngine.sync(pairing);
    await desktopEngine.sync(pairing);
    expect(phone.weightLogBox.get('2026-10-22')!.weightKg, 80.1);
    expect(desktop.intakeBox.isEmpty, isTrue);

    // Another token sees nothing.
    final stranger = await remote.pull(CloudBackupTokenService.generateToken(), null);
    expect(stranger, isEmpty);
  }, skip: skip);
}
