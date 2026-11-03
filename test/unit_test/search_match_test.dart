import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/search_match.dart';

void main() {
  test('foldSearchText removes accents and case', () {
    expect(foldSearchText('Plátano Ñoño Çà'), 'platano nono ca');
  });

  test('searchWords splits on whitespace and drops empties', () {
    expect(searchWords('  Leche   Entera '), ['leche', 'entera']);
    expect(searchWords('   '), isEmpty);
  });
}
