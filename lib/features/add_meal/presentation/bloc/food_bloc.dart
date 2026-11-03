import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/search_debounce.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_entity.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_repository.dart';

part 'food_event.dart';

part 'food_state.dart';

class FoodBloc extends Bloc<FoodEvent, FoodState> {
  final log = Logger('FoodBloc');

  final SearchProductsUseCase _searchProductUseCase;
  final GetConfigUsecase _getConfigUsecase;
  final FavoriteFoodRepository? _favorites;

  String _searchString = "";

  FoodBloc(this._searchProductUseCase, this._getConfigUsecase, [this._favorites])
      : super(FoodInitial()) {
    on<LoadFoodEvent>(
      (event, emit) =>
          _loadFood(event.searchString, emit, skipRemote: false, force: true),
    );
    on<SearchFoodInputChangedEvent>(
      (event, emit) => _loadFood(
        event.searchString,
        emit,
        skipRemote: event.searchString.trim().length < minRemoteQueryLength,
      ),
      transformer: debounceRestartable(searchDebounceDuration),
    );
    on<RefreshFoodEvent>((event, emit) async {
      emit(FoodLoadingState());
      try {
        final result = await _searchProductUseCase.searchFDCFoodByString(
          _searchString,
        );
        final favorites = _matchingFavorites(_searchString);
        emit(FoodLoadedState(
          food: _without(favorites, result.meals),
          favorites: favorites,
          remoteSourceEmpty: result.remoteSourceEmpty,
        ));
      } catch (error) {
        log.severe(error);
        emit(FoodFailedState());
      }
    });
  }

  /// Shared search routine for the immediate and debounced events. See
  /// [ProductsBloc] for the rationale behind [skipRemote], [force], and the
  /// no-blank behaviour.
  Future<void> _loadFood(
    String searchString,
    Emitter<FoodState> emit, {
    required bool skipRemote,
    bool force = false,
  }) async {
    if (!force && searchString == _searchString) return;
    _searchString = searchString;
    if (state is! FoodLoadedState) {
      emit(FoodLoadingState());
    }
    try {
      final result = await _searchProductUseCase.searchFDCFoodByString(
        searchString,
        skipRemote: skipRemote,
      );
      final config = await _getConfigUsecase.getConfig();
      final favorites = _matchingFavorites(searchString);
      emit(
        FoodLoadedState(
          food: _without(favorites, result.meals),
          favorites: favorites,
          usesImperialUnits: config.usesImperialUnits,
          remoteSourceEmpty: result.remoteSourceEmpty,
        ),
      );
    } catch (error) {
      log.severe(error);
      emit(FoodFailedState());
    }
  }

  /// The favorites that match [query]; they are shown before the results.
  List<FavoriteFoodEntity> _matchingFavorites(String query) => _favorites?.search(query) ?? const [];

  /// [meals] without the products the [favorites] stand for.
  List<MealEntity> _without(List<FavoriteFoodEntity> favorites, List<MealEntity> meals) => favorites.isEmpty
      ? meals
      : meals.where((m) => !favorites.any((f) => favoriteCoversMeal(f, m))).toList();
}
