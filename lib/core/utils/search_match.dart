import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

const _accentMap = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'ç': 'c',
  'ć': 'c',
  'č': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ě': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'ñ': 'n',
  'ń': 'n',
  'ň': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ō': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ů': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'š': 's',
  'ś': 's',
  'ž': 'z',
  'ź': 'z',
  'ł': 'l',
  'ß': 'ss',
  'æ': 'ae',
  'œ': 'oe',
};

/// Lower-cases [text] and removes accents, so "Plátano" and "platano" compare equal.
String foldSearchText(String text) {
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    out.write(_accentMap[char] ?? char);
  }
  return out.toString();
}

/// The words of a search [query], folded (see [foldSearchText]).
List<String> searchWords(String query) =>
    foldSearchText(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// How well [meal] answers the [words] of a query.
enum SearchMatch {
  /// Every word is in the name.
  name,

  /// Every word is in the name or the brand.
  nameAndBrand,

  /// Some words are, not all.
  partial,

  /// None.
  none,
}

class SearchMatchResult {
  final SearchMatch match;

  /// How many of the words were found in the name or the brand.
  final int matchedWords;

  const SearchMatchResult(this.match, this.matchedWords);
}

SearchMatchResult matchMeal(MealEntity meal, List<String> words) {
  if (words.isEmpty) return const SearchMatchResult(SearchMatch.none, 0);
  final name = foldSearchText(meal.name ?? '');
  final brand = foldSearchText(meal.brands ?? '');
  final both = '$name $brand';
  var inName = 0;
  var inBoth = 0;
  for (final w in words) {
    if (name.contains(w)) inName++;
    if (both.contains(w)) inBoth++;
  }
  if (inName == words.length) return SearchMatchResult(SearchMatch.name, inBoth);
  if (inBoth == words.length) return SearchMatchResult(SearchMatch.nameAndBrand, inBoth);
  return SearchMatchResult(inBoth > 0 ? SearchMatch.partial : SearchMatch.none, inBoth);
}

/// Whether the name or the brand of [meal] contains every one of [words].
bool mealContainsAllWords(MealEntity meal, List<String> words) {
  final match = matchMeal(meal, words).match;
  return match == SearchMatch.name || match == SearchMatch.nameAndBrand;
}

/// The [meals] that contain every one of [words]: those with all of them in
/// the name first, then those that need the brand. The order inside each group
/// is kept (it carries the cache-first and relevance order).
List<MealEntity> rankByMatch(List<MealEntity> meals, List<String> words) {
  final byName = <MealEntity>[];
  final byBrand = <MealEntity>[];
  for (final meal in meals) {
    switch (matchMeal(meal, words).match) {
      case SearchMatch.name:
        byName.add(meal);
      case SearchMatch.nameAndBrand:
        byBrand.add(meal);
      case SearchMatch.partial || SearchMatch.none:
        break;
    }
  }
  return [...byName, ...byBrand];
}
