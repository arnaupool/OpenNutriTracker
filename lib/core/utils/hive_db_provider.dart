import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/data/data_source/custom_activity_template_dbo.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/data/dbo/body_measurement_dbo.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/fasting_session_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/dbo/water_intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/features/diet_plan/data/diet_plan_dbo.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_entry_dbo.dart';
import 'package:opennutritracker/features/reminders/data/reminder_dbo.dart';
import 'package:opennutritracker/hive_registrar.g.dart';

class HiveDBProvider extends ChangeNotifier {
  static const configBoxName = 'ConfigBox';
  static const intakeBoxName = 'IntakeBox';
  static const userActivityBoxName = 'UserActivityBox';
  static const userBoxName = 'UserBox';
  static const trackedDayBoxName = 'TrackedDayBox';
  static const customMealBoxName = 'CustomMealBox';
  static const recipeBoxName = 'RecipeBox';
  static const cachedOffMealBoxName = 'CachedOffMealBox';
  // Sidecar to cachedOffMealBox: maps meal `code` -> millisSinceEpoch of
  // last "touch" (creation or user re-select). Used by the TTL sweep so
  // unused cache entries age out after 90 days.
  static const cachedOffMealTimestampsBoxName = 'CachedOffMealTimestampsBox';
  // #70 follow-up: saved Custom activity templates (name + typical kcal).
  static const customActivityTemplateBoxName = 'CustomActivityTemplateBox';
  static const weightLogBoxName = 'WeightLogBox';
  // #32: per-entry water intake log keyed by uuid; one row per sip so the
  // dialog's "undo last" can roll a single entry back without losing the
  // rest of the day.
  static const waterIntakeBoxName = 'WaterIntakeBox';
  // #84: persisted fasting sessions, one record per start. The data layer
  // intentionally keeps cancelled and completed sessions side by side with no
  // success/failure label on the record — see `FastingSessionDBO`.
  static const fastingBoxName = 'FastingBox';
  static const bodyMeasurementBoxName = 'BodyMeasurementBox';
  // FW-02: web has no filesystem, so user photos (recipes/meals/progress)
  // are stored as raw bytes here instead — see UserImageStorage. Opened
  // on every platform for simplicity; native ignores it and keeps using
  // files on disk.
  static const userImageBytesBoxName = 'UserImageBytesBox';
  // FAS-01: per-device sync bookkeeping (record fingerprints, pull cursor).
  // Never synced itself.
  static const syncStateBoxName = 'SyncStateBox';
  // FAS-04: planned meals (synced).
  static const mealPlanBoxName = 'MealPlanBox';
  // Diet plan with an end date and countdown (synced); a single record.
  static const dietPlanBoxName = 'DietPlanBox';
  // Reminders (keyed by id) and their settings (single record); both synced.
  static const reminderBoxName = 'ReminderBox';
  static const reminderSettingsBoxName = 'ReminderSettingsBox';

  late Box<ConfigDBO> configBox;
  late Box<IntakeDBO> intakeBox;
  late Box<UserActivityDBO> userActivityBox;
  late Box<UserDBO> userBox;
  late Box<TrackedDayDBO> trackedDayBox;
  late Box<MealDBO> customMealBox;
  late Box<RecipeDBO> recipeBox;
  late Box<MealDBO> cachedOffMealBox;
  late Box<int> cachedOffMealTimestampsBox;
  late Box<CustomActivityTemplateDBO> customActivityTemplateBox;
  late Box<WeightLogDBO> weightLogBox;
  late Box<WaterIntakeDBO> waterIntakeBox;
  late Box<FastingSessionDBO> fastingBox;
  late Box<BodyMeasurementDBO> bodyMeasurementBox;
  late Box<Uint8List> userImageBytesBox;
  late Box<dynamic> syncStateBox;
  late Box<MealPlanEntryDBO> mealPlanBox;
  late Box<DietPlanDBO> dietPlanBox;
  late Box<ReminderDBO> reminderBox;
  late Box<ReminderSettingsDBO> reminderSettingsBox;

  static bool _hiveReady = false;

  /// Every box a profile owns, by logical name (see [ProfileScope.box]).
  static const List<String> profileBoxNames = [
    configBoxName,
    intakeBoxName,
    userActivityBoxName,
    userBoxName,
    trackedDayBoxName,
    customMealBoxName,
    recipeBoxName,
    cachedOffMealBoxName,
    cachedOffMealTimestampsBoxName,
    customActivityTemplateBoxName,
    weightLogBoxName,
    waterIntakeBoxName,
    fastingBoxName,
    bodyMeasurementBoxName,
    userImageBytesBoxName,
    syncStateBoxName,
    mealPlanBoxName,
    dietPlanBoxName,
    reminderBoxName,
    reminderSettingsBoxName,
  ];

  /// Opens the active profile's boxes ([ProfileScope]). Safe to call again
  /// after [Hive.close] when switching profiles.
  Future<void> initHiveDB(Uint8List encryptionKey) async {
    final encryptionCypher = HiveAesCipher(encryptionKey);
    if (_hiveReady) {
      return _openBoxes(encryptionCypher);
    }
    _hiveReady = true;
    await Hive.initFlutter();
    // Delegate to the generated registrar so any new DBO type added to
    // the project is registered automatically on the next `just build`.
    // Registering by hand had drifted out of sync — `CaloriesProfileDBO`
    // (#7 on UserDBO) was missing, causing every save with a non-null
    // hormone profile to throw, which the previous broken async chains
    // swallowed silently. Result: profile reset to null on app relaunch.
    Hive.registerAdapters();
    // Hand-written adapter (see MealPlanEntryDBOAdapter), outside the
    // generated registrar.
    if (!Hive.isAdapterRegistered(MealPlanEntryDBO.hiveTypeId)) {
      Hive.registerAdapter(MealPlanEntryDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(DietPlanDBO.hiveTypeId)) {
      Hive.registerAdapter(DietPlanDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(ReminderDBO.hiveTypeId)) {
      Hive.registerAdapter(ReminderDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(ReminderSettingsDBO.hiveTypeId)) {
      Hive.registerAdapter(ReminderSettingsDBOAdapter());
    }
    await _openBoxes(encryptionCypher);
  }

  Future<void> _openBoxes(HiveAesCipher encryptionCypher) async {

    configBox = await Hive.openBox(
      ProfileScope.box(configBoxName),
      encryptionCipher: encryptionCypher,
    );
    intakeBox = await Hive.openBox(
      ProfileScope.box(intakeBoxName),
      encryptionCipher: encryptionCypher,
    );
    userActivityBox = await Hive.openBox(
      ProfileScope.box(userActivityBoxName),
      encryptionCipher: encryptionCypher,
    );
    userBox = await Hive.openBox(
      ProfileScope.box(userBoxName),
      encryptionCipher: encryptionCypher,
    );
    trackedDayBox = await Hive.openBox(
      ProfileScope.box(trackedDayBoxName),
      encryptionCipher: encryptionCypher,
    );
    customMealBox = await Hive.openBox(
      ProfileScope.box(customMealBoxName),
      encryptionCipher: encryptionCypher,
    );
    recipeBox = await Hive.openBox(
      ProfileScope.box(recipeBoxName),
      encryptionCipher: encryptionCypher,
    );
    cachedOffMealBox = await Hive.openBox(
      ProfileScope.box(cachedOffMealBoxName),
      encryptionCipher: encryptionCypher,
    );
    cachedOffMealTimestampsBox = await Hive.openBox(
      ProfileScope.box(cachedOffMealTimestampsBoxName),
      encryptionCipher: encryptionCypher,
    );
    customActivityTemplateBox = await Hive.openBox(
      ProfileScope.box(customActivityTemplateBoxName),
      encryptionCipher: encryptionCypher,
    );
    weightLogBox = await Hive.openBox(
      ProfileScope.box(weightLogBoxName),
      encryptionCipher: encryptionCypher,
    );
    waterIntakeBox = await Hive.openBox(
      ProfileScope.box(waterIntakeBoxName),
      encryptionCipher: encryptionCypher,
    );
    fastingBox = await Hive.openBox(
      ProfileScope.box(fastingBoxName),
      encryptionCipher: encryptionCypher,
    );
    bodyMeasurementBox = await Hive.openBox(
      ProfileScope.box(bodyMeasurementBoxName),
      encryptionCipher: encryptionCypher,
    );
    userImageBytesBox = await Hive.openBox(
      ProfileScope.box(userImageBytesBoxName),
      encryptionCipher: encryptionCypher,
    );
    syncStateBox = await Hive.openBox(
      ProfileScope.box(syncStateBoxName),
      encryptionCipher: encryptionCypher,
    );
    mealPlanBox = await Hive.openBox(
      ProfileScope.box(mealPlanBoxName),
      encryptionCipher: encryptionCypher,
    );
    dietPlanBox = await Hive.openBox(
      ProfileScope.box(dietPlanBoxName),
      encryptionCipher: encryptionCypher,
    );
    reminderBox = await Hive.openBox(
      ProfileScope.box(reminderBoxName),
      encryptionCipher: encryptionCypher,
    );
    reminderSettingsBox = await Hive.openBox(
      ProfileScope.box(reminderSettingsBoxName),
      encryptionCipher: encryptionCypher,
    );
  }

  static List<int> generateNewHiveEncryptionKey() => Hive.generateSecureKey();
}
