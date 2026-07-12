import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/presentation/widgets/error_dialog.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/recent_meal_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/no_results_widget.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// FR-02: "Recently" option from [AddItemMenuScreen] — extracted from what
/// used to be the third tab on the search screen, now a standalone
/// destination matching the reference menu.
class RecentlyScreen extends StatefulWidget {
  const RecentlyScreen({super.key});

  @override
  State<RecentlyScreen> createState() => _RecentlyScreenState();
}

class _RecentlyScreenState extends State<RecentlyScreen> {
  late final RecentMealBloc _recentMealBloc = locator<RecentMealBloc>();
  late AddMealScreenArguments _args;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _args =
        ModalRoute.of(context)?.settings.arguments as AddMealScreenArguments;
  }

  void _onRefreshPressed() {
    _recentMealBloc.add(const LoadRecentMealEvent(searchString: ""));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).addItemMenuRecentlyLabel)),
      body: BlocBuilder<RecentMealBloc, RecentMealState>(
        bloc: _recentMealBloc,
        builder: (context, state) {
          if (state is RecentMealInitial) {
            _recentMealBloc.add(const LoadRecentMealEvent(searchString: ""));
            return const Center(child: CircularProgressIndicator());
          } else if (state is RecentMealLoadingState) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is RecentMealLoadedState) {
            if (state.recentMeals.isEmpty) {
              return const NoResultsWidget();
            }
            return Semantics(
              identifier: 'recently-list',
              child: ListView.builder(
                itemCount: state.recentMeals.length,
                itemBuilder: (context, index) => MealItemCard(
                  day: _args.day,
                  mealEntity: state.recentMeals[index],
                  addMealType: _args.mealType,
                  usesImperialUnits: state.usesImperialUnits,
                ),
              ),
            );
          } else if (state is RecentMealFailedState) {
            return ErrorDialog(
              errorText: S.of(context).noMealsRecentlyAddedLabel,
              onRefreshPressed: _onRefreshPressed,
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
