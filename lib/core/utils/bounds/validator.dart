import 'package:opennutritracker/core/utils/bounds/ranges_const.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';

class ValueValidator {
  static String? heightStringValidator(
    String? value,
    String wrongHeightLabel, {
    bool isImperial = false,
  }) {
    if (value == null) return wrongHeightLabel;
    if (isImperial) {
      if (value.isEmpty || !Ranges.feetRegExp.hasMatch(value)) {
        return wrongHeightLabel;
      }
    } else {
      if (value.isEmpty || !Ranges.cmRegExp.hasMatch(value)) {
        return wrongHeightLabel;
      }
    }
    return null;
  }

  static String? weightStringValidator(
    String? value,
    String wrongWeightLabel, {
    bool isImperial = false,
  }) {
    if (value == null) return wrongWeightLabel;
    if (isImperial) {
      if (value.isEmpty || !Ranges.lbsRegExp.hasMatch(value)) {
        return wrongWeightLabel;
      }
    } else {
      if (value.isEmpty || !Ranges.kgRegExp.hasMatch(value)) {
        return wrongWeightLabel;
      }
    }
    return null;
  }

  static double? parseHeightInCm(double? height, {bool isImperial = false}) {
    if (height == null) return null;
    final belowMin =
        isImperial ? height < Ranges.minHeightInFeet : height < Ranges.minHeight;
    final aboveMax =
        isImperial ? height > Ranges.maxHeightInFeet : height > Ranges.maxHeight;
    if (belowMin || aboveMax) return null;
    return isImperial ? UnitCalc.feetToCm(height) : height;
  }

  static double? parseWeightInKg(double? weight, {bool isImperial = false}) {
    if (weight == null) return null;
    final belowMin =
        isImperial ? weight < Ranges.minWeightInLbs : weight < Ranges.minWeight;
    final aboveMax =
        isImperial ? weight > Ranges.maxWeightInLbs : weight > Ranges.maxWeight;
    if (belowMin || aboveMax) return null;
    return isImperial ? UnitCalc.lbsToKg(weight) : weight;
  }

  static DateTime getFirstDate() => DateTime.now().subtract(Ranges.maxAge);

  /// Latest selectable birthday: exactly [Ranges.minAgeYears] years ago.
  static DateTime getLastDate() {
    final now = DateTime.now();
    return DateTime(now.year - Ranges.minAgeYears, now.month, now.day);
  }
}
