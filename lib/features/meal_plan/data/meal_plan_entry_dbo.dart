import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';

/// One planned food or recipe for a day and meal slot (FAS-04). The meal is
/// a snapshot, like an intake's, so the plan survives the source food or
/// recipe being edited or deleted. An entry is one planned item on one day,
/// so its confirmation state is per entry and day: [loggedAt] is set once the
/// entry has turned into a diary intake (the Diary's "Confirm" or "Log plan"),
/// [discardedAt] once the owner dismissed it from the Diary. Both live in the
/// entry, so they survive restarts and travel with the synced plan.
class MealPlanEntryDBO extends HiveObject {
  static const int hiveTypeId = 23;

  final String id;
  final DateTime day;
  final IntakeTypeDBO type;
  final MealDBO meal;

  /// Grams (or millilitres for drinks), like an intake's amount.
  final double amount;
  final String unit;
  final DateTime? loggedAt;
  final DateTime? discardedAt;

  bool get isPending => loggedAt == null && discardedAt == null;

  MealPlanEntryDBO({
    required this.id,
    required this.day,
    required this.type,
    required this.meal,
    required this.amount,
    required this.unit,
    this.loggedAt,
    this.discardedAt,
  });

  MealPlanEntryDBO copyWith({double? amount, DateTime? loggedAt, DateTime? discardedAt}) => MealPlanEntryDBO(
    id: id,
    day: day,
    type: type,
    meal: meal,
    amount: amount ?? this.amount,
    unit: unit,
    loggedAt: loggedAt ?? this.loggedAt,
    discardedAt: discardedAt ?? this.discardedAt,
  );

  factory MealPlanEntryDBO.fromJson(Map<String, dynamic> json) => MealPlanEntryDBO(
    id: json['id'] as String,
    day: DateTime.parse(json['day'] as String),
    type: IntakeTypeDBO.values.byName(json['type'] as String),
    meal: MealDBO.fromJson(json['meal'] as Map<String, dynamic>),
    amount: (json['amount'] as num).toDouble(),
    unit: json['unit'] as String,
    loggedAt: json['loggedAt'] == null ? null : DateTime.parse(json['loggedAt'] as String),
    discardedAt: json['discardedAt'] == null ? null : DateTime.parse(json['discardedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day.toIso8601String(),
    'type': type.name,
    'meal': meal.toJson(),
    'amount': amount,
    'unit': unit,
    'loggedAt': loggedAt?.toIso8601String(),
    'discardedAt': discardedAt?.toIso8601String(),
  };
}

/// Hand-written in the generator's format (field ids are stable; add new
/// fields with new ids only).
class MealPlanEntryDBOAdapter extends TypeAdapter<MealPlanEntryDBO> {
  @override
  final typeId = MealPlanEntryDBO.hiveTypeId;

  @override
  MealPlanEntryDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return MealPlanEntryDBO(
      id: fields[0] as String,
      day: fields[1] as DateTime,
      type: fields[2] as IntakeTypeDBO,
      meal: fields[3] as MealDBO,
      amount: (fields[4] as num).toDouble(),
      unit: fields[5] as String,
      loggedAt: fields[6] as DateTime?,
      discardedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, MealPlanEntryDBO obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.day)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.meal)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.unit)
      ..writeByte(6)
      ..write(obj.loggedAt)
      ..writeByte(7)
      ..write(obj.discardedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MealPlanEntryDBOAdapter && typeId == other.typeId;
}
