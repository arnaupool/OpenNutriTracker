import 'package:hive_ce_flutter/hive_flutter.dart';

/// How the end date of a plan is decided: derived from kg and pace
/// ([auto]) or chosen by the user ([manual]).
enum DietPlanMode { auto, manual }

enum DietPlanStatus { active, paused, finished }

/// A stretch of days the plan was on hold. [to] is the day the plan was
/// resumed; null while the pause is still open.
class DietPlanPause {
  final DateTime from;
  final DateTime? to;

  const DietPlanPause({required this.from, this.to});

  DietPlanPause copyWith({DateTime? to}) => DietPlanPause(from: from, to: to ?? this.to);

  factory DietPlanPause.fromJson(Map<String, dynamic> json) => DietPlanPause(
    from: DateTime.parse(json['from'] as String),
    to: json['to'] == null ? null : DateTime.parse(json['to'] as String),
  );

  Map<String, dynamic> toJson() => {'from': from.toIso8601String(), 'to': to?.toIso8601String()};
}

/// The user's diet plan with an end date (single record under [boxKey]).
///
/// [endDate] is the end date before pauses: the effective end date moves
/// later by the paused days (see `DietPlanCalc.effectiveEnd`). Dates are
/// calendar days (local midnight).
class DietPlanDBO extends HiveObject {
  static const int hiveTypeId = 24;
  static const String boxKey = 'plan';

  final DietPlanMode mode;
  final DateTime startDate;
  final DateTime endDate;
  final double startWeightKg;

  /// Kilograms the plan aims to lose; null for a manual plan without one.
  final double? targetLossKg;

  /// Planned loss per week; null for a manual plan without one.
  final double? paceKgPerWeek;
  final List<DietPlanPause> pauses;
  final bool showCountdown;
  final DietPlanStatus status;

  DietPlanDBO({
    required this.mode,
    required this.startDate,
    required this.endDate,
    required this.startWeightKg,
    this.targetLossKg,
    this.paceKgPerWeek,
    this.pauses = const [],
    this.showCountdown = true,
    this.status = DietPlanStatus.active,
  });

  DietPlanDBO copyWith({
    DietPlanMode? mode,
    DateTime? startDate,
    DateTime? endDate,
    double? startWeightKg,
    double? targetLossKg,
    double? paceKgPerWeek,
    List<DietPlanPause>? pauses,
    bool? showCountdown,
    DietPlanStatus? status,
  }) => DietPlanDBO(
    mode: mode ?? this.mode,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    startWeightKg: startWeightKg ?? this.startWeightKg,
    targetLossKg: targetLossKg ?? this.targetLossKg,
    paceKgPerWeek: paceKgPerWeek ?? this.paceKgPerWeek,
    pauses: pauses ?? this.pauses,
    showCountdown: showCountdown ?? this.showCountdown,
    status: status ?? this.status,
  );

  factory DietPlanDBO.fromJson(Map<String, dynamic> json) => DietPlanDBO(
    mode: DietPlanMode.values.byName(json['mode'] as String),
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: DateTime.parse(json['endDate'] as String),
    startWeightKg: (json['startWeightKg'] as num).toDouble(),
    targetLossKg: (json['targetLossKg'] as num?)?.toDouble(),
    paceKgPerWeek: (json['paceKgPerWeek'] as num?)?.toDouble(),
    pauses: [for (final p in (json['pauses'] as List? ?? const [])) DietPlanPause.fromJson(p as Map<String, dynamic>)],
    showCountdown: json['showCountdown'] as bool? ?? true,
    status: DietPlanStatus.values.byName(json['status'] as String? ?? 'active'),
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'startWeightKg': startWeightKg,
    'targetLossKg': targetLossKg,
    'paceKgPerWeek': paceKgPerWeek,
    'pauses': [for (final p in pauses) p.toJson()],
    'showCountdown': showCountdown,
    'status': status.name,
  };
}

/// Hand-written in the generator's format (field ids are stable; add new
/// fields with new ids only). Pauses are stored flat as
/// `[from0, to0, from1, to1, ...]`, an open pause having a null `to`.
class DietPlanDBOAdapter extends TypeAdapter<DietPlanDBO> {
  @override
  final typeId = DietPlanDBO.hiveTypeId;

  @override
  DietPlanDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    final flat = (fields[7] as List?) ?? const [];
    return DietPlanDBO(
      mode: DietPlanMode.values.byName(fields[0] as String),
      startDate: fields[1] as DateTime,
      endDate: fields[2] as DateTime,
      startWeightKg: (fields[3] as num).toDouble(),
      targetLossKg: (fields[4] as num?)?.toDouble(),
      paceKgPerWeek: (fields[5] as num?)?.toDouble(),
      showCountdown: fields[6] as bool? ?? true,
      pauses: [
        for (var i = 0; i + 1 < flat.length; i += 2)
          DietPlanPause(from: flat[i] as DateTime, to: flat[i + 1] as DateTime?),
      ],
      status: DietPlanStatus.values.byName(fields[8] as String? ?? 'active'),
    );
  }

  @override
  void write(BinaryWriter writer, DietPlanDBO obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.mode.name)
      ..writeByte(1)
      ..write(obj.startDate)
      ..writeByte(2)
      ..write(obj.endDate)
      ..writeByte(3)
      ..write(obj.startWeightKg)
      ..writeByte(4)
      ..write(obj.targetLossKg)
      ..writeByte(5)
      ..write(obj.paceKgPerWeek)
      ..writeByte(6)
      ..write(obj.showCountdown)
      ..writeByte(7)
      ..write([
        for (final p in obj.pauses) ...[p.from, p.to],
      ])
      ..writeByte(8)
      ..write(obj.status.name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DietPlanDBOAdapter && typeId == other.typeId;
}
