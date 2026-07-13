import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_weight_log_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_activity/presentation/add_activity_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:opennutritracker/features/profile/presentation/widgets/set_weight_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';

class AddItemBottomSheet extends StatelessWidget {
  final DateTime day;
  final bool showActivityTracking;
  final GetUserUsecase? getUserUsecase;
  final ConfigRepository? configRepository;
  final AddWeightLogUsecase? addWeightLogUsecase;
  final ProfileBloc? profileBloc;

  const AddItemBottomSheet({
    super.key,
    required this.day,
    this.showActivityTracking = true,
    this.getUserUsecase,
    this.configRepository,
    this.addWeightLogUsecase,
    this.profileBloc,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              S.of(context).addItemLabel,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Semantics(
            identifier: 'add-item-weight',
            child: ListTile(
              title: Text(
                S.of(context).weightLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                S.of(context).addItemWeightExample,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              // ignore: sized_box_for_whitespace
              leading: Container(
                height: double.infinity,
                child: Icon(
                  Icons.monitor_weight_outlined,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              onTap: () => _logWeight(context),
            ),
          ),
          Semantics(
            identifier: 'add-item-body-measurements',
            child: ListTile(
              title: Text(
                S.of(context).profileBodyMeasurementsTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                S.of(context).addItemBodyMeasurementsExample,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              // ignore: sized_box_for_whitespace
              leading: Container(
                height: double.infinity,
                child: Icon(
                  Icons.straighten_outlined,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              onTap: () => _showBodyMeasurementsScreen(context),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          if (showActivityTracking) ...[
            Semantics(
              identifier: 'add-item-activity',
              child: ListTile(
                title: Text(
                  S.of(context).activityLabel,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  S.of(context).activityExample,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                // ignore: sized_box_for_whitespace
                leading: Container(
                  height: double.infinity,
                  child: Icon(
                    UserActivityEntity.getIconData(),
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                onTap: () {
                  _showAddActivityScreen(context);
                },
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
          ],
          Semantics(
            identifier: 'add-item-breakfast',
            child: ListTile(
              title: Text(
                S.of(context).breakfastLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                S.of(context).breakfastExample,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              // ignore: sized_box_for_whitespace
              leading: Container(
                height: double.infinity,
                child: Icon(IntakeTypeEntity.breakfast.getIconData()),
              ),
              onTap: () {
                _showAddItemScreen(context, AddMealType.breakfastType);
              },
            ),
          ),
          Semantics(
            identifier: 'add-item-lunch',
            child: ListTile(
              title: Text(
                S.of(context).lunchLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                S.of(context).lunchExample,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              // ignore: sized_box_for_whitespace
              leading: Container(
                height: double.infinity,
                child: Icon(IntakeTypeEntity.lunch.getIconData()),
              ),
              onTap: () {
                _showAddItemScreen(context, AddMealType.lunchType);
              },
            ),
          ),
          Semantics(
            identifier: 'add-item-dinner',
            child: ListTile(
              title: Text(
                S.of(context).dinnerLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                S.of(context).dinnerExample,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              // ignore: sized_box_for_whitespace
              leading: Container(
                height: double.infinity,
                child: Icon(IntakeTypeEntity.dinner.getIconData()),
              ),
              onTap: () {
                _showAddItemScreen(context, AddMealType.dinnerType);
              },
            ),
          ),
          Semantics(
            identifier: 'add-item-snack',
            child: ListTile(
              title: Text(
                S.of(context).snackLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                S.of(context).snackExample,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              // ignore: sized_box_for_whitespace
              leading: Container(
                height: double.infinity,
                child: Icon(IntakeTypeEntity.snack.getIconData()),
              ),
              onTap: () {
                _showAddItemScreen(context, AddMealType.snackType);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddItemScreen(BuildContext context, AddMealType itemType) {
    Navigator.of(context).pop(); // Close bottom sheet
    Navigator.of(context).pushNamed(
      NavigationOptions.addItemMenuRoute,
      arguments: AddMealScreenArguments(itemType, day),
    );
  }

  void _showAddActivityScreen(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(
      NavigationOptions.addActivityRoute,
      arguments: AddActivityScreenArguments(day: day),
    );
  }

  /// Unlike Weight, measurements are a multi-field (7 optional metrics)
  /// entry that benefits from seeing prior readings while filling it in —
  /// so this opens the full Body Measurements screen (same one reachable
  /// from Profile) rather than a standalone quick dialog. Its own FAB
  /// already prefills from the last entry, so the extra tap here isn't a
  /// meaningfully bigger ask than a dedicated quick-add would be.
  void _showBodyMeasurementsScreen(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(NavigationOptions.bodyMeasurementsRoute);
  }

  /// Unlike the quick pencil-edit on the home header (which only updates
  /// `UserEntity.weightKG`), this goes through `AddWeightLogUsecase` so the
  /// entry actually lands in the weight history / Strategy trend chart —
  /// that's the point of surfacing it from the "Add item" menu.
  ///
  /// The fetch happens *before* popping the bottom sheet, and the dialog
  /// opens immediately (no `await`) after the pop — a pop followed by an
  /// awaited gap on the same (about-to-be-disposed) context leaves it
  /// deactivated by the time execution resumes.
  Future<void> _logWeight(BuildContext context) async {
    final userUsecase = getUserUsecase ?? locator<GetUserUsecase>();
    final config = await (configRepository ?? locator<ConfigRepository>())
        .getConfig();
    final user = await userUsecase.getUserData();
    if (!context.mounted) return;

    final displayWeight = config.usesImperialUnits
        ? UnitCalc.kgToLbs(user.weightKG)
        : user.weightKG;

    Navigator.of(context).pop(); // Close bottom sheet
    // The bottom sheet's context is intentionally defunct from here on —
    // showDialog already resolved its own Navigator at call time, and
    // nothing below touches `context` again, so there's no `mounted` gate
    // to check on this pop-and-forget widget.
    final newWeight = await showDialog<double>(
      context: context,
      builder: (context) => SetWeightDialog(
        userWeight: displayWeight,
        usesImperialUnits: config.usesImperialUnits,
      ),
    );
    if (newWeight == null) return;

    final newWeightKg = config.usesImperialUnits
        ? UnitCalc.lbsToKg(newWeight)
        : newWeight;
    await (addWeightLogUsecase ?? locator<AddWeightLogUsecase>()).addEntry(
      WeightLogEntity(
        date: DateTime(day.year, day.month, day.day),
        weightKg: newWeightKg,
      ),
    );

    // AddWeightLogUsecase already persisted the user's new current weight
    // when the entry is for today; route through ProfileBloc so Home,
    // Diary, and Profile all refresh the same way the header's quick-edit
    // does instead of going stale until their next manual reload.
    final updatedUser = await userUsecase.getUserData();
    await (profileBloc ?? locator<ProfileBloc>()).updateUser(updatedUser);
  }
}
