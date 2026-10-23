import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_data_source.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/presentation/main_screen.dart';
import 'package:opennutritracker/core/presentation/widgets/responsive_layout.dart';
import 'package:opennutritracker/core/presentation/widgets/image_full_screen.dart';
import 'package:opennutritracker/core/styles/color_schemes.dart';
import 'package:opennutritracker/core/styles/fonts.dart';
import 'package:opennutritracker/core/utils/env.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/logger_config.dart';
import 'package:opennutritracker/core/utils/notification_service.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/locale_provider.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/theme_mode_provider.dart';
import 'package:opennutritracker/features/activity_detail/activity_detail_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_item_menu_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/magic_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/review_meal_screen.dart';
import 'package:opennutritracker/features/scanner/presentation/scan_label_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/presets_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/recently_screen.dart';
import 'package:opennutritracker/features/add_activity/presentation/add_activity_screen.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/onboarding/onboarding_screen.dart';
import 'package:opennutritracker/features/fasting/presentation/fasting_screen.dart';
import 'package:opennutritracker/features/profile/presentation/weight_history_screen.dart';
import 'package:opennutritracker/features/profile/presentation/body_measurements_screen.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/import_recipe_scanner_screen.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipe_builder_screen.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipes_page.dart';
import 'package:opennutritracker/features/home/presentation/screens/import_activity_scanner_screen.dart';
import 'package:opennutritracker/features/home/presentation/screens/import_meal_scanner_screen.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/features/review/presentation/review_page.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/accent_colour_screen.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/open_router_settings_screen.dart';
import 'package:opennutritracker/features/settings/settings_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LoggerConfig.intiLogger();
  await initLocator();

  // Drop cached remote-search results that haven't been touched in 90
  // days. Done once per app start; no need to schedule a recurring task.
  unawaited(
    locator<RemoteSearchCacheDataSource>().pruneStale(const Duration(days: 90)),
  );

  final isUserInitialized = await locator<UserDataSource>().hasUserData();
  // FAS-01: starts syncing if this device is linked; a no-op otherwise.
  if (isUserInitialized) unawaited(locator<SyncService>().start());
  final configRepo = locator<ConfigRepository>();

  final config = await configRepo.getConfig();
  final savedLocaleCode = await configRepo.getSelectedLocale();
  final savedLocale = savedLocaleCode != null ? Locale(savedLocaleCode) : null;

  // #312: Restore scheduled notifications after app start / device reboot.
  // Load the user's localized strings first — there's no widget tree yet, so
  // S is driven directly off the saved (or device) locale. Android re-applies
  // the channel name/description on every (re)registration, and they surface
  // in the OS settings, so this keeps them in the user's language instead of
  // reverting to English on each launch.
  if (config.notificationsEnabled) {
    await S.load(
      savedLocale ?? WidgetsBinding.instance.platformDispatcher.locale,
    );
    final s = S.current;
    final notificationService = locator<NotificationService>();
    await notificationService.initialize();
    await notificationService.scheduleDailyReminder(
      hour: config.notificationHour,
      minute: config.notificationMinute,
      title: s.notificationsDailyReminderTitle,
      body: s.notificationsDailyReminderBody,
      channelName: s.notificationsDailyReminderChannelName,
      channelDescription: s.notificationsDailyReminderChannelDescription,
    );
  }
  final hasAcceptedAnonymousData = await configRepo
      .getConfigHasAcceptedAnonymousData();
  final savedAppTheme = await configRepo.getConfigAppTheme();
  final savedUsesKilojoules = config.usesKilojoules;
  final savedUseMaterialYou = config.useMaterialYou;
  final savedAccentColor = config.accentColor;
  final log = Logger('main');

  // If the user has accepted anonymous data collection, run the app with
  // sentry enabled, else run without it
  if (kReleaseMode && hasAcceptedAnonymousData) {
    log.info('Starting App with Sentry enabled ...');
    _runAppWithSentryReporting(
      isUserInitialized,
      savedAppTheme,
      savedLocale,
      savedUsesKilojoules,
      savedUseMaterialYou,
      savedAccentColor,
    );
  } else {
    log.info('Starting App ...');
    runAppWithChangeNotifiers(
      isUserInitialized,
      savedAppTheme,
      savedLocale,
      savedUsesKilojoules,
      savedUseMaterialYou,
      savedAccentColor,
    );
  }
}

void _runAppWithSentryReporting(
  bool isUserInitialized,
  AppThemeEntity savedAppTheme,
  Locale? savedLocale,
  bool savedUsesKilojoules,
  bool savedUseMaterialYou,
  int? savedAccentColor,
) async {
  await SentryFlutter.init(
    (options) {
      options.dsn = Env.sentryDns;
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => runAppWithChangeNotifiers(
      isUserInitialized,
      savedAppTheme,
      savedLocale,
      savedUsesKilojoules,
      savedUseMaterialYou,
      savedAccentColor,
    ),
  );
}

void runAppWithChangeNotifiers(
  bool userInitialized,
  AppThemeEntity savedAppTheme,
  Locale? savedLocale,
  bool savedUsesKilojoules,
  bool savedUseMaterialYou,
  int? savedAccentColor,
) => runApp(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => ThemeModeProvider(
          appTheme: savedAppTheme,
          useMaterialYou: savedUseMaterialYou,
          accentColor: savedAccentColor,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => LocaleProvider(locale: savedLocale),
      ),
      ChangeNotifierProvider(
        create: (_) => EnergyUnitProvider(usesKilojoules: savedUsesKilojoules),
      ),
    ],
    child: OpenNutriTrackerApp(userInitialized: userInitialized),
  ),
);

class OpenNutriTrackerApp extends StatelessWidget {
  final bool userInitialized;

  const OpenNutriTrackerApp({super.key, required this.userInitialized});

  @override
  Widget build(BuildContext context) {
    // #415: DynamicColorBuilder hands back null on platforms that don't
    // support wallpaper-derived colours (iOS, older Android, desktop test
    // builds), so the static palette always remains as a graceful fallback.
    final themeProvider = Provider.of<ThemeModeProvider>(context);
    final useMaterialYou = themeProvider.useMaterialYou;
    final accentColor = themeProvider.accentColor;
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final ColorScheme lightScheme;
        final ColorScheme darkScheme;
        if (useMaterialYou && lightDynamic != null && darkDynamic != null) {
          lightScheme = lightDynamic.harmonized();
          darkScheme = darkDynamic.harmonized();
        } else if (accentColor != null) {
          final seed = Color(accentColor);
          lightScheme = withNeutralSurfaces(ColorScheme.fromSeed(seedColor: seed));
          darkScheme = withNeutralSurfaces(
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
          );
        } else {
          lightScheme = withNeutralSurfaces(lightColorScheme);
          darkScheme = withNeutralSurfaces(darkColorScheme);
        }
        return _buildMaterialApp(context, lightScheme, darkScheme);
      },
    );
  }

  Widget _buildMaterialApp(
    BuildContext context,
    ColorScheme lightScheme,
    ColorScheme darkScheme,
  ) {
    return MaterialApp(
      onGenerateTitle: (context) => S.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        textTheme: appTextTheme,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        textTheme: appTextTheme,
      ),
      themeMode: Provider.of<ThemeModeProvider>(context).themeMode,
      locale: Provider.of<LocaleProvider>(context).locale,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      initialRoute: userInitialized
          ? NavigationOptions.mainRoute
          : NavigationOptions.onboardingRoute,
      routes: {
        NavigationOptions.mainRoute: (context) => const MainScreen(),
        NavigationOptions.onboardingRoute: (context) =>
            DesktopRouteFrame(child: const OnboardingScreen()),
        NavigationOptions.settingsRoute: (context) =>
            DesktopRouteFrame(child: const SettingsScreen()),
        NavigationOptions.accentColourRoute: (context) =>
            DesktopRouteFrame(child: const AccentColourScreen()),
        NavigationOptions.openRouterSettingsRoute: (context) =>
            DesktopRouteFrame(child: const OpenRouterSettingsScreen()),
        NavigationOptions.addMealRoute: (context) =>
            DesktopRouteFrame(child: const AddMealScreen()),
        NavigationOptions.addItemMenuRoute: (context) =>
            DesktopRouteFrame(child: const AddItemMenuScreen()),
        NavigationOptions.recentlyRoute: (context) =>
            DesktopRouteFrame(child: const RecentlyScreen()),
        NavigationOptions.presetsRoute: (context) =>
            DesktopRouteFrame(child: const PresetsScreen()),
        NavigationOptions.magicRoute: (context) =>
            DesktopRouteFrame(child: const MagicScreen()),
        NavigationOptions.reviewMealRoute: (context) =>
            DesktopRouteFrame(child: const ReviewMealScreen()),
        NavigationOptions.scannerRoute: (context) =>
            DesktopRouteFrame(child: const ScannerScreen()),
        NavigationOptions.scanLabelRoute: (context) =>
            DesktopRouteFrame(child: const ScanLabelScreen()),
        NavigationOptions.mealDetailRoute: (context) =>
            DesktopRouteFrame(child: const MealDetailScreen()),
        NavigationOptions.editMealRoute: (context) =>
            DesktopRouteFrame(child: const EditMealScreen()),
        NavigationOptions.addActivityRoute: (context) =>
            DesktopRouteFrame(child: const AddActivityScreen()),
        NavigationOptions.activityDetailRoute: (context) =>
            DesktopRouteFrame(child: const ActivityDetailScreen()),
        NavigationOptions.imageFullScreenRoute: (context) =>
            const ImageFullScreen(),
        NavigationOptions.importMealScannerRoute: (context) =>
            DesktopRouteFrame(child: const ImportMealScannerScreen()),
        NavigationOptions.importActivityScannerRoute: (context) =>
            DesktopRouteFrame(child: const ImportActivityScannerScreen()),
        NavigationOptions.recipesRoute: (context) =>
            DesktopRouteFrame(child: const RecipesPage()),
        NavigationOptions.recipeBuilderRoute: (context) =>
            DesktopRouteFrame(child: const RecipeBuilderScreen()),
        NavigationOptions.recipeDetailRoute: (context) =>
            DesktopRouteFrame(child: const RecipeDetailScreen()),
        NavigationOptions.importRecipeScannerRoute: (context) =>
            DesktopRouteFrame(child: const ImportRecipeScannerScreen()),
        NavigationOptions.weightHistoryRoute: (context) =>
            DesktopRouteFrame(child: const WeightHistoryScreen()),
        NavigationOptions.bodyMeasurementsRoute: (context) =>
            DesktopRouteFrame(child: const BodyMeasurementsScreen()),
        // FAS-03: full width on desktop, the tables need the room.
        NavigationOptions.reviewRoute: (context) => const ReviewScreen(),
        NavigationOptions.fastingRoute: (context) =>
            DesktopRouteFrame(child: const FastingScreen()),
      },
    );
  }
}
