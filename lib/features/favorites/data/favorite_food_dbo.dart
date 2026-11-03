import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';

/// A favorite food: an editable local copy of any food (Open Food Facts,
/// USDA, BEDCA, custom) or one made by hand. Nutriments are per 100 [unit]
/// (`g` or `ml`). The copy never follows changes of the original product,
/// and editing it never touches past diary entries (those hold their own
/// snapshot of the meal).
class FavoriteFoodDBO extends HiveObject {
  static const int hiveTypeId = 27;

  final String id;
  final String name;
  final String? brand;
  final String? imageUrl;

  /// Macros and micronutrients per 100 [unit].
  final MealNutrimentsDBO nutriments;

  /// Base unit of the nutriments: `g` or `ml`.
  final String unit;

  /// Default portion, e.g. "glass" and 250 (in [unit]). Both null when the
  /// favorite has none; logging then starts from 100 [unit].
  final String? portionName;
  final double? portionQuantity;

  /// Every barcode that identifies this food (a product can have several).
  final List<String> barcodes;

  /// Where the copy came from (`off`, `fdc`, `bedca`, `custom`, `recipe`) and
  /// the id of the copied product; both null for a favorite made by hand.
  final String? originSource;
  final String? originId;

  final DateTime createdAt;
  final DateTime modifiedAt;

  FavoriteFoodDBO({
    required this.id,
    required this.name,
    this.brand,
    this.imageUrl,
    required this.nutriments,
    this.unit = 'g',
    this.portionName,
    this.portionQuantity,
    this.barcodes = const [],
    this.originSource,
    this.originId,
    required this.createdAt,
    required this.modifiedAt,
  });

  factory FavoriteFoodDBO.fromJson(Map<String, dynamic> json) => FavoriteFoodDBO(
    id: json['id'] as String,
    name: json['name'] as String,
    brand: json['brand'] as String?,
    imageUrl: json['imageUrl'] as String?,
    nutriments: MealNutrimentsDBO.fromJson(json['nutriments'] as Map<String, dynamic>),
    unit: json['unit'] as String? ?? 'g',
    portionName: json['portionName'] as String?,
    portionQuantity: (json['portionQuantity'] as num?)?.toDouble(),
    barcodes: [for (final b in (json['barcodes'] as List? ?? const [])) b as String],
    originSource: json['originSource'] as String?,
    originId: json['originId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    modifiedAt: DateTime.parse(json['modifiedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'imageUrl': imageUrl,
    'nutriments': nutriments.toJson(),
    'unit': unit,
    'portionName': portionName,
    'portionQuantity': portionQuantity,
    'barcodes': barcodes,
    'originSource': originSource,
    'originId': originId,
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': modifiedAt.toIso8601String(),
  };
}

/// Hand-written in the generator's format (field ids are stable; add new
/// fields with new ids only).
class FavoriteFoodDBOAdapter extends TypeAdapter<FavoriteFoodDBO> {
  @override
  final typeId = FavoriteFoodDBO.hiveTypeId;

  @override
  FavoriteFoodDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return FavoriteFoodDBO(
      id: fields[0] as String,
      name: fields[1] as String,
      brand: fields[2] as String?,
      imageUrl: fields[3] as String?,
      nutriments: fields[4] as MealNutrimentsDBO,
      unit: fields[5] as String? ?? 'g',
      portionName: fields[6] as String?,
      portionQuantity: (fields[7] as num?)?.toDouble(),
      barcodes: [for (final b in (fields[8] as List? ?? const [])) b as String],
      originSource: fields[9] as String?,
      originId: fields[10] as String?,
      createdAt: fields[11] as DateTime,
      modifiedAt: fields[12] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FavoriteFoodDBO obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.brand)
      ..writeByte(3)
      ..write(obj.imageUrl)
      ..writeByte(4)
      ..write(obj.nutriments)
      ..writeByte(5)
      ..write(obj.unit)
      ..writeByte(6)
      ..write(obj.portionName)
      ..writeByte(7)
      ..write(obj.portionQuantity)
      ..writeByte(8)
      ..write(obj.barcodes)
      ..writeByte(9)
      ..write(obj.originSource)
      ..writeByte(10)
      ..write(obj.originId)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.modifiedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is FavoriteFoodDBOAdapter && typeId == other.typeId;
}
