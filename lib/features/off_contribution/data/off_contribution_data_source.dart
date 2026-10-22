import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/utils/app_const.dart';
import 'package:opennutritracker/features/off_contribution/data/off_account_data_source.dart';

class OffAuthException implements Exception {}

/// Open Food Facts write API (https://openfoodfacts.github.io/openfoodfacts-server/api/).
///
/// Builds run with `--dart-define=OFF_STAGING=true` talk to the staging
/// server (world.openfoodfacts.net, basic auth off:off, separate accounts),
/// which is where contributions are tested; release builds use production.
class OffContributionDataSource {
  static const _stagingFromEnvironment = bool.fromEnvironment('OFF_STAGING');
  static const _timeout = Duration(seconds: 30);

  final _log = Logger('OffContributionDataSource');
  final http.Client _client;
  final Future<String> Function() _userAgent;
  final bool staging;

  OffContributionDataSource({
    http.Client? client,
    Future<String> Function()? userAgent,
    this.staging = _stagingFromEnvironment,
  })  : _client = client ?? http.Client(),
        _userAgent = userAgent ?? AppConst.getUserAgentString;

  String get _host => staging ? 'world.openfoodfacts.net' : 'world.openfoodfacts.org';

  Future<Map<String, String>> _headers() async => {
        'User-Agent': await _userAgent(),
        if (staging) 'Authorization': 'Basic ${base64Encode(utf8.encode('off:off'))}',
      };

  /// Whether OFF already has a product for [code].
  Future<bool> productExists(String code) async {
    final response = await _client
        .get(Uri.https(_host, '/api/v2/product/$code', {'fields': 'code'}), headers: await _headers())
        .timeout(_timeout);
    if (response.statusCode == 404) return false;
    if (response.statusCode != 200) {
      throw Exception('OFF product lookup failed: HTTP ${response.statusCode}');
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['status'] == 1;
  }

  /// Creates the product from [fields] (product_jqm2 form fields), signed
  /// with [credentials]. Throws [OffAuthException] on rejected credentials.
  Future<void> submitProduct(Map<String, String> fields, OffCredentials credentials) async {
    // The body carries the password, so only the barcode is logged.
    _log.fine('Sending product ${fields['code']} to OFF (${staging ? 'staging' : 'production'})');
    final response = await _client
        .post(
          Uri.https(_host, '/cgi/product_jqm2.pl'),
          headers: await _headers(),
          body: {...fields, 'user_id': credentials.userId, 'password': credentials.password},
        )
        .timeout(_timeout);
    if (response.statusCode == 401 || response.statusCode == 403) throw OffAuthException();
    if (response.statusCode != 200) {
      throw Exception('OFF save failed: HTTP ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['status'] != 1) {
      throw Exception('OFF save rejected: ${json['status_verbose']}');
    }
  }
}
