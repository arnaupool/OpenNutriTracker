import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/reminders/data/reminder_data_source.dart';
import 'package:opennutritracker/features/reminders/data/reminder_dbo.dart';
import 'package:opennutritracker/features/reminders/data/reminder_device_token_service.dart';
import 'package:opennutritracker/features/reminders/data/reminder_platform.dart';
import 'package:opennutritracker/features/reminders/data/reminders_api.dart';
import 'package:opennutritracker/features/reminders/domain/reminder_open_target.dart';
import 'package:opennutritracker/features/reminders/domain/reminder_rules.dart';
import 'package:opennutritracker/features/reminders/domain/reminders_service.dart';

class _FakePlatform implements ReminderPlatform {
  PushSupport support;
  _FakePlatform({this.support = PushSupport.notSupported});

  @override
  PushSupport get pushSupport => support;

  @override
  PushPermission get pushPermission => PushPermission.prompt;

  @override
  Future<PushPermission> requestPushPermission() async => PushPermission.granted;

  @override
  Future<Map<String, dynamic>?> subscribePush(String vapidPublicKey) async => {
    'endpoint': 'https://push.example/abc',
    'keys': {'p256dh': 'k', 'auth': 'a'},
  };

  @override
  Future<String?> detectTimezone() async => 'Europe/Madrid';
}

ReminderDBO _custom({String id = 'c1', String label = 'Agua', ReminderChannel channel = ReminderChannel.telegram}) =>
    ReminderDBO(id: id, type: ReminderType.custom, label: label, time: '10:00', days: const [1, 3], channel: channel);

IntakeEntity _intake(IntakeTypeEntity type, DateTime when) =>
    IntakeEntity(id: 'i1', unit: 'g', amount: 100, type: type, meal: MealEntity.empty(), dateTime: when);

void main() {
  group('defaults', () {
    final defaults = ReminderRules.defaults(ReminderChannel.telegram);

    test('five built-in reminders with the specified times and days', () {
      expect(defaults.map((r) => r.id), [
        'default_weigh_in',
        'default_breakfast',
        'default_lunch',
        'default_snack',
        'default_dinner',
      ]);
      expect(defaults.map((r) => r.time), ['07:00', '07:30', '14:00', '17:30', '21:00']);
      expect(defaults.first.days, [1, 2, 3, 4, 5]);
      for (final meal in defaults.skip(1)) {
        expect(meal.days, [1, 2, 3, 4, 5, 6, 7]);
      }
    });

    test('only the weigh-in is enabled; meals skip when already logged', () {
      expect(defaults.first.enabled, isTrue);
      expect(defaults.first.type, ReminderType.weighIn);
      expect(defaults.skip(1).every((r) => !r.enabled && r.skipIfLogged && r.type == ReminderType.meal), isTrue);
      expect(defaults.skip(1).map((r) => r.mealType), ReminderMealType.values);
      expect(defaults.every(ReminderRules.isValid), isTrue);
    });

    test('quiet hours default to 23:00-06:30', () {
      final s = ReminderSettingsDBO();
      expect((s.quietStart, s.quietEnd), ('23:00', '06:30'));
      expect(s.hasQuietHours, isTrue);
      expect(s.copyWith(clearQuiet: true).hasQuietHours, isFalse);
    });
  });

  group('default channel', () {
    ReminderChannel pick(bool telegram, bool email, bool push) =>
        ReminderRules.defaultChannel(telegramLinked: telegram, emailVerified: email, pushSupported: push);

    test('telegram, then email, then push, then telegram again', () {
      expect(pick(true, true, true), ReminderChannel.telegram);
      expect(pick(false, true, true), ReminderChannel.email);
      expect(pick(false, false, true), ReminderChannel.push);
      expect(pick(false, false, false), ReminderChannel.telegram);
    });
  });

  group('validation', () {
    test('label is 1 to 40 characters', () {
      expect(ReminderRules.isValidLabel(''), isFalse);
      expect(ReminderRules.isValidLabel('   '), isFalse);
      expect(ReminderRules.isValidLabel('a' * 40), isTrue);
      expect(ReminderRules.isValidLabel('a' * 41), isFalse);
      expect(ReminderRules.clampLabel('a' * 50).length, 40);
    });

    test('at most 15 reminders', () {
      expect(ReminderRules.canAdd(14), isTrue);
      expect(ReminderRules.canAdd(15), isFalse);
    });

    test('built-in reminders cannot be deleted or renamed, custom ones can', () {
      for (final r in ReminderRules.defaults(ReminderChannel.push)) {
        expect(ReminderRules.canDelete(r), isFalse);
        expect(ReminderRules.canRename(r), isFalse);
      }
      expect(ReminderRules.canDelete(_custom()), isTrue);
      expect(ReminderRules.canRename(_custom()), isTrue);
    });

    test('time is HH:MM in 5-minute steps', () {
      expect(ReminderRules.isValidTime('07:05'), isTrue);
      expect(ReminderRules.isValidTime('07:03'), isFalse);
      expect(ReminderRules.isValidTime('24:00'), isFalse);
      expect(ReminderRules.isValidTime('7:00'), isFalse);
      expect(ReminderRules.snapTime(7, 3), '07:05');
      expect(ReminderRules.snapTime(7, 2), '07:00');
      expect(ReminderRules.snapTime(23, 58), '00:00');
    });

    test('days are ISO weekdays and not empty', () {
      expect(ReminderRules.isValidDays([1, 7]), isTrue);
      expect(ReminderRules.isValidDays([]), isFalse);
      expect(ReminderRules.isValidDays([0]), isFalse);
      expect(ReminderRules.isValidDays([8]), isFalse);
    });

    test('a meal needs a meal type and the others must not have one', () {
      final meal = ReminderDBO(
        id: 'm',
        type: ReminderType.meal,
        time: '08:00',
        days: const [1],
        channel: ReminderChannel.push,
      );
      expect(ReminderRules.isValid(meal), isFalse);
      expect(ReminderRules.isValid(_custom().copyWith(id: 'bad id')), isFalse);
      expect(ReminderRules.isValid(_custom()), isTrue);
    });

    test('a duplicate is a disabled copy with a new id', () {
      final copy = ReminderRules.duplicate(
        ReminderRules.defaults(ReminderChannel.email)[2],
        'new1',
        'Almuerzo (copia)',
      );
      expect(copy.id, 'new1');
      expect(copy.isDefault, isFalse);
      expect(copy.enabled, isFalse);
      expect(copy.mealType, ReminderMealType.lunch);
      expect(copy.time, '14:00');
    });
  });

  group('serialization', () {
    test('reminder JSON is the backend wire format and round-trips', () {
      final r = ReminderRules.defaults(ReminderChannel.push)[2];
      expect(r.toJson(), {
        'id': 'default_lunch',
        'type': 'meal',
        'mealType': 'lunch',
        'label': '',
        'time': '14:00',
        'days': [1, 2, 3, 4, 5, 6, 7],
        'channel': 'push',
        'enabled': false,
        'skipIfLogged': true,
      });
      expect(ReminderDBO.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>).toJson(), r.toJson());
      final w = ReminderRules.defaults(ReminderChannel.telegram).first;
      expect(w.toJson()['type'], 'weigh_in');
      expect(w.toJson()['mealType'], isNull);
    });

    test('settings JSON round-trips', () {
      final s = ReminderSettingsDBO(
        timezone: 'Europe/Madrid',
        quietStart: null,
        quietEnd: null,
        email: 'a@b.com',
        emailVerified: true,
        telegramLinked: true,
      );
      final back = ReminderSettingsDBO.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(back.toJson(), s.toJson());
      expect(back.hasQuietHours, isFalse);
    });

    test('hive adapters round-trip both records', () async {
      final dir = await Directory.systemTemp.createTemp('reminders_hive');
      addTearDown(() => dir.delete(recursive: true));
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(ReminderDBO.hiveTypeId)) Hive.registerAdapter(ReminderDBOAdapter());
      if (!Hive.isAdapterRegistered(ReminderSettingsDBO.hiveTypeId)) Hive.registerAdapter(ReminderSettingsDBOAdapter());
      final reminder = _custom(channel: ReminderChannel.email);
      final settings = ReminderSettingsDBO(timezone: 'America/Lima', email: 'x@y.org', emailVerified: true);
      final rBox = await Hive.openBox<ReminderDBO>('RemindersRoundTrip');
      final sBox = await Hive.openBox<ReminderSettingsDBO>('ReminderSettingsRoundTrip');
      await rBox.put(reminder.id, reminder);
      await sBox.put(ReminderSettingsDBO.boxKey, settings);
      await rBox.close();
      await sBox.close();
      final rBack = await Hive.openBox<ReminderDBO>('RemindersRoundTrip');
      final sBack = await Hive.openBox<ReminderSettingsDBO>('ReminderSettingsRoundTrip');
      expect(rBack.get(reminder.id)!.toJson(), reminder.toJson());
      expect(sBack.get(ReminderSettingsDBO.boxKey)!.toJson(), settings.toJson());
      await rBack.close();
      await sBack.close();
    });
  });

  group('device token', () {
    test('is 64 lowercase hex characters', () {
      final token = ReminderDeviceTokenService.generate(Random(1));
      expect(ReminderDeviceTokenService.tokenPattern.hasMatch(token), isTrue);
      expect(ReminderDeviceTokenService.generate() == ReminderDeviceTokenService.generate(), isFalse);
    });
  });

  group('notification link', () {
    test('parses weigh-in and meal targets', () {
      expect(ReminderOpenTarget.fromUri(Uri.parse('https://x.test/?open=weigh_in'))!.weighIn, isTrue);
      final meal = ReminderOpenTarget.fromUri(Uri.parse('https://x.test/?open=meal&meal=lunch#/'))!;
      expect(meal.weighIn, isFalse);
      expect(meal.meal, ReminderMealType.lunch);
    });

    test('ignores anything else', () {
      expect(ReminderOpenTarget.fromUri(Uri.parse('https://x.test/')), isNull);
      expect(ReminderOpenTarget.fromUri(Uri.parse('https://x.test/?open=meal')), isNull);
      expect(ReminderOpenTarget.fromUri(Uri.parse('https://x.test/?open=meal&meal=brunch')), isNull);
      expect(ReminderOpenTarget.fromUri(Uri.parse('https://x.test/?open=other')), isNull);
    });
  });

  group('api', () {
    test('posts to the function with the device and apikey headers', () async {
      late http.Request seen;
      final api = RemindersApi(
        'https://proj.supabase.co/',
        'anon',
        () async => 'a' * 64,
        client: MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'vapidPublicKey': 'VK',
              'channels': {'push': true, 'email': false, 'telegram': true},
              'emailAddress': null,
              'reminders': [
                {'id': 'r1', 'channel': 'email'},
              ],
              'telegramLink': {'code': 'c', 'url': 'https://t.me/bot?start=c'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final r = await api.sync({'telegramLink': true});
      expect(seen.method, 'POST');
      expect(seen.url.toString(), 'https://proj.supabase.co/functions/v1/reminders-sync');
      expect(seen.headers['apikey'], 'anon');
      expect(seen.headers['x-reminder-device'], 'a' * 64);
      expect(seen.headers['Content-Type'], contains('application/json'));
      expect(jsonDecode(seen.body), {'telegramLink': true});
      expect(r.vapidPublicKey, 'VK');
      expect(r.pushActive, isTrue);
      expect(r.telegramLinked, isTrue);
      expect(r.emailVerified, isFalse);
      expect(r.channels['r1'], ReminderChannel.email);
      expect(r.telegramLinkUrl, 'https://t.me/bot?start=c');
    });

    test('errors carry the backend code and status', () async {
      final api = RemindersApi(
        'https://proj.supabase.co',
        'anon',
        () async => 'a' * 64,
        client: MockClient((_) async => http.Response('{"error":"wrong_code"}', 400)),
      );
      await expectLater(
        api.confirmEmail('000000'),
        throwsA(
          isA<RemindersApiException>()
              .having((e) => e.code, 'code', 'wrong_code')
              .having((e) => e.status, 'status', 400),
        ),
      );
    });

    test('test endpoint returns the channel used', () async {
      late Map<String, dynamic> body;
      final api = RemindersApi(
        'https://proj.supabase.co',
        'anon',
        () async => 'a' * 64,
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.url.path, '/functions/v1/reminders-test');
          return http.Response('{"ok":true,"channel":"telegram"}', 200);
        }),
      );
      expect(await api.test('r1'), 'telegram');
      expect(body, {'reminderId': 'r1'});
    });
  });

  group('service', () {
    late Directory dir;
    late ReminderDataSource data;
    late List<http.Request> requests;
    Map<String, dynamic> answer = {};
    Future<void>? gate;
    var idCounter = 0;

    RemindersService build({_FakePlatform? platform, DateTime? now}) => RemindersService(
      data,
      RemindersApi(
        'https://proj.supabase.co',
        'anon',
        () async => 'b' * 64,
        client: MockClient((request) async {
          requests.add(request);
          await gate;
          return http.Response(jsonEncode(answer), 200);
        }),
      ),
      platform ?? _FakePlatform(),
      debounce: const Duration(milliseconds: 20),
      now: now == null ? null : () => now,
      newId: () => 'id${idCounter++}',
    );

    setUp(() async {
      requests = [];
      gate = null;
      idCounter = 0;
      answer = {
        'vapidPublicKey': 'VK',
        'channels': {'push': false, 'email': false, 'telegram': false},
        'emailAddress': null,
        'reminders': <dynamic>[],
      };
      dir = await Directory.systemTemp.createTemp('reminders_service');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(ReminderDBO.hiveTypeId)) Hive.registerAdapter(ReminderDBOAdapter());
      if (!Hive.isAdapterRegistered(ReminderSettingsDBO.hiveTypeId)) Hive.registerAdapter(ReminderSettingsDBOAdapter());
      data = ReminderDataSource(await Hive.openBox<ReminderDBO>('r'), await Hive.openBox<ReminderSettingsDBO>('s'));
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('first open creates the defaults, the timezone and a telegram channel', () async {
      final service = build();
      await service.ensureDefaults();
      expect(service.reminders.length, 5);
      expect(service.settings.timezone, 'Europe/Madrid');
      expect(service.reminders.every((r) => r.channel == ReminderChannel.telegram), isTrue);
      // Opening again never duplicates them.
      await service.ensureDefaults();
      expect(service.reminders.length, 5);
    });

    test('defaults use web push when the browser supports it and nothing is linked', () async {
      final service = build(platform: _FakePlatform(support: PushSupport.supported));
      await service.ensureDefaults();
      expect(service.reminders.every((r) => r.channel == ReminderChannel.push), isTrue);
    });

    test('custom reminders: limit of 15, rename, duplicate, delete', () async {
      final service = build();
      await service.ensureDefaults();
      for (var i = 0; i < 10; i++) {
        expect(await service.addCustom('Aviso $i'), isNotNull);
      }
      expect(service.reminders.length, 15);
      expect(await service.addCustom('Uno más'), isNull);
      final custom = service.reminders.firstWhere((r) => !r.isDefault);
      expect(await service.duplicate(custom.id, 'Copia'), isNull);
      expect(await service.delete(custom.id), isTrue);
      expect(await service.delete('default_lunch'), isFalse);
      expect(await service.rename('default_lunch', 'Otro'), isFalse);
      final copy = await service.duplicate('default_lunch', 'Almuerzo (copia)');
      expect(copy, isNotNull);
      expect(await service.rename(copy!.id, 'x' * 41), isFalse);
      expect(await service.rename(copy.id, 'x' * 40), isTrue);
      expect(data.reminder(copy.id)!.label.length, 40);
      expect(await service.addCustom(''), isNull);
    });

    test('sync sends the full list and settings and adopts the server channel', () async {
      final service = build();
      await service.ensureDefaults();
      await service.update(_custom(id: 'r1', channel: ReminderChannel.push));
      answer['reminders'] = [
        {'id': 'r1', 'channel': 'email'},
      ];
      answer['channels'] = {'push': false, 'email': true, 'telegram': true};
      answer['emailAddress'] = 'me@x.org';
      final response = await service.syncNow();
      expect(response, isNotNull);
      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(body['timezone'], 'Europe/Madrid');
      expect(body['quietStart'], '23:00');
      expect(body['quietEnd'], '06:30');
      expect((body['reminders'] as List).length, 6);
      expect(requests.last.headers['x-reminder-device'], 'b' * 64);
      expect(data.reminder('r1')!.channel, ReminderChannel.email);
      expect(service.settings.telegramLinked, isTrue);
      expect(service.settings.emailVerified, isTrue);
      expect(service.settings.email, 'me@x.org');
    });

    test('a channel the user changed during the request is kept', () async {
      final service = build();
      await service.ensureDefaults();
      await service.update(_custom(id: 'r1', channel: ReminderChannel.push));
      answer['reminders'] = [
        {'id': 'r1', 'channel': 'email'},
      ];
      final release = Completer<void>();
      gate = release.future;
      final pending = service.syncNow();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await service.update(data.reminder('r1')!.copyWith(channel: ReminderChannel.telegram));
      release.complete();
      await pending;
      expect(data.reminder('r1')!.channel, ReminderChannel.telegram);
    });

    test('changes are synced after the debounce, once', () async {
      final service = build();
      await service.ensureDefaults();
      await service.start();
      await service.setEnabled('default_lunch', true);
      await service.setEnabled('default_snack', true);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final syncs = requests.where((r) => r.url.path.endsWith('reminders-sync')).toList();
      expect(syncs.length, 1);
      expect(
        ((jsonDecode(syncs.first.body) as Map)['reminders'] as List).where((r) => (r as Map)['enabled'] == true).length,
        3,
      );
      await service.stop();
    });

    test('server errors set the error status without throwing', () async {
      final failing = RemindersService(
        data,
        RemindersApi(
          'https://proj.supabase.co',
          'anon',
          () async => 'b' * 64,
          client: MockClient((_) async => http.Response('{"error":"internal"}', 500)),
        ),
        _FakePlatform(),
      );
      expect(await failing.syncNow(), isNull);
      expect(failing.status.value, ReminderSyncStatus.error);
    });

    test('meal flag: only for a meal logged today that an enabled reminder skips', () async {
      final now = DateTime(2026, 10, 27, 13, 30);
      final service = build(now: now);
      await service.ensureDefaults();

      await service.onIntakeAdded(_intake(IntakeTypeEntity.lunch, now));
      expect(requests, isEmpty, reason: 'lunch reminder is disabled');

      await service.setEnabled('default_lunch', true);
      await service.onIntakeAdded(_intake(IntakeTypeEntity.dinner, now));
      expect(requests, isEmpty, reason: 'no enabled reminder for dinner');

      await service.onIntakeAdded(_intake(IntakeTypeEntity.lunch, now.subtract(const Duration(days: 1))));
      expect(requests, isEmpty, reason: 'not today');

      await service.onIntakeAdded(_intake(IntakeTypeEntity.lunch, now));
      expect(requests.length, 1);
      expect(jsonDecode(requests.single.body), {
        'mealLogged': {'date': '2026-10-27', 'mealType': 'lunch'},
      });
    });

    test('a failing meal flag never throws', () async {
      final now = DateTime(2026, 10, 27, 13, 30);
      final service = RemindersService(
        data,
        RemindersApi(
          'https://p.supabase.co',
          'a',
          () async => 'b' * 64,
          client: MockClient((_) async => throw const SocketException('offline')),
        ),
        _FakePlatform(),
        now: () => now,
      );
      await service.ensureDefaults();
      await service.setEnabled('default_lunch', true);
      await service.onIntakeAdded(_intake(IntakeTypeEntity.lunch, now));
    });

    test('intake types map to the backend meal names', () {
      expect(IntakeTypeEntity.values.map((t) => t.name).toSet(), ReminderMealType.values.map((m) => m.name).toSet());
      expect(IntakeTypeEntity.fromIntakeTypeDBO(IntakeTypeDBO.snack).name, 'snack');
    });

    test('web push: subscription is sent after permission and the vapid key', () async {
      final service = build(platform: _FakePlatform(support: PushSupport.supported));
      await service.ensureDefaults();
      answer['channels'] = {'push': true, 'email': false, 'telegram': false};
      expect(await service.enablePush(), PushSetupResult.active);
      final last = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(last['pushSubscription']['endpoint'], 'https://push.example/abc');
      expect(service.pushActive.value, isTrue);
      expect(await build().enablePush(), PushSetupResult.unsupported);
    });
  });
}
