part of 'food_bloc.dart';

abstract class FoodState extends Equatable {
  const FoodState();
}

class FoodInitial extends FoodState {
  @override
  List<Object> get props => [];
}

class FoodLoadingState extends FoodState {
  @override
  List<Object?> get props => [];
}

class FoodLoadedState extends FoodState {
  final List<MealEntity> food;

  /// Favorites matching the search, shown first with a star.
  final List<FavoriteFoodEntity> favorites;
  final bool usesImperialUnits;

  /// True when the remote FDC source returned zero results (or failed
  /// silently — e.g. rate limit). The UI uses this to show a "no results"
  /// hint below any custom-meal matches.
  final bool remoteSourceEmpty;

  const FoodLoadedState({
    required this.food,
    this.favorites = const [],
    this.usesImperialUnits = false,
    this.remoteSourceEmpty = false,
  });

  @override
  List<Object?> get props => [food, favorites, usesImperialUnits, remoteSourceEmpty];
}

class FoodFailedState extends FoodState {
  @override
  List<Object?> get props => [];
}
