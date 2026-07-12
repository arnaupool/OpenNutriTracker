import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/error_dialog.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/no_results_widget.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/custom_meals_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// FR-02/FR-03: "Presets" option from [AddItemMenuScreen] — the user's saved
/// custom meals ([CustomMealsBloc]/`CustomMealBox`) plus multi-ingredient
/// combos saved via Review meal's "Save as preset" ([RecipeRepository]/
/// `RecipeBox` — the data model that actually supports a list of
/// ingredients), merged into one list. Reuses [MealItemCard] (same as
/// Recently/Search) so tapping an entry goes straight to [MealDetailScreen]
/// rather than the edit form [CustomMealsTab] in Settings uses for managing
/// the templates themselves.
class PresetsScreen extends StatefulWidget {
  final GetConfigUsecase? getConfigUsecase;
  final RecipeRepository? recipeRepository;

  const PresetsScreen({super.key, this.getConfigUsecase, this.recipeRepository});

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> {
  late final CustomMealsBloc _customMealsBloc = locator<CustomMealsBloc>();
  late final GetConfigUsecase _getConfigUsecase =
      widget.getConfigUsecase ?? locator<GetConfigUsecase>();
  late final RecipeRepository _recipeRepository =
      widget.recipeRepository ?? locator<RecipeRepository>();
  late AddMealScreenArguments _args;

  bool _usesImperialUnits = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _args =
        ModalRoute.of(context)?.settings.arguments as AddMealScreenArguments;
  }

  @override
  void initState() {
    super.initState();
    _customMealsBloc.add(LoadCustomMealsEvent());
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final config = await _getConfigUsecase.getConfig();
    if (!mounted) return;
    setState(() => _usesImperialUnits = config.usesImperialUnits);
  }

  void _onRefreshPressed() {
    _customMealsBloc.add(LoadCustomMealsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).addItemMenuPresetsLabel)),
      body: BlocBuilder<CustomMealsBloc, CustomMealsState>(
        bloc: _customMealsBloc,
        builder: (context, state) {
          if (state is CustomMealsLoadingState || state is CustomMealsInitial) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is CustomMealsLoadedState) {
            final List<MealEntity> meals = [
              ...state.meals,
              ..._recipeRepository.getAllRecipes().map((r) => r.toMealEntity()),
            ];
            if (meals.isEmpty) {
              return const NoResultsWidget();
            }
            return Semantics(
              identifier: 'presets-list',
              child: ListView.builder(
                itemCount: meals.length,
                itemBuilder: (context, index) => MealItemCard(
                  day: _args.day,
                  mealEntity: meals[index],
                  addMealType: _args.mealType,
                  usesImperialUnits: _usesImperialUnits,
                ),
              ),
            );
          } else if (state is CustomMealsFailedState) {
            return ErrorDialog(
              errorText: S.of(context).errorFetchingProductData,
              onRefreshPressed: _onRefreshPressed,
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
