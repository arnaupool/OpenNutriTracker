import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/off_image_url.dart';

void main() {
  final base = Uri.parse('https://food.example.com/');
  const thumb = 'https://images.openfoodfacts.org/images/products/301/762/042/2003/front_en.12.100.jpg';

  group('displayImageUrl', () {
    test('web rewrites images.openfoodfacts.org to the same-origin proxy', () {
      expect(
        displayImageUrl(thumb, isWeb: true, base: base),
        'https://food.example.com/off-images/images/products/301/762/042/2003/front_en.12.100.jpg',
      );
    });

    test('web rewrites static.openfoodfacts.org and keeps the query', () {
      expect(
        displayImageUrl('https://static.openfoodfacts.org/images/misc/nutriscore-a.svg?v=2', isWeb: true, base: base),
        'https://food.example.com/off-static/images/misc/nutriscore-a.svg?v=2',
      );
    });

    test('web keeps a sub-path deployment', () {
      expect(
        displayImageUrl(thumb, isWeb: true, base: Uri.parse('https://example.com/ont/')).startsWith(
          'https://example.com/ont/off-images/images/products/',
        ),
        isTrue,
      );
    });

    test('native keeps calling Open Food Facts directly', () {
      expect(displayImageUrl(thumb, isWeb: false, base: base), thumb);
    });

    test('other hosts, empty and already proxied URLs are untouched', () {
      for (final url in ['', 'https://example.org/a.jpg', 'https://food.example.com/off-images/x.jpg']) {
        expect(displayImageUrl(url, isWeb: true, base: base), url);
      }
    });
  });
}
