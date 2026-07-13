// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'body_measurement_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BodyMeasurementDBOAdapter extends TypeAdapter<BodyMeasurementDBO> {
  @override
  final typeId = 20;

  @override
  BodyMeasurementDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BodyMeasurementDBO(
      date: fields[0] as DateTime,
      neckCm: (fields[1] as num?)?.toDouble(),
      shouldersCm: (fields[2] as num?)?.toDouble(),
      chestCm: (fields[3] as num?)?.toDouble(),
      waistCm: (fields[4] as num?)?.toDouble(),
      hipsCm: (fields[5] as num?)?.toDouble(),
      bicepsCm: (fields[6] as num?)?.toDouble(),
      thighCm: (fields[7] as num?)?.toDouble(),
      note: fields[8] as String?,
      frontPhotoPath: fields[9] as String?,
      sidePhotoPath: fields[10] as String?,
      backPhotoPath: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BodyMeasurementDBO obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.neckCm)
      ..writeByte(2)
      ..write(obj.shouldersCm)
      ..writeByte(3)
      ..write(obj.chestCm)
      ..writeByte(4)
      ..write(obj.waistCm)
      ..writeByte(5)
      ..write(obj.hipsCm)
      ..writeByte(6)
      ..write(obj.bicepsCm)
      ..writeByte(7)
      ..write(obj.thighCm)
      ..writeByte(8)
      ..write(obj.note)
      ..writeByte(9)
      ..write(obj.frontPhotoPath)
      ..writeByte(10)
      ..write(obj.sidePhotoPath)
      ..writeByte(11)
      ..write(obj.backPhotoPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BodyMeasurementDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BodyMeasurementDBO _$BodyMeasurementDBOFromJson(Map<String, dynamic> json) =>
    BodyMeasurementDBO(
      date: DateTime.parse(json['date'] as String),
      neckCm: (json['neckCm'] as num?)?.toDouble(),
      shouldersCm: (json['shouldersCm'] as num?)?.toDouble(),
      chestCm: (json['chestCm'] as num?)?.toDouble(),
      waistCm: (json['waistCm'] as num?)?.toDouble(),
      hipsCm: (json['hipsCm'] as num?)?.toDouble(),
      bicepsCm: (json['bicepsCm'] as num?)?.toDouble(),
      thighCm: (json['thighCm'] as num?)?.toDouble(),
      note: json['note'] as String?,
      frontPhotoPath: json['frontPhotoPath'] as String?,
      sidePhotoPath: json['sidePhotoPath'] as String?,
      backPhotoPath: json['backPhotoPath'] as String?,
    );

Map<String, dynamic> _$BodyMeasurementDBOToJson(BodyMeasurementDBO instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'neckCm': instance.neckCm,
      'shouldersCm': instance.shouldersCm,
      'chestCm': instance.chestCm,
      'waistCm': instance.waistCm,
      'hipsCm': instance.hipsCm,
      'bicepsCm': instance.bicepsCm,
      'thighCm': instance.thighCm,
      'note': instance.note,
      'frontPhotoPath': instance.frontPhotoPath,
      'sidePhotoPath': instance.sidePhotoPath,
      'backPhotoPath': instance.backPhotoPath,
    };
