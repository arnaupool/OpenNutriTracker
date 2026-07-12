import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// FR-02: the entry point reached after picking a meal type (Breakfast /
/// Lunch / Dinner / Snack) from [AddItemBottomSheet]. Clones XMihura's
/// reference "Add new Item" menu 1:1 — Magic, Search, Scan Product,
/// Recently, Presets — replacing the old direct-to-search-tabs landing.
/// Each option is a separate screen; this one only routes.
class AddItemMenuScreen extends StatelessWidget {
  const AddItemMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as AddMealScreenArguments;
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(args.mealType.getTypeName(context))),
      body: ListView(
        children: [
          _MenuTile(
            identifier: 'add-item-menu-magic',
            icon: Icons.auto_awesome_outlined,
            title: s.addItemMenuMagicLabel,
            subtitle: s.addItemMenuMagicSubtitle,
            onTap: () => Navigator.of(
              context,
            ).pushNamed(NavigationOptions.magicRoute, arguments: args),
          ),
          const Divider(indent: 16, endIndent: 16),
          _MenuTile(
            identifier: 'add-item-menu-search',
            icon: Icons.search_outlined,
            title: s.addItemMenuSearchLabel,
            subtitle: s.addItemMenuSearchSubtitle,
            onTap: () => Navigator.of(
              context,
            ).pushNamed(NavigationOptions.addMealRoute, arguments: args),
          ),
          _MenuTile(
            identifier: 'add-item-menu-scan-product',
            icon: Icons.qr_code_scanner_outlined,
            title: s.addItemMenuScanProductLabel,
            subtitle: s.addItemMenuScanProductSubtitle,
            onTap: () => Navigator.of(context).pushNamed(
              NavigationOptions.scannerRoute,
              arguments: ScannerScreenArguments(
                args.day,
                args.mealType.getIntakeType(),
              ),
            ),
          ),
          _MenuTile(
            identifier: 'add-item-menu-recently',
            icon: Icons.history_outlined,
            title: s.addItemMenuRecentlyLabel,
            subtitle: s.addItemMenuRecentlySubtitle,
            onTap: () => Navigator.of(
              context,
            ).pushNamed(NavigationOptions.recentlyRoute, arguments: args),
          ),
          _MenuTile(
            identifier: 'add-item-menu-presets',
            icon: Icons.playlist_add_check_outlined,
            title: s.addItemMenuPresetsLabel,
            subtitle: s.addItemMenuPresetsSubtitle,
            onTap: () => Navigator.of(
              context,
            ).pushNamed(NavigationOptions.presetsRoute, arguments: args),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String identifier;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.identifier,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
