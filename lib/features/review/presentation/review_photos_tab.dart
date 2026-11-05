import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/domain/usecase/get_body_measurement_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';
import 'package:opennutritracker/features/profile/presentation/body_measurements_screen.dart' show ProgressPhotoAngle;
import 'package:opennutritracker/features/review/domain/review_photos.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Side-by-side comparison of two progress photos for one angle. Ignores the
/// review date range: it lists every entry that has a photo for the angle.
class ReviewPhotosTab extends StatefulWidget {
  final GetBodyMeasurementUsecase? getUsecase;

  const ReviewPhotosTab({super.key, this.getUsecase});

  @override
  State<ReviewPhotosTab> createState() => _ReviewPhotosTabState();
}

class _ReviewPhotosTabState extends State<ReviewPhotosTab> {
  bool _loading = true;
  Map<ProgressPhotoAngle, List<ReviewPhoto>> _photos = {};
  ProgressPhotoAngle _angle = ProgressPhotoAngle.front;
  ReviewPhoto? _before;
  ReviewPhoto? _after;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final usecase = widget.getUsecase ?? locator<GetBodyMeasurementUsecase>();
    final entries = await usecase.getAllEntries();
    if (!mounted) return;
    final photos = {for (final a in ProgressPhotoAngle.values) a: ReviewPhotos.forAngle(entries, a.pathFor)};
    final angle = ProgressPhotoAngle.values.firstWhere(
      (a) => photos[a]!.length >= 2,
      orElse: () => ProgressPhotoAngle.front,
    );
    setState(() {
      _photos = photos;
      _loading = false;
      _selectAngle(angle);
    });
  }

  List<ReviewPhoto> get _list => _photos[_angle] ?? const [];

  void _selectAngle(ProgressPhotoAngle angle) {
    _angle = angle;
    final pair = ReviewPhotos.defaultPair(_list);
    _before = pair?.$1 ?? (_list.isEmpty ? null : _list.first);
    _after = pair?.$2;
  }

  Future<void> _pick({required bool isBefore}) async {
    final picked = await showModalBottomSheet<ReviewPhoto>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PhotoPickerSheet(photos: _list),
    );
    if (picked == null) return;
    setState(() {
      if (isBefore) {
        _before = picked;
      } else {
        _after = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final s = S.of(context);
    final list = _list;
    final before = _before;
    final after = _after;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(
          identifier: 'review-photos-angle',
          child: SegmentedButton<ProgressPhotoAngle>(
            showSelectedIcon: false,
            segments: [
              for (final a in ProgressPhotoAngle.values) ButtonSegment(value: a, label: Text(a.label(context))),
            ],
            selected: {_angle},
            onSelectionChanged: (v) => setState(() => _selectAngle(v.first)),
          ),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(s.reviewPhotosEmpty, textAlign: TextAlign.center),
          )
        else ...[
          if (before != null && after != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                s.homeHabitDaysCount(ReviewPhotos.daysBetween(before, after)),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PhotoCard(
                  idSuffix: 'before',
                  title: s.bodyMeasurementsCompareBeforeLabel,
                  photo: before,
                  onChange: () => _pick(isBefore: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PhotoCard(
                  idSuffix: 'after',
                  title: s.bodyMeasurementsCompareAfterLabel,
                  photo: after,
                  onChange: () => _pick(isBefore: false),
                ),
              ),
            ],
          ),
          if (list.length < 2)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(s.reviewPhotosNeedSecond, textAlign: TextAlign.center),
            ),
        ],
      ],
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String idSuffix;
  final String title;
  final ReviewPhoto? photo;
  final VoidCallback onChange;

  const _PhotoCard({required this.idSuffix, required this.title, required this.photo, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final p = photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, textAlign: TextAlign.center, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Semantics(
          identifier: 'review-photos-$idSuffix',
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: p == null ? null : onChange,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: _PhotoImage(path: p?.path),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          p == null ? '' : DateFormat.yMMMd(locale).format(p.date),
          key: Key('review-photos-$idSuffix-date'),
          textAlign: TextAlign.center,
        ),
        if (p != null)
          Semantics(
            identifier: 'review-photos-$idSuffix-change',
            child: TextButton(onPressed: onChange, child: Text(S.of(context).reviewPhotosChange)),
          ),
      ],
    );
  }
}

/// A stored photo, cropped to fill its box; a flat placeholder while it loads
/// (on the web it may download on demand) or when it cannot be read.
class _PhotoImage extends StatelessWidget {
  final String? path;

  const _PhotoImage({required this.path});

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest);
    final p = path;
    if (p == null) return placeholder;
    return ValueListenableBuilder<int>(
      valueListenable: UserImageStorage.changes,
      builder: (context, _, _) => FutureBuilder<ImageProvider?>(
        future: UserImageStorage.imageProvider(p),
        builder: (context, snapshot) {
          final provider = snapshot.data;
          if (provider == null) return placeholder;
          return Image(
            image: provider,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => placeholder,
          );
        },
      ),
    );
  }
}

class _PhotoPickerSheet extends StatelessWidget {
  final List<ReviewPhoto> photos;

  const _PhotoPickerSheet({required this.photos});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final format = DateFormat.yMMMd(locale);
    return SafeArea(
      child: Semantics(
        identifier: 'review-photos-picker',
        child: GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            childAspectRatio: 0.62,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: photos.length,
          itemBuilder: (context, i) {
            final photo = photos[i];
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).pop(photo),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox.expand(child: _PhotoImage(path: photo.path)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(format.format(photo.date), style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
