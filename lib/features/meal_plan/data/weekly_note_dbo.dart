import 'package:hive_ce_flutter/hive_flutter.dart';

/// The note of one ISO week of the meal plan: free text where the lines that
/// start with `- [ ]` or `- [x]` are checkboxes. One record per week, keyed by
/// [weekKey] (`2026-W45`). Devices of an account sync it as a whole: the last
/// write of the note wins, like the rest of the sync.
class WeeklyNoteDBO extends HiveObject {
  static const int hiveTypeId = 28;

  final String weekKey;
  final String text;
  final DateTime modifiedAt;

  WeeklyNoteDBO({required this.weekKey, required this.text, required this.modifiedAt});

  factory WeeklyNoteDBO.fromJson(Map<String, dynamic> json) => WeeklyNoteDBO(
    weekKey: json['weekKey'] as String,
    text: json['text'] as String? ?? '',
    modifiedAt: DateTime.parse(json['modifiedAt'] as String),
  );

  Map<String, dynamic> toJson() => {'weekKey': weekKey, 'text': text, 'modifiedAt': modifiedAt.toIso8601String()};
}

/// Hand-written in the generator's format (field ids are stable; add new
/// fields with new ids only).
class WeeklyNoteDBOAdapter extends TypeAdapter<WeeklyNoteDBO> {
  @override
  final typeId = WeeklyNoteDBO.hiveTypeId;

  @override
  WeeklyNoteDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return WeeklyNoteDBO(
      weekKey: fields[0] as String,
      text: fields[1] as String? ?? '',
      modifiedAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, WeeklyNoteDBO obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.weekKey)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.modifiedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is WeeklyNoteDBOAdapter && typeId == other.typeId;
}
