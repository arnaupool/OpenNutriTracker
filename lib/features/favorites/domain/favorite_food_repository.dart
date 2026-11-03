import 'package:flutter/foundation.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/favorites/data/favorite_food_data_source.dart';
import 'package:opennutritracker/features/favorites/data/favorite_food_dbo.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_entity.dart';

/// Whether [meal] is the product [favorite] was copied from, or carries one
/// of its barcodes (so a search shows the favorite instead of it).
bool favoriteCoversMeal(FavoriteFoodEntity favorite, MealEntity meal) {
  final code = meal.code;
  if (code == null) return false;
  return favorite.barcodes.contains(code) || (favorite.originSource == meal.source.name && favorite.originId == code);
}

class FavoriteFoodRepository {
  final FavoriteFoodDataSource _dataSource;

  FavoriteFoodRepository(this._dataSource);

  /// All favorites, by name.
  List<FavoriteFoodEntity> getAll() {
    final list = _dataSource.getAll().map(FavoriteFoodEntity.fromDBO).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  FavoriteFoodEntity? getById(String id) {
    final dbo = _dataSource.getById(id);
    return dbo == null ? null : FavoriteFoodEntity.fromDBO(dbo);
  }

  /// The favorite that carries [barcode], if any.
  FavoriteFoodEntity? findByBarcode(String barcode) {
    final wanted = barcode.trim();
    if (wanted.isEmpty) return null;
    for (final f in getAll()) {
      if (f.barcodes.contains(wanted)) return f;
    }
    return null;
  }

  /// The favorite made from the product [source]/[originId], if any.
  FavoriteFoodEntity? findByOrigin(String? source, String? originId) {
    if (source == null || originId == null) return null;
    for (final f in getAll()) {
      if (f.originSource == source && f.originId == originId) return f;
    }
    return null;
  }

  /// The favorite a meal of the logging flow stands for: by its `fav:` code,
  /// its barcode or its origin.
  FavoriteFoodEntity? findForMeal(String? code, String? source) {
    if (code == null) return null;
    if (code.startsWith(favoriteCodePrefix)) return getById(code.substring(favoriteCodePrefix.length));
    return findByBarcode(code) ?? findByOrigin(source, code);
  }

  /// Favorites whose name or brand contains every word of [query].
  List<FavoriteFoodEntity> search(String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    return getAll().where((f) {
      final haystack = '${f.name} ${f.brand ?? ''}'.toLowerCase();
      return words.every(haystack.contains);
    }).toList();
  }

  /// Saves [favorite], stamping `modifiedAt`.
  Future<void> save(FavoriteFoodEntity favorite, {DateTime? now}) =>
      _dataSource.save(favorite.copyWith(modifiedAt: now ?? DateTime.now()).toDBO());

  Future<void> delete(String id) => _dataSource.delete(id);

  /// Notifies when favorites change (local edits and synced ones).
  Listenable listenable() => _dataSource.listenable();

  // Used by ExportDataUsecase / ImportDataUsecase.
  List<Map<String, dynamic>> exportJson() => _dataSource.getAll().map((f) => f.toJson()).toList();

  /// Merges exported favorites: a record with a known id replaces the local
  /// one only when it is newer. Returns how many were written.
  Future<int> importJson(List<Map<String, dynamic>> records) async {
    var imported = 0;
    for (final json in records) {
      final incoming = FavoriteFoodDBO.fromJson(json);
      final local = _dataSource.getById(incoming.id);
      if (local != null && !local.modifiedAt.isBefore(incoming.modifiedAt)) continue;
      await _dataSource.save(incoming);
      imported++;
    }
    return imported;
  }
}
