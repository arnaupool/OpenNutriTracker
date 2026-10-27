import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/features/reminders/data/reminder_data_source.dart';
import 'package:opennutritracker/features/reminders/data/reminder_dbo.dart';
import 'package:opennutritracker/features/reminders/data/reminder_platform.dart';
import 'package:opennutritracker/features/reminders/data/reminders_api.dart';
import 'package:opennutritracker/features/reminders/domain/reminders_service.dart';
import 'package:opennutritracker/features/reminders/presentation/reminder_edit_sheet.dart';
import 'package:opennutritracker/features/reminders/presentation/reminders_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _Platform implements ReminderPlatform {
  final PushSupport support;

  _Platform(this.support);

  @override
  PushSupport get pushSupport => support;

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
  late RemindersService service;
  late List<http.Request> requests;
  var linked = false;
  var counter = 0;

  setUp(() async {
    requests = [];
    linked = false;
    if (!Hive.isAdapterRegistered(ReminderDBO.hiveTypeId)) Hive.registerAdapter(ReminderDBOAdapter());
    if (!Hive.isAdapterRegistered(ReminderSettingsDBO.hiveTypeId)) Hive.registerAdapter(ReminderSettingsDBOAdapter());
    final n = counter++;
    data = ReminderDataSource(
      await Hive.openBox<ReminderDBO>('screen_reminders_$n', bytes: Uint8List(0)),
      await Hive.openBox<ReminderSettingsDBO>('screen_settings_$n', bytes: Uint8List(0)),
    );
    service = RemindersService(
      data,
      RemindersApi(
        'https://proj.supabase.co',
        'anon',
        () async => 'c' * 64,
        client: MockClient((request) async {
          requests.add(request);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'vapidPublicKey': 'VK',
              'channels': {'push': false, 'email': false, 'telegram': linked},
              'emailAddress': null,
              'reminders': <dynamic>[],
              if (body['telegramLink'] == true) 'telegramLink': {'code': 'x', 'url': 'https://t.me/bot?start=x'},
            }),
            200,
          );
        }),
      ),
      _Platform(PushSupport.iosNotInstalled),
      debounce: const Duration(milliseconds: 10),
    );
  });

  Future<void> pump(WidgetTester tester, {Future<bool> Function(Uri)? launcher}) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        locale: const Locale('en'),
        home: RemindersScreen(
          service: service,
          launcher: launcher,
          telegramPollInterval: const Duration(milliseconds: 20),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await service.stop();
  }

  testWidgets('shows the five defaults, the server note and the iPhone limitation', (tester) async {
    await pump(tester);
    for (final name in ['Weigh-in', 'Breakfast', 'Lunch', 'Snack', 'Dinner']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.textContaining('07:00 · M T W T F · Telegram'), findsOneWidget);
    expect(find.textContaining('Notifications may arrive 1-2 minutes late'), findsOneWidget);
    expect(find.textContaining('Add to Home Screen'), findsOneWidget);
    await close(tester);
  });

  testWidgets('the switch enables a reminder', (tester) async {
    await pump(tester);
    expect(data.reminder('default_lunch')!.enabled, isFalse);
    await tester.runAsync(() async {
      // Rows are ordered by time: weigh-in, breakfast, lunch.
      await tester.tap(find.byType(Switch).at(2));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(data.reminder('default_lunch')!.enabled, isTrue);
    await close(tester);
  });

  testWidgets('adding a custom reminder opens its editor, which can delete it; built-ins cannot be deleted', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Add reminder'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'Drink water');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('OK'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(data.reminders().where((r) => !r.isDefault).single.label, 'Drink water');
    expect(find.text('DELETE'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(ReminderEditSheet), matching: find.text('CANCEL')));
    await tester.pumpAndSettle();
    expect(find.text('Drink water'), findsOneWidget);

    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();
    expect(find.text('DELETE'), findsNothing);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.textContaining('Log your lunch'), findsOneWidget);
    await close(tester);
  });

  testWidgets('quiet hours can be switched off and on', (tester) async {
    await pump(tester);
    expect(data.settings().hasQuietHours, isTrue);
    await tester.runAsync(() async {
      await tester.tap(find.byType(SwitchListTile));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(data.settings().hasQuietHours, isFalse);
    await close(tester);
  });

  testWidgets('linking Telegram opens the bot link and ends linked', (tester) async {
    Uri? opened;
    await pump(
      tester,
      launcher: (uri) async {
        opened = uri;
        linked = true;
        return true;
      },
    );
    expect(find.text('Link Telegram'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Link Telegram'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(opened.toString(), 'https://t.me/bot?start=x');
    expect(data.settings().telegramLinked, isTrue);
    expect(find.text('Linked'), findsOneWidget);
    await close(tester);
  });
}
