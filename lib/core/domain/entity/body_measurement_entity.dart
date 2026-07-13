import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/data/dbo/body_measurement_dbo.dart';

class BodyMeasurementEntity extends Equatable {
  final DateTime date;
  final double? neckCm;
  final double? shouldersCm;
  final double? chestCm;
  final double? waistCm;
  final double? hipsCm;
  final double? bicepsCm;
  final double? thighCm;
  final String? note;

  const BodyMeasurementEntity({
    required this.date,
    this.neckCm,
    this.shouldersCm,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
    this.bicepsCm,
    this.thighCm,
    this.note,
  });

  factory BodyMeasurementEntity.fromBodyMeasurementDBO(
    BodyMeasurementDBO dbo,
  ) {
    return BodyMeasurementEntity(
      date: dbo.date,
      neckCm: dbo.neckCm,
      shouldersCm: dbo.shouldersCm,
      chestCm: dbo.chestCm,
      waistCm: dbo.waistCm,
      hipsCm: dbo.hipsCm,
      bicepsCm: dbo.bicepsCm,
      thighCm: dbo.thighCm,
      note: dbo.note,
    );
  }

  @override
  List<Object?> get props => [
    date,
    neckCm,
    shouldersCm,
    chestCm,
    waistCm,
    hipsCm,
    bicepsCm,
    thighCm,
    note,
  ];
}
