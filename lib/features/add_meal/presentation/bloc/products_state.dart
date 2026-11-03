part of 'products_bloc.dart';

abstract class ProductsState extends Equatable {
  const ProductsState();
}

class ProductsInitial extends ProductsState {
  @override
  List<Object> get props => [];
}

class ProductsLoadingState extends ProductsState {
  @override
  List<Object?> get props => [];
}

class ProductsLoadedState extends ProductsState {
  final List<MealEntity> products;

  /// Products that match only some of the words, shown under "Similar
  /// results" when none matches them all.
  final List<MealEntity> similar;

  /// Favorites matching the search, shown first with a star.
  final List<FavoriteFoodEntity> favorites;
  final bool usesImperialUnits;

  /// True when the remote OFF source returned zero results (or failed
  /// silently — e.g. rate limit). The UI uses this to show a "no results"
  /// hint below any custom-meal matches.
  final bool remoteSourceEmpty;

  const ProductsLoadedState({
    required this.products,
    this.similar = const [],
    this.favorites = const [],
    this.usesImperialUnits = false,
    this.remoteSourceEmpty = false,
  });

  @override
  List<Object?> get props => [products, similar, favorites, remoteSourceEmpty];
}

class ProductsFailedState extends ProductsState {
  @override
  List<Object?> get props => [];
}
