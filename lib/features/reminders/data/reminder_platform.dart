import 'package:opennutritracker/features/reminders/data/reminder_platform_stub.dart'
    if (dart.library.js_interop) 'package:opennutritracker/features/reminders/data/reminder_platform_web.dart'
    as impl;

/// Whether this device can receive web push.
enum PushSupport {
  supported,

  /// No service worker / Push API / secure context (or not a browser).
  notSupported,

  /// iOS Safari outside the installed PWA: push only works once the app is
  /// added to the Home Screen.
  iosNotInstalled,
}

enum PushPermission { granted, denied, prompt, unsupported }

/// What differs by platform: time zone detection and web push. Everything
/// except the time zone is a no-op outside the browser.
abstract class ReminderPlatform {
  PushSupport get pushSupport;

  PushPermission get pushPermission;

  /// Asks the browser for notification permission. Must run straight from a
  /// tap (before any `await`) or Safari refuses it.
  Future<PushPermission> requestPushPermission();

  /// Subscribes this browser to push with the server's VAPID key and returns
  /// the subscription JSON (`endpoint`, `keys`), or null when not possible.
  Future<Map<String, dynamic>?> subscribePush(String vapidPublicKey);

  /// IANA name of the device time zone, or null when it cannot be read.
  Future<String?> detectTimezone();
}

ReminderPlatform createReminderPlatform() => impl.createPlatform();
