import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/features/favorites/data/favorite_food_dbo.dart';

/// Favorite foods keyed by id.
class FavoriteFoodDataSource {
  final Box<FavoriteFoodDBO> _box;

  FavoriteFoodDataSource(this._box);

  List<FavoriteFoodDBO> getAll() => _box.values.toList();

  FavoriteFoodDBO? getById(String id) => _box.get(id);

  Future<void> save(FavoriteFoodDBO favorite) => _box.put(favorite.id, favorite);

  Future<void> delete(String id) => _box.delete(id);

  /// Notifies on every change to the box (local edits and synced ones).
  Listenable listenable() => _box.listenable();
}
