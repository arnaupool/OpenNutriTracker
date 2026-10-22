import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:opennutritracker/features/add_meal/data/dto/bedca/bedca_food_dto.dart';

/// Searches the bundled BEDCA food list on the device (no network).
class BedcaDataSource {
  static const _defaultLimit = 30;

  final Future<String> Function() _load;
  Future<List<_IndexedFood>>? _foods;

  BedcaDataSource({Future<String> Function()? loader})
      : _load = loader ?? (() => rootBundle.loadString(BedcaConst.assetPath));

  /// Foods where every word of [query] starts a word of the Spanish or the
  /// English name, ignoring case and accents. Names whose first word is the
  /// query's first word come first, then other Spanish matches, then English
  /// ones; shorter names first within each.
  Future<List<BedcaFoodDTO>> search(String query, {int limit = _defaultLimit}) async {
    final tokens = _words(query);
    if (tokens.isEmpty) return const [];

    final ranked = <(int, _IndexedFood)>[];
    for (final food in await (_foods ??= _index())) {
      final int rank;
      if (_allMatch(tokens, food.esWords)) {
        rank = _wordMatches(tokens.first, food.esWords.first) ? 0 : 1;
      } else if (_allMatch(tokens, food.enWords)) {
        rank = 2;
      } else {
        continue;
      }
      ranked.add((rank, food));
    }
    ranked.sort((a, b) {
      final byRank = a.$1.compareTo(b.$1);
      if (byRank != 0) return byRank;
      final byLength = a.$2.es.length.compareTo(b.$2.es.length);
      return byLength != 0 ? byLength : a.$2.es.compareTo(b.$2.es);
    });
    return ranked.take(limit).map((r) => r.$2.food).toList();
  }

  Future<List<_IndexedFood>> _index() async {
    final json = jsonDecode(await _load()) as Map<String, dynamic>;
    return (json['foods'] as List)
        .map((f) => _IndexedFood(BedcaFoodDTO.fromJson(f as Map<String, dynamic>)))
        .toList();
  }

  static bool _allMatch(List<String> tokens, List<String> words) =>
      tokens.every((t) => words.any((w) => _wordMatches(t, w)));

  /// [token] starts [word], or is its plural: BEDCA names are singular
  /// ("Lenteja, seca") while people type "lentejas".
  static bool _wordMatches(String token, String word) =>
      word.startsWith(token) ||
      (word.length >= 3 &&
          token.startsWith(word) &&
          (token == '${word}s' || token == '${word}es'));

  static const _accents = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', 'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', 'ñ': 'n', 'ç': 'c',
  };

  static String _normalize(String s) =>
      s.toLowerCase().split('').map((c) => _accents[c] ?? c).join();

  static List<String> _words(String s) =>
      _normalize(s).split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
}

class _IndexedFood {
  final BedcaFoodDTO food;
  final String es;
  final List<String> esWords;
  final List<String> enWords;

  _IndexedFood(this.food)
      : es = BedcaDataSource._words(food.nameEs).join(' '),
        esWords = BedcaDataSource._words(food.nameEs),
        enWords = BedcaDataSource._words(food.nameEn ?? '');
}
