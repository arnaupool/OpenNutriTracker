import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/domain/entity/body_measurement_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_body_measurement_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';
import 'package:opennutritracker/features/profile/presentation/body_measurements_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum _CompareBackground { white, dark }

/// Before/after photo comparator (FC-02). Layout mirrors MacroFactor's own
/// choice — two photos stacked vertically (not side-by-side, not a
/// slider) against a solid background, with a share action that captures
/// the composited widget to a PNG via `RenderRepaintBoundary`.
class ProgressPhotoCompareScreen extends StatefulWidget {
  final GetBodyMeasurementUsecase? getUsecase;

  const ProgressPhotoCompareScreen({super.key, this.getUsecase});

  @override
  State<ProgressPhotoCompareScreen> createState() =>
      _ProgressPhotoCompareScreenState();
}

class _ProgressPhotoCompareScreenState
    extends State<ProgressPhotoCompareScreen> {
  late final GetBodyMeasurementUsecase _getUsecase =
      widget.getUsecase ?? locator<GetBodyMeasurementUsecase>();

  final GlobalKey _captureKey = GlobalKey();

  bool _loading = true;
  List<BodyMeasurementEntity> _entries = const [];
  ProgressPhotoAngle _angle = ProgressPhotoAngle.front;
  DateTime? _beforeDate;
  DateTime? _afterDate;
  _CompareBackground _background = _CompareBackground.white;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _getUsecase.getAllEntries();
    entries.sort((a, b) => b.date.compareTo(a.date));
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  List<BodyMeasurementEntity> get _entriesForAngle =>
      _entries.where((e) => _angle.pathFor(e) != null).toList();

  BodyMeasurementEntity? _entryForDate(DateTime? date) {
    if (date == null) return null;
    for (final entry in _entries) {
      if (entry.date == date) return entry;
    }
    return null;
  }

  void _onAngleChanged(ProgressPhotoAngle angle) {
    setState(() {
      _angle = angle;
      // A date picked for one angle may not have a photo for the next —
      // start fresh rather than silently showing a placeholder.
      _beforeDate = null;
      _afterDate = null;
    });
  }

  Future<void> _pickDate({required bool isBefore}) async {
    final s = S.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(localeTag);
    final options = _entriesForAngle;
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                s.bodyMeasurementsCompareSelectDateLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final entry in options)
              ListTile(
                leading: _Thumb(path: _angle.pathFor(entry)!),
                title: Text(dateFormat.format(entry.date)),
                onTap: () => Navigator.of(context).pop(entry.date),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isBefore) {
        _beforeDate = picked;
      } else {
        _afterDate = picked;
      }
    });
  }

  Future<void> _share() async {
    try {
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/progress_comparison.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).exportImportErrorLabel)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final beforeEntry = _entryForDate(_beforeDate);
    final afterEntry = _entryForDate(_afterDate);
    final canShare = beforeEntry != null && afterEntry != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.bodyMeasurementsCompareTitle),
        actions: [
          if (canShare)
            Semantics(
              identifier: 'compare-share',
              child: IconButton(
                tooltip: s.bodyMeasurementsCompareShareTooltip,
                icon: const Icon(Icons.share_outlined),
                onPressed: _share,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Semantics(
                    identifier: 'compare-angle-chips',
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final angle in ProgressPhotoAngle.values)
                          ChoiceChip(
                            label: Text(angle.label(context)),
                            selected: _angle == angle,
                            onSelected: (_) => _onAngleChanged(angle),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_entriesForAngle.length < 2)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          s.bodyMeasurementsCompareEmptyLabel,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _DateSelectorButton(
                            identifier: 'compare-before-button',
                            label: s.bodyMeasurementsCompareBeforeLabel,
                            date: _beforeDate,
                            onTap: () => _pickDate(isBefore: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateSelectorButton(
                            identifier: 'compare-after-button',
                            label: s.bodyMeasurementsCompareAfterLabel,
                            date: _afterDate,
                            onTap: () => _pickDate(isBefore: false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Semantics(
                      identifier: 'compare-background-toggle',
                      child: SegmentedButton<_CompareBackground>(
                        segments: [
                          ButtonSegment(
                            value: _CompareBackground.white,
                            label: Text(
                              s.bodyMeasurementsCompareBackgroundWhiteLabel,
                            ),
                          ),
                          ButtonSegment(
                            value: _CompareBackground.dark,
                            label: Text(
                              s.bodyMeasurementsCompareBackgroundDarkLabel,
                            ),
                          ),
                        ],
                        selected: {_background},
                        onSelectionChanged: (next) =>
                            setState(() => _background = next.first),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: RepaintBoundary(
                        key: _captureKey,
                        child: Container(
                          color: _background == _CompareBackground.white
                              ? Colors.white
                              : Colors.black,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _ComparePhoto(entry: beforeEntry, angle: _angle),
                              const SizedBox(height: 16),
                              _ComparePhoto(entry: afterEntry, angle: _angle),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _DateSelectorButton extends StatelessWidget {
  final String identifier;
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateSelectorButton({
    required this.identifier,
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(localeTag);
    return Semantics(
      identifier: identifier,
      child: OutlinedButton(
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(date == null ? '—' : dateFormat.format(date!)),
          ],
        ),
      ),
    );
  }
}

class _ComparePhoto extends StatelessWidget {
  final BodyMeasurementEntity? entry;
  final ProgressPhotoAngle angle;

  const _ComparePhoto({required this.entry, required this.angle});

  @override
  Widget build(BuildContext context) {
    final path = entry == null ? null : angle.pathFor(entry!);
    if (path == null) {
      return AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      );
    }
    return FutureBuilder<ImageProvider?>(
      future: UserImageStorage.imageProvider(path),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const AspectRatio(aspectRatio: 3 / 4, child: SizedBox());
        }
        return Image(
          image: snapshot.data!,
          fit: BoxFit.contain,
          errorBuilder: (_, error, stack) => AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  final String path;

  const _Thumb({required this.path});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider?>(
      future: UserImageStorage.imageProvider(path),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox(width: 40, height: 40);
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image(
            image: snapshot.data!,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stack) => const SizedBox(
              width: 40,
              height: 40,
            ),
          ),
        );
      },
    );
  }
}
