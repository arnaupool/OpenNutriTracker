import 'package:flutter/foundation.dart';
import 'package:opennutritracker/features/favorites/data/favorite_food_data_source.dart';
import 'package:opennutritracker/features/favorites/data/favorite_food_dbo.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_repository.dart';

/// A favorites data source that lives in memory, for widget tests.
class InMemoryFavoriteDataSource extends ChangeNotifier implements FavoriteFoodDataSource {
  final Map<String, FavoriteFoodDBO> items = {};

  @override
  List<FavoriteFoodDBO> getAll() => items.values.toList();

  @override
  FavoriteFoodDBO? getById(String id) => items[id];

  @override
  Future<void> save(FavoriteFoodDBO favorite) async {
    items[favorite.id] = favorite;
    notifyListeners();
  }

  @override
  Future<void> delete(String id) async {
    items.remove(id);
    notifyListeners();
  }

  @override
  Listenable listenable() => this;
}

FavoriteFoodRepository inMemoryRepository([InMemoryFavoriteDataSource? source]) =>
    FavoriteFoodRepository(source ?? InMemoryFavoriteDataSource());
