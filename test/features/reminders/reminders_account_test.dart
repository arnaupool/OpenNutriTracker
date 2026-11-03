import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/features/reminders/data/reminder_data_source.dart';
import 'package:opennutritracker/features/reminders/data/reminder_dbo.dart';
import 'package:opennutritracker/features/reminders/data/reminder_platform.dart';
import 'package:opennutritracker/features/reminders/data/reminders_api.dart';
import 'package:opennutritracker/features/reminders/domain/reminders_service.dart';

class _Platform implements ReminderPlatform {
  @override
  PushSupport get pushSupport => PushSupport.notSupported;

  @override
  PushPermission get pushPermission => PushPermission.unsupported;

  @override
  Future<PushPermission> requestPushPermission() async => PushPermission.unsupported;

  @override
  Future<Map<String, dynamic>?> subscribePush(String vapidPublicKey) async => null;

  @override
  Future<String?> detectTimezone() async => 'Europe/Madrid';
}

void main() {
  late ReminderDataSource data;
  late List<http.Request> requests;
  var counter = 0;

  setUp(() async {
    requests = [];
    if (!Hive.isAdapterRegistered(ReminderDBO.hiveTypeId)) Hive.registerAdapter(ReminderDBOAdapter());
    if (!Hive.isAdapterRegistered(ReminderSettingsDBO.hiveTypeId)) Hive.registerAdapter(ReminderSettingsDBOAdapter());
    final n = counter++;
    data = ReminderDataSource(
      await Hive.openBox<ReminderDBO>('acc_reminders_$n', bytes: Uint8List(0)),
      await Hive.openBox<ReminderSettingsDBO>('acc_settings_$n', bytes: Uint8List(0)),
    );
  });

  RemindersService build({required bool account}) => RemindersService(
    data,
    RemindersApi(
      'https://proj.supabase.co',
      'anon',
      () async => 'd' * 64,
      accountToken: () async => account ? 'jwt-123' : null,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'channels': {'push': false, 'email': true, 'telegram': true},
            'emailAddress': 'me@example.org',
            'reminders': <dynamic>[],
          }),
          200,
        );
      }),
    ),
    _Platform(),
    debounce: const Duration(milliseconds: 10),
    usesAccount: () async => account,
  );

  test('account profile sends the bearer token and reads the channels from the account', () async {
    final service = build(account: true);
    await service.refreshStatus();
    expect(requests.single.headers['Authorization'], 'Bearer jwt-123');
    expect(requests.single.headers['x-reminder-device'], 'd' * 64);
    final state = service.channelState;
    expect(state.telegramLinked, isTrue);
    expect(state.emailVerified, isTrue);
    expect(state.email, 'me@example.org');
    // Nothing of it lands in the settings box that sync carries to other devices.
    expect(data.settings().telegramLinked, isFalse);
    expect(data.settings().emailVerified, isFalse);
  });

  test('local profile keeps the device behaviour', () async {
    final service = build(account: false);
    await service.refreshStatus();
    expect(requests.single.headers.containsKey('Authorization'), isFalse);
    expect(data.settings().telegramLinked, isTrue);
    expect(service.channelState.emailVerified, isTrue);
  });

  test('the synced settings never carry the channel state', () {
    final json = ReminderSettingsDBO(
      timezone: 'UTC',
      email: 'a@b.c',
      emailVerified: true,
      telegramLinked: true,
    ).toSyncJson();
    expect(json.keys, unorderedEquals(['timezone', 'quietStart', 'quietEnd']));
  });

  test('detachAccount calls reminders-sync without the account token', () async {
    final service = build(account: true);
    await service.detachAccount();
    final request = requests.single;
    expect(request.url.path, '/functions/v1/reminders-sync');
    expect(jsonDecode(request.body), {'detachAccount': true});
    expect(request.headers.containsKey('Authorization'), isFalse);
  });
}
