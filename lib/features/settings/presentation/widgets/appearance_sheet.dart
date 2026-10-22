import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/core/utils/theme_mode_provider.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/accent_colour_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Palette button for the main app bars. Opens [AppearanceSheet], so theme
/// mode and accent colour are one tap away instead of buried in Settings.
class AppearanceButton extends StatelessWidget {
  const AppearanceButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'appbar-appearance',
      child: IconButton(
        tooltip: S.of(context).appearanceTitle,
        icon: const Icon(Icons.palette_outlined),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          constraints: const BoxConstraints(maxWidth: 560),
          builder: (_) => const AppearanceSheet(),
        ),
      ),
    );
  }
}

/// Theme mode (system / light / dark) and accent swatches, applied live.
/// The full hue picker stays on the accent colour screen.
class AppearanceSheet extends StatelessWidget {
  const AppearanceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Provider.of<ThemeModeProvider>(context);
    final settings = locator<SettingsBloc>();
    final colors = Theme.of(context).colorScheme;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final current = isAndroid && theme.useMaterialYou ? null : theme.accentColor;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.appearanceTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(l10n.settingsThemeLabel, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Semantics(
              identifier: 'appearance-theme-mode',
              child: SegmentedButton<AppThemeEntity>(
                segments: [
                  ButtonSegment(
                    value: AppThemeEntity.system,
                    icon: const Icon(Icons.brightness_auto_outlined),
                    label: Text(l10n.settingsThemeSystemDefaultLabel),
                  ),
                  ButtonSegment(
                    value: AppThemeEntity.light,
                    icon: const Icon(Icons.light_mode_outlined),
                    label: Text(l10n.settingsThemeLightLabel),
                  ),
                  ButtonSegment(
                    value: AppThemeEntity.dark,
                    icon: const Icon(Icons.dark_mode_outlined),
                    label: Text(l10n.settingsThemeDarkLabel),
                  ),
                ],
                selected: {theme.appTheme},
                onSelectionChanged: (selection) {
                  final mode = selection.first;
                  settings.setAppTheme(mode);
                  theme.updateTheme(mode);
                  settings.add(LoadSettingsEvent());
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.settingsAccentColourTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (i, color) in accentPresetColors.indexed)
                  Semantics(
                    identifier: 'appearance-accent-${i.toString().padLeft(2, '0')}',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        final argb = color.toARGB32();
                        settings.setAccentColor(argb);
                        settings.setUseMaterialYou(false);
                        theme.updateAccentColor(argb);
                        theme.updateUseMaterialYou(false);
                        settings.add(LoadSettingsEvent());
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: current == color.toARGB32()
                              ? Border.all(color: colors.onSurface, width: 3)
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              identifier: 'appearance-more-colours',
              child: TextButton.icon(
                icon: const Icon(Icons.colorize_outlined),
                label: Text(l10n.settingsAccentCustomColour),
                onPressed: () {
                  Navigator.of(context)
                    ..pop()
                    ..pushNamed(NavigationOptions.accentColourRoute);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
