import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/error_dialog.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/add_meal_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/food_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/default_results_widget.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_search_bar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/no_results_widget.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/quick_add_bottom_sheet.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/products_bloc.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_entity.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_repository.dart';
import 'package:opennutritracker/features/favorites/presentation/favorites_list.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/features/scanner/util/barcode_check_digit.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// FR-02: this is now the "Search" destination reached from
/// [AddItemMenuScreen] (Products + Food tabs) — Scan Product and Recently
/// were promoted to their own top-level menu entries, matching the
/// reference UI, so the search bar no longer carries a redundant barcode
/// icon and this screen no longer owns a Recently tab.
class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  /// Tab indexes of the add-meal screen.
  static const favoritesTab = 0;

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<String> _searchStringListener = ValueNotifier('');

  late AddMealType _mealType;
  late DateTime _day;

  late ProductsBloc _productsBloc;
  late FoodBloc _foodBloc;

  late TabController _tabController;
  bool _initialTabApplied = false;

  @override
  void initState() {
    _productsBloc = locator<ProductsBloc>();
    _foodBloc = locator<FoodBloc>();
    // Favorites first; start there when there are any, otherwise on the
    // product search.
    final hasFavorites = locator<FavoriteFoodRepository>().getAll().isNotEmpty;
    _tabController = TabController(length: 3, vsync: this, initialIndex: hasFavorites ? 0 : 1);
    _tabController.addListener(() {
      // Update search results when tab changes
      _onSearchSubmit(_searchStringListener.value);
    });
    super.initState();
  }

  @override
  void didChangeDependencies() {
    final args =
        ModalRoute.of(context)?.settings.arguments as AddMealScreenArguments;
    _mealType = args.mealType;
    _day = args.day;
    if (!_initialTabApplied) {
      _initialTabApplied = true;
      final tab = args.initialTab;
      if (tab != null && tab >= 0 && tab < _tabController.length) _tabController.index = tab;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_mealType.getTypeName(context)),
        actions: [
          Semantics(
            identifier: 'add-meal-quick-add',
            child: TextButton(
              onPressed: _onQuickAddPressed,
              child: Text(S.of(context).quickAddCardLabel),
            ),
          ),
          BlocBuilder<AddMealBloc, AddMealState>(
            bloc: locator<AddMealBloc>()..add(InitializeAddMealEvent()),
            builder: (BuildContext context, AddMealState state) {
              if (state is AddMealLoadedState) {
                return IconButton(
                  onPressed: () =>
                      _onCustomAddButtonPressed(state.usesImperialUnits),
                  icon: const Icon(Icons.add_circle_outline),
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              MealSearchBar(
                searchStringListener: _searchStringListener,
                onSearchSubmit: _onSearchSubmit,
                onSearchChanged: _onSearchChanged,
                onBarcodePressed: null,
              ),
              const SizedBox(height: 16.0),
              TabBar(
                tabs: [
                  Tab(text: S.of(context).favoritesTitle),
                  Tab(text: S.of(context).searchProductsPage),
                  Tab(text: S.of(context).searchFoodPage),
                ],
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    FavoritesList(
                      query: _searchStringListener,
                      day: _day,
                      mealType: _mealType,
                    ),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.only(left: 8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            S.of(context).searchResultsLabel,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        BlocBuilder<ProductsBloc, ProductsState>(
                          bloc: _productsBloc,
                          builder: (context, state) {
                            if (state is ProductsInitial) {
                              return const DefaultsResultsWidget();
                            } else if (state is ProductsLoadingState) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 32),
                                child: CircularProgressIndicator(),
                              );
                            } else if (state is ProductsLoadedState) {
                              if (state.products.isEmpty &&
                                  state.favorites.isEmpty) {
                                return const NoResultsWidget();
                              }
                              return Flexible(
                                child: _resultsList(
                                  state.favorites,
                                  state.products,
                                  state.remoteSourceEmpty,
                                  state.usesImperialUnits,
                                ),
                              );
                            } else if (state is ProductsFailedState) {
                              return ErrorDialog(
                                errorText: S
                                    .of(context)
                                    .errorFetchingProductData,
                                onRefreshPressed:
                                    _onProductsRefreshButtonPressed,
                              );
                            } else {
                              return const SizedBox();
                            }
                          },
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.only(left: 8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            S.of(context).searchResultsLabel,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        BlocBuilder<FoodBloc, FoodState>(
                          bloc: _foodBloc,
                          builder: (context, state) {
                            if (state is FoodInitial) {
                              return const DefaultsResultsWidget();
                            } else if (state is FoodLoadingState) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 32),
                                child: CircularProgressIndicator(),
                              );
                            } else if (state is FoodLoadedState) {
                              if (state.food.isEmpty &&
                                  state.favorites.isEmpty) {
                                return const NoResultsWidget();
                              }
                              return Flexible(
                                child: _resultsList(
                                  state.favorites,
                                  state.food,
                                  state.remoteSourceEmpty,
                                  state.usesImperialUnits,
                                ),
                              );
                            } else if (state is FoodFailedState) {
                              return ErrorDialog(
                                errorText: S
                                    .of(context)
                                    .errorFetchingProductData,
                                onRefreshPressed: _onFoodRefreshButtonPressed,
                              );
                            } else {
                              return const SizedBox();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Search results: the matching favorites first (with a star), then the
  /// products found.
  Widget _resultsList(
    List<FavoriteFoodEntity> favorites,
    List<MealEntity> meals,
    bool remoteSourceEmpty,
    bool usesImperialUnits,
  ) {
    return Semantics(
      identifier: 'add-meal-results',
      child: ListView.builder(
        itemCount: favorites.length + meals.length + (remoteSourceEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < favorites.length) {
            final favorite = favorites[index];
            return MealItemCard(
              day: _day,
              mealEntity: favorite.toMealEntity(),
              addMealType: _mealType,
              usesImperialUnits: usesImperialUnits,
              favorite: favorite,
            );
          }
          final mealIndex = index - favorites.length;
          if (mealIndex == meals.length) return const NoResultsWidget();
          return MealItemCard(
            day: _day,
            mealEntity: meals[mealIndex],
            addMealType: _mealType,
            usesImperialUnits: usesImperialUnits,
          );
        },
      ),
    );
  }

  void _onProductsRefreshButtonPressed() {
    _productsBloc.add(const RefreshProductsEvent());
  }

  void _onFoodRefreshButtonPressed() {
    _foodBloc.add(const RefreshFoodEvent());
  }

  void _onSearchSubmit(String inputText) {
    switch (_tabController.index) {
      case 0:
        // Favorites filter locally as the text changes.
        break;
      case 1:
        final trimmed = inputText.trim();
        if (isValidBarcodeCheckDigit(trimmed)) {
          Navigator.of(context).pushNamed(
            NavigationOptions.scannerRoute,
            arguments: ScannerScreenArguments(
              _day,
              _mealType.getIntakeType(),
              initialBarcode: trimmed,
            ),
          );
          return;
        }
        _productsBloc.add(LoadProductsEvent(searchString: inputText));
      case 2:
        _foodBloc.add(LoadFoodEvent(searchString: inputText));
    }
  }

  /// Debounced search-as-you-type.
  void _onSearchChanged(String inputText) {
    switch (_tabController.index) {
      case 1:
        _productsBloc.add(SearchInputChangedEvent(searchString: inputText));
      case 2:
        _foodBloc.add(SearchFoodInputChangedEvent(searchString: inputText));
    }
  }

  void _onQuickAddPressed() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) =>
          QuickAddBottomSheet(intakeType: _mealType.getIntakeType(), day: _day),
    );
  }

  void _onCustomAddButtonPressed(bool usesImperialUnits) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(S.of(context).createCustomDialogTitle),
          content: Text(S.of(context).createCustomDialogContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // close dialog
              child: Text(S.of(context).dialogCancelLabel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _openEditMealScreen(usesImperialUnits);
              },
              child: Text(S.of(context).buttonYesLabel),
            ),
          ],
        );
      },
    );
  }

  void _openEditMealScreen(bool usesImperialUnits) {
    Navigator.of(context).pushNamed(
      NavigationOptions.editMealRoute,
      arguments: EditMealScreenArguments(
        _day,
        MealEntity.empty(),
        _mealType.getIntakeType(),
        usesImperialUnits,
      ),
    );
  }
}

class AddMealScreenArguments {
  final AddMealType mealType;
  final DateTime day;

  /// Tab to open on instead of the default one (see [AddMealScreen.favoritesTab]).
  final int? initialTab;

  AddMealScreenArguments(this.mealType, this.day, {this.initialTab});
}
