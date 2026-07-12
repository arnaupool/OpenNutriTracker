import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/error_dialog.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/no_results_widget.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/custom_meals_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// FR-02: "Presets" option from [AddItemMenuScreen] — the user's saved
/// custom meals ([CustomMealsBloc]/`CustomMealBox`), one tap away from being
/// logged again. Reuses [MealItemCard] (same as Recently/Search) so tapping
/// a preset goes straight to [MealDetailScreen] rather than the edit form
/// [CustomMealsTab] in Settings uses for managing the templates themselves.
class PresetsScreen extends StatefulWidget {
  final GetConfigUsecase? getConfigUsecase;

  const PresetsScreen({super.key, this.getConfigUsecase});

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> {
  late final CustomMealsBloc _customMealsBloc = locator<CustomMealsBloc>();
  late final GetConfigUsecase _getConfigUsecase =
      widget.getConfigUsecase ?? locator<GetConfigUsecase>();
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
            if (state.meals.isEmpty) {
              return const NoResultsWidget();
            }
            return Semantics(
              identifier: 'presets-list',
              child: ListView.builder(
                itemCount: state.meals.length,
                itemBuilder: (context, index) => MealItemCard(
                  day: _args.day,
                  mealEntity: state.meals[index],
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
