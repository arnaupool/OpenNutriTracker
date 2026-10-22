import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/add_item_bottom_sheet.dart';
import 'package:opennutritracker/core/presentation/widgets/responsive_layout.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/diary/diary_page.dart';
import 'package:opennutritracker/core/presentation/widgets/home_appbar.dart';
import 'package:opennutritracker/features/home/home_page.dart';
import 'package:opennutritracker/core/presentation/widgets/main_appbar.dart';
import 'package:opennutritracker/features/profile/profile_page.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipes_page.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/custom_meals_bloc.dart';
import 'package:opennutritracker/features/strategy/presentation/strategy_page.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/appearance_sheet.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedPageIndex = 0;

  late List<Widget> _bodyPages;
  late List<PreferredSizeWidget> _appbarPages;

  @override
  void didChangeDependencies() {
    _bodyPages = [
      const HomePage(),
      const DiaryPage(),
      const RecipesPage(),
      const StrategyPage(),
      const ProfilePage(),
    ];
    _appbarPages = [
      const HomeAppbar(),
      MainAppbar(title: S.of(context).diaryLabel, iconData: Icons.book),
      AppBar(
        leading: const Icon(Icons.menu_book),
        title: Text(S.of(context).recipesLabel),
        actions: [
          PopupMenuButton<_RecipesAction>(
            tooltip: S.of(context).addLabel,
            icon: const Icon(Icons.add),
            onSelected: (action) => _onRecipesAddSelected(context, action),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _RecipesAction.newRecipe,
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_outlined),
                    const SizedBox(width: 12),
                    Text(S.of(context).createRecipeTitle),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _RecipesAction.newCustomMeal,
                child: Row(
                  children: [
                    const Icon(Icons.restaurant_outlined),
                    const SizedBox(width: 12),
                    Text(S.of(context).newCustomMealLabel),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _RecipesAction.importRecipe,
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner_outlined),
                    const SizedBox(width: 12),
                    Text(S.of(context).importRecipeLabel),
                  ],
                ),
              ),
            ],
          ),
          const AppearanceButton(),
          IconButton(
            tooltip: S.of(context).settingsLabel,
            onPressed: () => Navigator.of(
              context,
            ).pushNamed(NavigationOptions.settingsRoute),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      MainAppbar(title: S.of(context).strategyLabel, iconData: Icons.bar_chart),
      MainAppbar(
        title: S.of(context).profileLabel,
        iconData: Icons.account_circle,
      ),
    ];
    super.didChangeDependencies();
  }

  /// The five main tabs. Shared by the phone bottom bar and the desktop
  /// side rail so both keep the same order, icons and test ids.
  List<({String id, IconData icon, IconData selectedIcon, String label})> _destinations(BuildContext context) => [
    (id: 'nav-home', icon: Icons.home_outlined, selectedIcon: Icons.home, label: S.of(context).homeLabel),
    (id: 'nav-diary', icon: Icons.book_outlined, selectedIcon: Icons.book, label: S.of(context).diaryLabel),
    (
      id: 'nav-recipes',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
      label: S.of(context).recipesLabel,
    ),
    (
      id: 'nav-strategy',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: S.of(context).strategyLabel,
    ),
    (
      id: 'nav-profile',
      icon: Icons.account_circle_outlined,
      selectedIcon: Icons.account_circle,
      label: S.of(context).profileLabel,
    ),
  ];

  Widget? _fab(BuildContext context) => _selectedPageIndex == 0
      ? Semantics(
          identifier: 'fab-add-item',
          child: FloatingActionButton(
            onPressed: () => _onFabPressed(context),
            tooltip: S.of(context).addLabel,
            child: const Icon(Icons.add),
          ),
        )
      : null;

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations(context);
    final width = MediaQuery.sizeOf(context).width;

    // FAS-02: on a desktop-width window the bottom bar becomes a side rail
    // and the page is centered at a readable maximum width.
    if (width >= ResponsiveLayout.wide) {
      final extended = width >= ResponsiveLayout.extendedRail;
      return Scaffold(
        appBar: _appbarPages[_selectedPageIndex],
        floatingActionButton: _fab(context),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedPageIndex,
              onDestinationSelected: _setPage,
              extended: extended,
              labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              destinations: [
                for (var i = 0; i < destinations.length; i++)
                  NavigationRailDestination(
                    icon: Semantics(identifier: destinations[i].id, child: Icon(destinations[i].icon)),
                    selectedIcon: Semantics(identifier: destinations[i].id, child: Icon(destinations[i].selectedIcon)),
                    label: Text(destinations[i].label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: MaxWidthBox(
                maxWidth: ResponsiveLayout.maxContentWidth,
                child: _bodyPages[_selectedPageIndex],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _appbarPages[_selectedPageIndex],
      body: _bodyPages[_selectedPageIndex],
      floatingActionButton: _fab(context),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedPageIndex,
        onDestinationSelected: _setPage,
        destinations: [
          for (var i = 0; i < destinations.length; i++)
            NavigationDestination(
              icon: Semantics(
                identifier: destinations[i].id,
                child: Icon(_selectedPageIndex == i ? destinations[i].selectedIcon : destinations[i].icon),
              ),
              label: destinations[i].label,
            ),
        ],
      ),
    );
  }

  void _setPage(int selectedIndex) {
    setState(() {
      _selectedPageIndex = selectedIndex;
    });
  }

  Future<void> _onRecipesAddSelected(
    BuildContext context,
    _RecipesAction action,
  ) async {
    switch (action) {
      case _RecipesAction.newRecipe:
        await Navigator.of(
          context,
        ).pushNamed(NavigationOptions.recipeBuilderRoute);
        locator<RecipesBloc>().add(const LoadRecipesEvent());
      case _RecipesAction.newCustomMeal:
        await Navigator.of(context).pushNamed(
          NavigationOptions.editMealRoute,
          arguments: EditMealScreenArguments(
            DateTime.now(),
            MealEntity.empty(),
            IntakeTypeEntity.breakfast,
            false,
            editOnly: true,
          ),
        );
        locator<CustomMealsBloc>().add(LoadCustomMealsEvent());
      case _RecipesAction.importRecipe:
        await Navigator.of(
          context,
        ).pushNamed(NavigationOptions.importRecipeScannerRoute);
        // The scanner screen itself dispatches LoadRecipesEvent on success,
        // but cover the cancel-then-reopen flow here too.
        locator<RecipesBloc>().add(const LoadRecipesEvent());
    }
  }

  Future<void> _onFabPressed(BuildContext context) async {
    final config = await locator<GetConfigUsecase>().getConfig();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
      ),
      builder: (BuildContext context) {
        return AddItemBottomSheet(
          day: DateTime.now(),
          showActivityTracking: config.showActivityTracking,
        );
      },
    );
  }
}

enum _RecipesAction { newRecipe, newCustomMeal, importRecipe }
