// Live check of account sync (task B6) against the real Supabase project:
// real Auth, real RLS on account_records and sync_records, real encryption.
// Skipped unless these are set:
//
//   ACCOUNT_LIVE_URL       https://<ref>.supabase.co
//   ACCOUNT_LIVE_KEY       anon / publishable key
//   ACCOUNT_LIVE_EMAIL     a TEMPORARY confirmed user created for this run
//   ACCOUNT_LIVE_PASSWORD  its password (Auth stores AccountAuthSecret of it)
//
// It signs two simulated devices in, creates the data key, migrates a token
// pairing into the account (and deletes the token rows), syncs records both
// ways and starts the account from scratch. Never point it at a real user:
// it deletes the account's records and key. Delete the user afterwards.
//
// The closed sign-up check runs only with ACCOUNT_LIVE_SIGNUP_FLAG set to a
// file path: it waits for `<flag>.go` (create it after setting
// app_settings.signups_open = false), tries one sign-up, writes
// `<flag>.done`, and the caller opens sign-ups again at once.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/account/account_auth_api.dart';
import 'package:opennutritracker/core/account/account_key_remote.dart';
import 'package:opennutritracker/core/account/account_key_service.dart';
import 'package:opennutritracker/core/account/account_session_exceptions.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/account/account_session_store.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/sync/sync_boxes.dart';
import 'package:opennutritracker/core/sync/sync_crypto.dart';
import 'package:opennutritracker/core/sync/sync_engine.dart';
import 'package:opennutritracker/core/sync/sync_pairing.dart';
import 'package:opennutritracker/core/sync/sync_remote.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/sync/sync_state_store.dart';
import 'package:opennutritracker/core/utils/cloud_backup_token_service.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_entry_dbo.dart';
import 'package:opennutritracker/features/reminders/data/reminder_dbo.dart';
import 'package:opennutritracker/hive_registrar.g.dart';

final _env = Platform.environment;
final _url = _env['ACCOUNT_LIVE_URL'];
final _key = _env['ACCOUNT_LIVE_KEY'];
final _email = _env['ACCOUNT_LIVE_EMAIL'];
final _password = _env['ACCOUNT_LIVE_PASSWORD'];
final _signupFlag = _env['ACCOUNT_LIVE_SIGNUP_FLAG'];

class _MemoryStorage implements FlutterSecureStorage {
  final values = <String, String>{};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String?;
    switch (invocation.memberName) {
      case #read:
        return Future<String?>.value(values[key]);
      case #write:
        final value = invocation.namedArguments[#value] as String?;
        value == null ? values.remove(key) : values[key!] = value;
        return Future<void>.value();
      case #delete:
        values.remove(key);
        return Future<void>.value();
      case #containsKey:
        return Future<bool>.value(values.containsKey(key));
    }
    return super.noSuchMethod(invocation);
  }
}

class _Pairings implements SyncKeyService {
  SyncPairing? pairing;
  bool forgotten = false;

  @override
  Future<SyncPairing?> read() async => pairing;

  @override
  Future<bool> isEnabled() async => pairing != null;

  @override
  Future<void> disable() async => pairing = null;

  @override
  Future<void> forget() async {
    pairing = null;
    forgotten = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

/// A closed sign-up that the app's first look at app_settings missed: the
/// request reaches the server and the trigger refuses it.
class _RacingApi extends AccountAuthApi {
  var _reads = 0;

  _RacingApi(super.projectUrl, super.anonKey);

  @override
  Future<bool> signupsOpen() async => _reads++ == 0 ? true : super.signupsOpen();
}

var _deviceCount = 0;

class _Device {
  final HiveDBProvider db;
  final Box<dynamic> stateBox;
  final storage = _MemoryStorage();
  final pairings = _Pairings();
  late final profiles = ProfileStore(storage: storage);
  late final accounts = AccountSessionService(
    api: AccountAuthApi(_url!, _key!),
    keys: AccountKeyService(AccountKeyRemote(_url!, _key!)),
    store: AccountSessionStore(storage: storage),
    profiles: profiles,
  );
  late final engine = SyncEngine(boxes: buildSyncedBoxes(db));
  late final service = SyncService(
    engine: engine,
    pairings: pairings,
    accounts: accounts,
    stateBox: stateBox,
    boxes: engine.boxes,
    tokenRemote: (token) => TokenSyncRemote(_url!, _key!, token),
    accountRemote: (userId, token) => AccountSyncRemote(_url!, _key!, userId, token),
    onApplied: (_) async {},
    activeProfile: () => AppProfile.defaultId,
  );

  _Device(this.db, this.stateBox);

  static Future<_Device> create() async {
    final n = _deviceCount++;
    Future<Box<T>> open<T>(String name) => Hive.openBox<T>('acct_$name$n', bytes: Uint8List(0));
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
      ..dietPlanBox = await open('diet_plan')
      ..reminderBox = await open('reminders')
      ..reminderSettingsBox = await open('reminder_settings');
    return _Device(db, await open<dynamic>('state'));
  }
}

IntakeDBO _intake(String id, String name, double kcal) => IntakeDBO(
  id: id,
  unit: 'g',
  amount: 150,
  type: IntakeTypeDBO.lunch,
  dateTime: DateTime(2026, 11, 3, 13, 30),
  meal: MealDBO(
    code: null,
    name: name,
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

// ignore: avoid_print
void _log(String message) => print('[live] $message');

void main() {
  final skip = _url == null || _key == null || _email == null || _password == null
      ? 'set ACCOUNT_LIVE_URL, ACCOUNT_LIVE_KEY, ACCOUNT_LIVE_EMAIL and ACCOUNT_LIVE_PASSWORD to run'
      : null;

  setUpAll(() {
    Hive.registerAdapters();
    Hive.registerAdapter(MealPlanEntryDBOAdapter());
    Hive.registerAdapter(ReminderDBOAdapter());
    Hive.registerAdapter(ReminderSettingsDBOAdapter());
  });

  test('account sync end to end', () async {
    const profile = AppProfile.defaultId;

    // Phone: a profile that synced through an old pairing token.
    final phone = await _Device.create();
    final pairing = SyncPairing(CloudBackupTokenService.generateToken(), SyncCrypto.generateKey());
    _log('token ${pairing.token}');
    phone.pairings.pairing = pairing;
    await phone.db.intakeBox.add(_intake('live-i1', 'Paella secreta', 180));
    await phone.db.weightLogBox.put('2026-11-03', WeightLogDBO(date: DateTime(2026, 11, 3), weightKg: 80.4));
    final tokenRun = await phone.service.syncNow();
    expect(tokenRun!.pushed, 2);
    expect(await TokenSyncRemote(_url!, _key!, pairing.token).pull(), hasLength(2));

    // Signs in: first sign-in creates the data key.
    expect(await phone.accounts.signIn(profile, _email!, _password!), SignInResult.ready);
    final link = (await phone.accounts.link(profile))!;
    _log('user ${link.userId}');
    expect(await phone.accounts.status(profile), AccountStatus.ready);
    expect(await phone.service.hasPendingChanges(profile), isTrue);

    // First account sync: upload and merge, then the token rows go.
    final migration = await phone.service.syncNow();
    expect(migration, isNotNull, reason: '${phone.service.status.value.error}');
    expect(migration!.pushed, 2);
    expect(await TokenSyncRemote(_url!, _key!, pairing.token).pull(), isEmpty, reason: 'token rows deleted');
    expect(phone.pairings.forgotten, isTrue);
    expect(await phone.service.hasPendingChanges(profile), isFalse);

    // Laptop: same account, its own local data; merge both ways.
    final laptop = await _Device.create();
    await laptop.db.intakeBox.add(_intake('live-i2', 'Lentejas', 120));
    expect(await laptop.accounts.signIn(profile, _email!, _password!), SignInResult.ready);
    expect(await laptop.accounts.dataKey(profile), await phone.accounts.dataKey(profile));
    final down = await laptop.service.syncNow();
    expect(down, isNotNull, reason: '${laptop.service.status.value.error}');
    expect(down!.pulled, 2);
    expect(down.unreadable, 0);
    expect(laptop.db.intakeBox.values.map((i) => i.id), unorderedEquals(['live-i1', 'live-i2']));
    expect(laptop.db.weightLogBox.get('2026-11-03')!.weightKg, 80.4);

    await laptop.db.weightLogBox.put('2026-11-03', WeightLogDBO(date: DateTime(2026, 11, 3), weightKg: 80.1));
    expect(await laptop.service.syncBeforeSignOut(profile), isTrue);
    await phone.service.syncNow();
    expect(phone.db.intakeBox.values.map((i) => i.id), unorderedEquals(['live-i1', 'live-i2']));
    expect(phone.db.weightLogBox.get('2026-11-03')!.weightKg, 80.1);

    // A forced refresh gives a new token that still works.
    final before = await phone.accounts.accessToken(profile);
    final forced = await phone.accounts.accessToken(profile, forceRefresh: true);
    expect(forced, isNot(before));
    expect(await phone.service.syncNow(), isNotNull);

    // Start from scratch on the laptop: the phone's old key is refused.
    final oldKey = (await phone.accounts.dataKey(profile))!;
    expect(await laptop.service.startFresh(profile, _password!), isTrue);
    expect(await laptop.accounts.dataKey(profile), isNot(oldKey));
    expect(await phone.service.syncNow(), isNull);
    expect(phone.service.status.value.error, isA<SyncKeyMismatchException>());
    final fresh = await SyncEngine(boxes: buildSyncedBoxes((await _Device.create()).db)).sync(
      SyncTarget(
        remote: AccountSyncRemote(
          _url!,
          _key!,
          link.userId,
          ({bool forceRefresh = false}) => laptop.accounts.accessToken(profile, forceRefresh: forceRefresh),
        ),
        state: SyncStateStore.account(await Hive.openBox<dynamic>('acct_fresh_state', bytes: Uint8List(0)), 'x'),
        key: (await laptop.accounts.dataKey(profile))!,
        account: true,
      ),
    );
    expect(fresh.pulled, 3, reason: 'two intakes and the weight, under the new key');
    expect(fresh.unreadable, 0);
    _log('done');
  }, skip: skip);

  test(
    'a sign-up the server refuses maps to SignupsClosedException',
    () async {
      final flag = _signupFlag!;
      final api = _RacingApi(_url!, _key!);
      final storage = _MemoryStorage();
      final accounts = AccountSessionService(
        api: api,
        keys: AccountKeyService(AccountKeyRemote(_url!, _key!)),
        store: AccountSessionStore(storage: storage),
        profiles: ProfileStore(storage: storage),
      );
      _log('waiting for $flag.go');
      final go = File('$flag.go');
      final deadline = DateTime.now().add(const Duration(minutes: 3));
      while (!go.existsSync()) {
        if (DateTime.now().isAfter(deadline)) fail('no go signal');
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      Object? error;
      try {
        await accounts.signUp(
          AppProfile.defaultId,
          'b6-closed-${DateTime.now().millisecondsSinceEpoch}@example.com',
          'x' * 12,
        );
      } on Object catch (e) {
        error = e;
      } finally {
        File('$flag.done').writeAsStringSync('$error');
      }
      _log('sign-up error: $error');
      expect(error, isA<SignupsClosedException>());
    },
    skip: _signupFlag == null || _url == null || _key == null ? 'set ACCOUNT_LIVE_SIGNUP_FLAG' : null,
  );
}
