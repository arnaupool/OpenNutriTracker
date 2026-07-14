import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:opennutritracker/core/data/data_source/custom_activity_template_dbo.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/data/dbo/body_measurement_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/repository/body_measurement_repository.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/custom_activity_template_repository.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/data/repository/user_activity_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/utils/csv_data_exporter.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';

class ImportDataUsecase {
  final UserActivityRepository _userActivityRepository;
  final IntakeRepository _intakeRepository;
  final TrackedDayRepository _trackedDayRepository;
  final RecipeRepository _recipeRepository;
  final WeightLogRepository _weightLogRepository;
  final CustomActivityTemplateRepository _customActivityTemplateRepository;
  final BodyMeasurementRepository _bodyMeasurementRepository;
  final UserRepository _userRepository;
  final ConfigRepository _configRepository;

  ImportDataUsecase(
    this._userActivityRepository,
    this._intakeRepository,
    this._trackedDayRepository,
    this._recipeRepository,
    this._weightLogRepository,
    this._customActivityTemplateRepository,
    this._bodyMeasurementRepository,
    this._userRepository,
    this._configRepository,
  );

  /// Imports user activity, intake, tracked day, and (optionally) recipe,
  /// weight log, Custom activity template or body measurement data from a
  /// zip file containing JSON files. Recipe, weight log, template and body
  /// measurement files are treated as optional so zips exported by older
  /// versions still import.
  ///
  /// Returns true if import was successful, false otherwise.
  Future<bool> importData(
    String userActivityJsonFileName,
    String userIntakeJsonFileName,
    String trackedDayJsonFileName,
    String recipeJsonFileName,
    String weightLogJsonFileName,
    String customActivityTemplateJsonFileName,
    String bodyMeasurementJsonFileName, {
    // Unlike the optional sections above (restored whenever the file is
    // present in the zip), profile/settings restoration requires this
    // explicit opt-in even if the files are present — overwriting a
    // person's height/weight/goals or app preferences is a bigger deal
    // than merging in some extra recipes, so the caller (the cloud-backup
    // restore flow, which shows its own destructive-action warning first)
    // has to ask for it on purpose. The regular Settings → Import screen
    // never passes this, so it can't happen by accident there.
    bool restoreProfile = false,
    String userProfileJsonFileName = 'user_profile.json',
    String userConfigJsonFileName = 'user_config.json',
  }) async {
    // Allow user to pick a zip file. withData: true is required on web —
    // file_picker never returns a filesystem `path` there (there isn't
    // one), only in-memory `bytes` — and works identically on
    // Android/iOS, so there's no need to branch by platform.
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      withData: true,
      // allowedExtensions: ['zip'],
    );

    final zipBytes = result?.files.single.bytes;
    if (zipBytes == null) {
      throw Exception('No file selected');
    }

    return importFromZipBytes(
      zipBytes,
      userActivityJsonFileName: userActivityJsonFileName,
      userIntakeJsonFileName: userIntakeJsonFileName,
      trackedDayJsonFileName: trackedDayJsonFileName,
      recipeJsonFileName: recipeJsonFileName,
      weightLogJsonFileName: weightLogJsonFileName,
      customActivityTemplateJsonFileName: customActivityTemplateJsonFileName,
      bodyMeasurementJsonFileName: bodyMeasurementJsonFileName,
      restoreProfile: restoreProfile,
      userProfileJsonFileName: userProfileJsonFileName,
      userConfigJsonFileName: userConfigJsonFileName,
    );
  }

  /// The zip-decoding core of [importData], split out so the cloud-backup
  /// feature ([CloudRestoreUsecase]) can restore from bytes downloaded off
  /// Supabase Storage instead of a file-picker selection. Filenames default
  /// to the same constants [ExportImportBloc] passes explicitly.
  Future<bool> importFromZipBytes(
    Uint8List zipBytes, {
    String userActivityJsonFileName = 'user_activity.json',
    String userIntakeJsonFileName = 'user_intake.json',
    String trackedDayJsonFileName = 'user_tracked_day.json',
    String recipeJsonFileName = 'user_recipes.json',
    String weightLogJsonFileName = 'weight_log.json',
    String customActivityTemplateJsonFileName =
        'custom_activity_templates.json',
    String bodyMeasurementJsonFileName = 'body_measurements.json',
    bool restoreProfile = false,
    String userProfileJsonFileName = 'user_profile.json',
    String userConfigJsonFileName = 'user_config.json',
  }) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    // Extract and process user activity data
    final userActivityFile = archive.findFile(userActivityJsonFileName);
    if (userActivityFile != null) {
      final userActivityJsonString = utf8.decode(
        userActivityFile.content as List<int>,
      );
      final userActivityList = (jsonDecode(userActivityJsonString) as List)
          .cast<Map<String, dynamic>>();

      final userActivityDBOs = userActivityList
          .map((json) => UserActivityDBO.fromJson(json))
          .toList();

      await _userActivityRepository.addAllUserActivityDBOs(userActivityDBOs);
    } else {
      throw Exception('User activity file not found in the archive');
    }

    // Extract and process intake data
    final intakeFile = archive.findFile(userIntakeJsonFileName);
    if (intakeFile != null) {
      final intakeJsonString = utf8.decode(intakeFile.content as List<int>);
      final intakeList = (jsonDecode(intakeJsonString) as List)
          .cast<Map<String, dynamic>>();

      final intakeDBOs = intakeList
          .map((json) => IntakeDBO.fromJson(json))
          .toList();

      await _intakeRepository.addAllIntakeDBOs(intakeDBOs);
    } else {
      throw Exception('Intake file not found in the archive');
    }

    // Extract and process tracked day data
    final trackedDayFile = archive.findFile(trackedDayJsonFileName);
    if (trackedDayFile != null) {
      final trackedDayJsonString = utf8.decode(
        trackedDayFile.content as List<int>,
      );
      final trackedDayList = (jsonDecode(trackedDayJsonString) as List)
          .cast<Map<String, dynamic>>();

      final trackedDayDBOs = trackedDayList
          .map((json) => TrackedDayDBO.fromJson(json))
          .toList();

      await _trackedDayRepository.addAllTrackedDays(trackedDayDBOs);
    } else {
      throw Exception('Tracked day file not found in the archive');
    }

    // Extract and process recipe data — optional so older zips still import.
    final recipeFile = archive.findFile(recipeJsonFileName);
    if (recipeFile != null) {
      final recipeJsonString = utf8.decode(recipeFile.content as List<int>);
      final recipeList = (jsonDecode(recipeJsonString) as List)
          .cast<Map<String, dynamic>>();
      final recipeDBOs = recipeList
          .map((json) => RecipeDBO.fromJson(json))
          .toList();
      await _recipeRepository.addAllRecipeDBOs(recipeDBOs);
    }

    // Extract and process weight log data — optional so older zips still import.
    final weightLogFile = archive.findFile(weightLogJsonFileName);
    if (weightLogFile != null) {
      final weightLogJsonString = utf8.decode(
        weightLogFile.content as List<int>,
      );
      final weightLogList = (jsonDecode(weightLogJsonString) as List)
          .cast<Map<String, dynamic>>();
      final weightLogDBOs = weightLogList
          .map((json) => WeightLogDBO.fromJson(json))
          .toList();
      await _weightLogRepository.addAllEntries(weightLogDBOs);
    }

    // Extract and process Custom activity template data (#70 follow-up)
    // — also optional so zips produced before templates landed still import.
    final templateFile = archive.findFile(customActivityTemplateJsonFileName);
    if (templateFile != null) {
      final templateJsonString = utf8.decode(templateFile.content as List<int>);
      final templateList = (jsonDecode(templateJsonString) as List)
          .cast<Map<String, dynamic>>();
      final templateDBOs = templateList
          .map((json) => CustomActivityTemplateDBO.fromJson(json))
          .toList();
      await _customActivityTemplateRepository.addAllTemplateDBOs(templateDBOs);
    }

    // Extract and process body measurement data (FC-01/FC-02) — optional
    // so zips produced before this feature landed still import.
    final bodyMeasurementFile = archive.findFile(bodyMeasurementJsonFileName);
    if (bodyMeasurementFile != null) {
      final bodyMeasurementJsonString = utf8.decode(
        bodyMeasurementFile.content as List<int>,
      );
      final bodyMeasurementList =
          (jsonDecode(bodyMeasurementJsonString) as List)
              .cast<Map<String, dynamic>>();
      final bodyMeasurementDBOs = bodyMeasurementList
          .map((json) => BodyMeasurementDBO.fromJson(json))
          .toList();
      await _bodyMeasurementRepository.addAllEntries(bodyMeasurementDBOs);
    }

    // Restore profile + settings — explicit opt-in, see restoreProfile doc
    // above. Overwrites the local UserBox/ConfigBox record outright (both
    // are single-record boxes keyed by a hardcoded key, so there's nothing
    // to merge — it's a plain replace, same as the rest of this method's
    // upsert-by-key sections, just with no per-record granularity).
    if (restoreProfile) {
      final userProfileFile = archive.findFile(userProfileJsonFileName);
      if (userProfileFile != null) {
        final userJson =
            jsonDecode(utf8.decode(userProfileFile.content as List<int>))
                as Map<String, dynamic>;
        await _userRepository.saveUserDBO(UserDBO.fromJson(userJson));
      }

      final userConfigFile = archive.findFile(userConfigJsonFileName);
      if (userConfigFile != null) {
        final configJson =
            jsonDecode(utf8.decode(userConfigFile.content as List<int>))
                as Map<String, dynamic>;
        await _configRepository.saveConfigDBO(ConfigDBO.fromJson(configJson));
      }
    }

    // Restore any user-attached photos — recipes under `recipe_images/`,
    // custom meals under `meal_images/`, and progress photos under
    // `progress_photos/` (only present if the export opted in). Each
    // archive entry's name already matches the relative slug we stored on
    // the matching DBO, so we just write the bytes back into the right
    // private documents subdirectory. Anything outside those known
    // prefixes is skipped by the sanitiser, so a hostile zip can't escape
    // into other folders.
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final sanitized = UserImageStorage.sanitizeRelative(entry.name);
      if (sanitized == null) continue;
      await UserImageStorage.writeBytes(
        sanitized,
        Uint8List.fromList(entry.content as List<int>),
      );
    }

    return true;
  }

  /// Symmetric CSV counterpart to [importData]. Reads a zip produced by
  /// `ExportDataUsecase.exportData(format: ExportFormat.csv)` and feeds
  /// each CSV through the matching `parse...FromCsv` helper on
  /// [CsvDataExporter]. Recipes, photos, the weight log and Custom
  /// activity templates are intentionally not handled here — CSV export
  /// omits them by design (nested or binary shapes don't flatten
  /// cleanly), so a CSV-only round trip does not restore them. A user
  /// who needs them in their backup should choose the JSON format
  /// instead.
  Future<bool> importDataCsv({
    String userActivityCsvFileName = 'user_activity.csv',
    String userIntakeCsvFileName = 'user_intake.csv',
    String trackedDayCsvFileName = 'user_tracked_day.csv',
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      withData: true,
    );
    final zipBytes = result?.files.single.bytes;
    if (zipBytes == null) {
      throw Exception('No file selected');
    }

    final archive = ZipDecoder().decodeBytes(zipBytes);

    final activityFile = archive.findFile(userActivityCsvFileName);
    if (activityFile != null) {
      final csv = utf8.decode(activityFile.content as List<int>);
      final dbos = CsvDataExporter.parseUserActivitiesFromCsv(csv);
      await _userActivityRepository.addAllUserActivityDBOs(dbos);
    } else {
      throw Exception('User activity CSV not found in the archive');
    }

    final intakeFile = archive.findFile(userIntakeCsvFileName);
    if (intakeFile != null) {
      final csv = utf8.decode(intakeFile.content as List<int>);
      final dbos = CsvDataExporter.parseIntakesFromCsv(csv);
      await _intakeRepository.addAllIntakeDBOs(dbos);
    } else {
      throw Exception('Intake CSV not found in the archive');
    }

    final trackedDayFile = archive.findFile(trackedDayCsvFileName);
    if (trackedDayFile != null) {
      final csv = utf8.decode(trackedDayFile.content as List<int>);
      final dbos = CsvDataExporter.parseTrackedDaysFromCsv(csv);
      await _trackedDayRepository.addAllTrackedDays(dbos);
    } else {
      throw Exception('Tracked day CSV not found in the archive');
    }

    return true;
  }
}
