import 'package:opennutritracker/core/domain/entity/body_measurement_entity.dart';
import 'package:opennutritracker/core/utils/calc/calendar_day_calc.dart';

/// One progress photo: the measurement entry it belongs to and its storage path.
class ReviewPhoto {
  final DateTime date;
  final String path;

  const ReviewPhoto(this.date, this.path);

  @override
  bool operator ==(Object other) => other is ReviewPhoto && other.date == date && other.path == path;

  @override
  int get hashCode => Object.hash(date, path);
}

/// Pure selection logic for the photo comparator in the review screen.
class ReviewPhotos {
  const ReviewPhotos._();

  /// Photos for one angle (the [pathFor] accessor picks it from an entry),
  /// newest first.
  static List<ReviewPhoto> forAngle(
    Iterable<BodyMeasurementEntity> entries,
    String? Function(BodyMeasurementEntity) pathFor,
  ) {
    final photos = <ReviewPhoto>[];
    for (final e in entries) {
      final path = pathFor(e);
      if (path != null && path.isNotEmpty) photos.add(ReviewPhoto(e.date, path));
    }
    photos.sort((a, b) => b.date.compareTo(a.date));
    return photos;
  }

  /// Default pair for [photos] (newest first): oldest as "before", newest as
  /// "after". Null when there are fewer than two photos.
  static (ReviewPhoto, ReviewPhoto)? defaultPair(List<ReviewPhoto> photos) {
    if (photos.length < 2) return null;
    return (photos.last, photos.first);
  }

  /// Whole calendar days between two photos.
  static int daysBetween(ReviewPhoto before, ReviewPhoto after) =>
      CalendarDayCalc.daysBetween(before.date, after.date).abs();
}
