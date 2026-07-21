import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/off_const.dart';

// kIsWeb is a compile-time constant that's always false under `flutter
// test` (the VM test runner, not a web compile target), so only the
// native-build branch of getOffWordSearchUrl is exercisable here. The
// web-proxy branch (see off_const.dart) is verified manually against a
// real web build instead.
void main() {
  group('OFFConst.getOffWordSearchUrl', () {
    test('native builds call search.openfoodfacts.org directly', () {
      final uri = OFFConst.getOffWordSearchUrl('banana');

      expect(uri.host, 'search.openfoodfacts.org');
      expect(uri.path, '/search');
      expect(uri.queryParameters['q'], 'banana');
      expect(uri.queryParameters['langs'], 'en');
    });

    test('passes the requested locale through', () {
      final uri = OFFConst.getOffWordSearchUrl('milch', langs: 'de');

      expect(uri.queryParameters['langs'], 'de');
    });
  });

  group('OFFConst.getOffBarcodeSearchUri', () {
    test('always calls world.openfoodfacts.org directly (CORS-enabled, '
        'no proxy needed)', () {
      final uri = OFFConst.getOffBarcodeSearchUri('5449000000996');

      expect(uri.host, 'world.openfoodfacts.org');
      expect(uri.path, '/api/v2/product/5449000000996');
    });
  });
}
