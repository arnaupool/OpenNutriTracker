import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:opennutritracker/features/reminders/data/reminder_platform.dart';

ReminderPlatform createPlatform() => _NativeReminderPlatform();

/// Android / iOS / desktop: no web push; the time zone comes from the OS.
class _NativeReminderPlatform implements ReminderPlatform {
  @override
  PushSupport get pushSupport => PushSupport.notSupported;

  @override
  PushPermission get pushPermission => PushPermission.unsupported;

  @override
  Future<PushPermission> requestPushPermission() async => PushPermission.unsupported;

  @override
  Future<Map<String, dynamic>?> subscribePush(String vapidPublicKey) async => null;

  @override
  Future<String?> detectTimezone() async {
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      return name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }
}
