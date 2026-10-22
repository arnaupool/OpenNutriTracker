/// One food from the bundled BEDCA asset (`assets/bedca/bedca_foods.json`).
///
/// BEDCA (Base de Datos Española de Composición de Alimentos) is published
/// by AESAN for personal, non-commercial use with attribution; values are
/// per 100 g of edible portion. The asset is built by
/// `tool/bedca/build_bedca_asset.py` from the public BEDCA query service.
/// [nutrients] uses the asset's short keys (see [BedcaConst]).
class BedcaFoodDTO {
  final int id;
  final String nameEs;
  final String? nameEn;
  final Map<String, double> nutrients;

  const BedcaFoodDTO({
    required this.id,
    required this.nameEs,
    required this.nameEn,
    required this.nutrients,
  });

  factory BedcaFoodDTO.fromJson(Map<String, dynamic> json) => BedcaFoodDTO(
        id: json['id'] as int,
        nameEs: json['es'] as String,
        nameEn: json['en'] as String?,
        nutrients: {
          for (final e in ((json['n'] as Map<String, dynamic>?) ?? const {}).entries)
            if (e.value is num) e.key: (e.value as num).toDouble(),
        },
      );

  double? operator [](String key) => nutrients[key];
}

class BedcaConst {
  static const assetPath = 'assets/bedca/bedca_foods.json';
  static const websiteUrl = 'https://www.bedca.net/bdpub/index.php';
  static const brandLabel = 'BEDCA';
  static const codePrefix = 'bedca-';

  // Asset nutrient keys, per 100 g edible portion. Energy is in kcal
  // (BEDCA reports kJ; the build script divides by 4.184), minerals and
  // vitamins in the units MealNutrimentsEntity uses.
  static const kcal = 'kcal';
  static const carbs = 'carb';
  static const fat = 'fat';
  static const protein = 'prot';
  static const sugars = 'sug';
  static const saturatedFat = 'sat';
  static const fiber = 'fib';
  static const monounsaturatedFat = 'mufa';
  static const polyunsaturatedFat = 'pufa';
  static const transFat = 'trans';
  static const cholesterol = 'chol';
  static const sodium = 'na';
  static const potassium = 'k';
  static const magnesium = 'mg';
  static const calcium = 'ca';
  static const iron = 'fe';
  static const zinc = 'zn';
  static const phosphorus = 'p';
  static const vitaminA = 'vitA';
  static const vitaminC = 'vitC';
  static const vitaminD = 'vitD';
  static const vitaminB6 = 'vitB6';
  static const vitaminB12 = 'vitB12';
  static const niacin = 'nia';
}
