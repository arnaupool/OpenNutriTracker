import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:opennutritracker/features/reminders/data/reminder_dbo.dart';

/// A non-2xx answer from the reminders backend (`{"error": "<code>"}`).
class RemindersApiException implements Exception {
  final int status;
  final String code;

  const RemindersApiException(this.status, this.code);

  @override
  String toString() => 'RemindersApiException($status, $code)';
}

/// What `reminders-sync` answers.
class ReminderSyncResponse {
  final String? vapidPublicKey;
  final bool pushActive;
  final bool emailVerified;
  final bool telegramLinked;
  final String? emailAddress;

  /// Channel the server has for each reminder id (it may have moved push to email).
  final Map<String, ReminderChannel> channels;
  final String? telegramLinkUrl;

  const ReminderSyncResponse({
    this.vapidPublicKey,
    this.pushActive = false,
    this.emailVerified = false,
    this.telegramLinked = false,
    this.emailAddress,
    this.channels = const {},
    this.telegramLinkUrl,
  });

  factory ReminderSyncResponse.fromJson(Map<String, dynamic> json) {
    final ch = (json['channels'] as Map?) ?? const {};
    final link = json['telegramLink'] as Map?;
    return ReminderSyncResponse(
      vapidPublicKey: json['vapidPublicKey'] as String?,
      pushActive: ch['push'] == true,
      emailVerified: ch['email'] == true,
      telegramLinked: ch['telegram'] == true,
      emailAddress: json['emailAddress'] as String?,
      channels: {
        for (final r in (json['reminders'] as List? ?? const []))
          (r as Map)['id'] as String: ReminderChannel.fromWire(r['channel'] as String?),
      },
      telegramLinkUrl: link?['url'] as String?,
    );
  }
}

/// Client of the reminders Edge Functions (docs/reminders-backend.md).
class RemindersApi {
  final String baseUrl;
  final String anonKey;
  final Future<String> Function() _deviceToken;
  final http.Client _client;

  /// [baseUrl] is the project URL; `/functions/v1` is added here.
  RemindersApi(String projectUrl, this.anonKey, this._deviceToken, {http.Client? client})
    : baseUrl = '${projectUrl.replaceAll(RegExp(r'/+$'), '')}/functions/v1',
      _client = client ?? http.Client();

  Future<Map<String, dynamic>> _post(String function, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/$function'),
          headers: {'Content-Type': 'application/json', 'apikey': anonKey, 'x-reminder-device': await _deviceToken()},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    Map<String, dynamic> decoded = {};
    try {
      final parsed = jsonDecode(utf8.decode(response.bodyBytes));
      if (parsed is Map<String, dynamic>) decoded = parsed;
    } on FormatException {
      // Not JSON (a gateway error page): handled by the status below.
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RemindersApiException(response.statusCode, decoded['error'] as String? ?? 'http_${response.statusCode}');
    }
    return decoded;
  }

  /// Sends whatever keys are present in [body] (see the contract) and returns the server state.
  Future<ReminderSyncResponse> sync(Map<String, dynamic> body) async =>
      ReminderSyncResponse.fromJson(await _post('reminders-sync', body));

  /// Sends reminder [reminderId] now. Returns the channel used.
  Future<String?> test(String reminderId) async =>
      (await _post('reminders-test', {'reminderId': reminderId}))['channel'] as String?;

  Future<void> requestEmailCode(String email) async {
    await _post('email-verify', {'action': 'request', 'email': email});
  }

  /// Returns the verified address.
  Future<String?> confirmEmail(String code) async =>
      (await _post('email-verify', {'action': 'confirm', 'code': code}))['email'] as String?;
}
