import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/domain/entity/body_measurement_entity.dart';

part 'body_measurement_dbo.g.dart';

@HiveType(typeId: 20)
@JsonSerializable()
class BodyMeasurementDBO extends HiveObject {
  @HiveField(0)
  DateTime date;
  @HiveField(1)
  double? neckCm;
  @HiveField(2)
  double? shouldersCm;
  @HiveField(3)
  double? chestCm;
  @HiveField(4)
  double? waistCm;
  @HiveField(5)
  double? hipsCm;
  @HiveField(6)
  double? bicepsCm;
  @HiveField(7)
  double? thighCm;
  @HiveField(8)
  String? note;
  // Relative UserImageStorage slugs (e.g. `progress_photos/<id>.webp`),
  // added alongside the numeric fields since MacroFactor logs photos as
  // part of the same daily entry rather than a separate flow.
  @HiveField(9)
  String? frontPhotoPath;
  @HiveField(10)
  String? sidePhotoPath;
  @HiveField(11)
  String? backPhotoPath;

  BodyMeasurementDBO({
    required this.date,
    this.neckCm,
    this.shouldersCm,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
    this.bicepsCm,
    this.thighCm,
    this.note,
    this.frontPhotoPath,
    this.sidePhotoPath,
    this.backPhotoPath,
  });

  factory BodyMeasurementDBO.fromBodyMeasurementEntity(
    BodyMeasurementEntity entity,
  ) {
    return BodyMeasurementDBO(
      date: entity.date,
      neckCm: entity.neckCm,
      shouldersCm: entity.shouldersCm,
      chestCm: entity.chestCm,
      waistCm: entity.waistCm,
      hipsCm: entity.hipsCm,
      bicepsCm: entity.bicepsCm,
      thighCm: entity.thighCm,
      note: entity.note,
      frontPhotoPath: entity.frontPhotoPath,
      sidePhotoPath: entity.sidePhotoPath,
      backPhotoPath: entity.backPhotoPath,
    );
  }

  factory BodyMeasurementDBO.fromJson(Map<String, dynamic> json) =>
      _$BodyMeasurementDBOFromJson(json);

  Map<String, dynamic> toJson() => _$BodyMeasurementDBOToJson(this);
}
