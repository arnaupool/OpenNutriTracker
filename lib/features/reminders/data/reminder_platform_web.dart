import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:opennutritracker/features/reminders/data/reminder_platform.dart';
import 'package:web/web.dart' as web;

ReminderPlatform createPlatform() => _WebReminderPlatform();

/// Browser: web push through `push_sw.js`, registered with scope `push/` so
/// it never competes with Flutter's own service worker for the app page.
class _WebReminderPlatform implements ReminderPlatform {
  static const _scriptPath = 'push_sw.js';
  static const _scopePath = 'push/';

  bool get _isIos {
    final ua = web.window.navigator.userAgent;
    if (RegExp(r'iPhone|iPad|iPod').hasMatch(ua)) return true;
    // iPadOS reports a Mac user agent but has touch points.
    return ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1;
  }

  bool get _isStandalone {
    final nav = web.window.navigator as JSObject;
    if (nav.has('standalone') && nav.getProperty<JSAny?>('standalone'.toJS).dartify() == true) return true;
    return web.window.matchMedia('(display-mode: standalone)').matches;
  }

  bool get _apisAvailable =>
      web.window.navigator.has('serviceWorker') && globalContext.has('PushManager') && web.window.isSecureContext;

  @override
  PushSupport get pushSupport {
    if (!web.window.isSecureContext) return PushSupport.notSupported;
    if (_isIos && !_isStandalone) return PushSupport.iosNotInstalled;
    return _apisAvailable && globalContext.has('Notification') ? PushSupport.supported : PushSupport.notSupported;
  }

  @override
  PushPermission get pushPermission {
    if (pushSupport != PushSupport.supported) return PushPermission.unsupported;
    return _permissionFrom(web.Notification.permission);
  }

  PushPermission _permissionFrom(String value) => switch (value) {
    'granted' => PushPermission.granted,
    'denied' => PushPermission.denied,
    _ => PushPermission.prompt,
  };

  @override
  Future<PushPermission> requestPushPermission() async {
    if (pushSupport != PushSupport.supported) return PushPermission.unsupported;
    // The call itself runs synchronously from the tap; only the result is awaited.
    final result = await web.Notification.requestPermission().toDart;
    return _permissionFrom(result.toDart);
  }

  Future<web.ServiceWorkerRegistration> _registration() async {
    final base = web.document.baseURI;
    final container = web.window.navigator.serviceWorker;
    final registration = await container
        .register(
          Uri.parse(base).resolve(_scriptPath).toString().toJS,
          web.RegistrationOptions(scope: Uri.parse(base).resolve(_scopePath).path),
        )
        .toDart;
    // pushManager needs an active worker.
    for (var i = 0; i < 100 && registration.active == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return registration;
  }

  @override
  Future<Map<String, dynamic>?> subscribePush(String vapidPublicKey) async {
    if (pushSupport != PushSupport.supported || pushPermission != PushPermission.granted) return null;
    final registration = await _registration();
    if (registration.active == null) return null;
    final existing = await registration.pushManager.getSubscription().toDart;
    web.PushSubscription? subscription = existing;
    subscription ??= await registration.pushManager
        .subscribe(
          web.PushSubscriptionOptionsInit(
            userVisibleOnly: true,
            applicationServerKey: base64Url.decode(base64Url.normalize(vapidPublicKey)).toJS,
          ),
        )
        .toDart;
    final json = subscription.toJSON().dartify();
    if (json is! Map) return null;
    return _plain(json) as Map<String, dynamic>;
  }

  /// `dartify` gives `Map<Object?, Object?>`; the API client wants JSON-like maps.
  Object? _plain(Object? value) {
    if (value is Map) return {for (final e in value.entries) e.key.toString(): _plain(e.value)};
    if (value is List) return [for (final v in value) _plain(v)];
    return value;
  }

  @override
  Future<String?> detectTimezone() async {
    try {
      final intl = globalContext.getProperty<JSObject>('Intl'.toJS);
      final format = intl.callMethod<JSObject>('DateTimeFormat'.toJS);
      final zone = format.callMethod<JSObject>('resolvedOptions'.toJS).getProperty<JSString?>('timeZone'.toJS);
      final name = zone?.toDart;
      return name == null || name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }
}
