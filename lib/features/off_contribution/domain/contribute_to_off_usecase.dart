import 'dart:ui' show PlatformDispatcher;

import 'package:logging/logging.dart';
import 'package:opennutritracker/core/utils/barcode_validator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/off_contribution/data/off_account_data_source.dart';
import 'package:opennutritracker/features/off_contribution/data/off_contribution_data_source.dart';

enum OffContributionResult {
  sent,
  alreadyOnOff,
  notSignedIn,
  wrongCredentials,
  missingData,
  failed,
}

/// Sends a custom food with a retail barcode to Open Food Facts as a new
/// product, signed with the user's own OFF account. Products that already
/// exist on OFF are left alone, so a local copy never overwrites shared data.
class ContributeToOffUsecase {
  final _log = Logger('ContributeToOffUsecase');
  final OffAccountDataSource _account;
  final OffContributionDataSource _dataSource;

  ContributeToOffUsecase(this._account, this._dataSource);

  /// Only foods whose values are per 100 g or 100 ml qualify. Simple-mode
  /// custom meals keep the totals of one serving in the per-100 fields with
  /// the unit "g/ml"; OFF would publish those as per-100 g values.
  static const _per100Units = {'g', 'ml'};

  static bool canContribute(MealEntity meal) =>
      _per100Units.contains(meal.mealUnit) &&
      isBarcodeFormatValid(meal.code ?? '') &&
      (meal.name?.trim().isNotEmpty ?? false) &&
      meal.nutriments.energyKcal100 != null;

  Future<OffContributionResult> contribute(MealEntity meal) async {
    if (!canContribute(meal)) return OffContributionResult.missingData;
    final credentials = await _account.read();
    if (credentials == null) return OffContributionResult.notSignedIn;
    try {
      if (await _dataSource.productExists(meal.code!)) {
        return OffContributionResult.alreadyOnOff;
      }
      await _dataSource.submitProduct(formFields(meal), credentials);
      return OffContributionResult.sent;
    } on OffAuthException {
      return OffContributionResult.wrongCredentials;
    } catch (e, st) {
      _log.warning('OFF contribution failed', e, st);
      return OffContributionResult.failed;
    }
  }

  /// product_jqm2 form fields: nutrition per 100 g as the app stores it.
  static Map<String, String> formFields(MealEntity meal) {
    final n = meal.nutriments;
    final fields = <String, String>{
      'code': meal.code!,
      'product_name': meal.name!.trim(),
      'lc': PlatformDispatcher.instance.locale.languageCode,
      'nutrition_data_per': '100g',
      'comment': 'Added with OpenNutriTracker',
    };
    final brands = meal.brands?.trim();
    if (brands != null && brands.isNotEmpty) fields['brands'] = brands;
    final servingSize = meal.servingSize?.trim();
    if (servingSize != null && servingSize.isNotEmpty) fields['serving_size'] = servingSize;

    void put(String nutrient, double? value, String unit) {
      if (value == null) return;
      fields['nutriment_$nutrient'] = _format(value);
      fields['nutriment_${nutrient}_unit'] = unit;
    }

    put('energy-kcal', n.energyKcal100, 'kcal');
    put('fat', n.fat100, 'g');
    put('saturated-fat', n.saturatedFat100, 'g');
    put('carbohydrates', n.carbohydrates100, 'g');
    put('sugars', n.sugars100, 'g');
    put('fiber', n.fiber100, 'g');
    put('proteins', n.proteins100, 'g');
    // Sodium is kept in mg in the app.
    put('sodium', n.sodium100 == null ? null : n.sodium100! / 1000, 'g');
    return fields;
  }

  static String _format(double v) {
    final rounded = double.parse(v.toStringAsFixed(4));
    return rounded == rounded.roundToDouble() ? rounded.toInt().toString() : rounded.toString();
  }
}
