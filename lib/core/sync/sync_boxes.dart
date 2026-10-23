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
import 'package:opennutritracker/core/sync/synced_box.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_entry_dbo.dart';

/// The boxes that sync between devices and how each identifies a record.
/// Left out on purpose: the Open Food Facts cache (re-downloadable) and
/// photo bytes (they travel in the zip backup; synced records keep their
/// paths, which only resolve on the device that took the photo).
List<SyncedBox<dynamic>> buildSyncedBoxes(HiveDBProvider db) => [
  SyncedBox<ConfigDBO>(
    name: HiveDBProvider.configBoxName,
    box: db.configBox,
    identityOf: (_, key) => key?.toString(),
    toJson: (v) => v.toJson(),
    fromJson: ConfigDBO.fromJson,
    naturalKey: true,
  ),
  SyncedBox<UserDBO>(
    name: HiveDBProvider.userBoxName,
    box: db.userBox,
    identityOf: (_, key) => key?.toString(),
    toJson: (v) => v.toJson(),
    fromJson: UserDBO.fromJson,
    naturalKey: true,
  ),
  SyncedBox<IntakeDBO>(
    name: HiveDBProvider.intakeBoxName,
    box: db.intakeBox,
    identityOf: (v, _) => v.id,
    toJson: (v) => v.toJson(),
    fromJson: IntakeDBO.fromJson,
  ),
  SyncedBox<UserActivityDBO>(
    name: HiveDBProvider.userActivityBoxName,
    box: db.userActivityBox,
    identityOf: (v, _) => v.id,
    toJson: (v) => v.toJson(),
    fromJson: UserActivityDBO.fromJson,
  ),
  SyncedBox<TrackedDayDBO>(
    name: HiveDBProvider.trackedDayBoxName,
    box: db.trackedDayBox,
    identityOf: (_, key) => key?.toString(),
    toJson: (v) => v.toJson(),
    fromJson: TrackedDayDBO.fromJson,
    naturalKey: true,
  ),
  SyncedBox<MealDBO>(
    name: HiveDBProvider.customMealBoxName,
    box: db.customMealBox,
    // Same match the custom-meal data source uses to avoid duplicates.
    identityOf: (v, _) => v.code ?? v.name,
    toJson: (v) => v.toJson(),
    fromJson: MealDBO.fromJson,
  ),
  SyncedBox<RecipeDBO>(
    name: HiveDBProvider.recipeBoxName,
    box: db.recipeBox,
    identityOf: (v, _) => v.id,
    toJson: (v) => v.toJson(),
    fromJson: RecipeDBO.fromJson,
  ),
  SyncedBox<CustomActivityTemplateDBO>(
    name: HiveDBProvider.customActivityTemplateBoxName,
    box: db.customActivityTemplateBox,
    identityOf: (v, _) => v.name,
    toJson: (v) => v.toJson(),
    fromJson: CustomActivityTemplateDBO.fromJson,
  ),
  SyncedBox<WeightLogDBO>(
    name: HiveDBProvider.weightLogBoxName,
    box: db.weightLogBox,
    identityOf: (_, key) => key?.toString(),
    toJson: (v) => v.toJson(),
    fromJson: WeightLogDBO.fromJson,
    naturalKey: true,
  ),
  SyncedBox<WaterIntakeDBO>(
    name: HiveDBProvider.waterIntakeBoxName,
    box: db.waterIntakeBox,
    identityOf: (_, key) => key?.toString(),
    toJson: (v) => v.toJson(),
    fromJson: WaterIntakeDBO.fromJson,
    naturalKey: true,
  ),
  SyncedBox<FastingSessionDBO>(
    name: HiveDBProvider.fastingBoxName,
    box: db.fastingBox,
    identityOf: (_, key) => key?.toString(),
    toJson: (v) => v.toJson(),
    fromJson: FastingSessionDBO.fromJson,
    naturalKey: true,
  ),
  SyncedBox<BodyMeasurementDBO>(
    name: HiveDBProvider.bodyMeasurementBoxName,
    box: db.bodyMeasurementBox,
    identityOf: (_, key) => key?.toString(),
    toJson: (v) => v.toJson(),
    fromJson: BodyMeasurementDBO.fromJson,
    naturalKey: true,
  ),
  SyncedBox<MealPlanEntryDBO>(
    name: HiveDBProvider.mealPlanBoxName,
    box: db.mealPlanBox,
    identityOf: (_, key) => key?.toString(),
    toJson: (v) => v.toJson(),
    fromJson: MealPlanEntryDBO.fromJson,
    naturalKey: true,
  ),
];
