import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/domain/entity/body_measurement_entity.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';
import 'package:opennutritracker/features/profile/presentation/body_measurements_screen.dart';

/// Full-screen, swipeable viewer for the photos logged on a single Body
/// Measurements entry. Opened by tapping a thumbnail on the entry list —
/// starts on whichever angle was tapped and lets the user swipe to the
/// other angles logged that day.
class ProgressPhotoViewerScreen extends StatefulWidget {
  final BodyMeasurementEntity entry;
  final ProgressPhotoAngle initialAngle;

  const ProgressPhotoViewerScreen({
    super.key,
    required this.entry,
    required this.initialAngle,
  });

  @override
  State<ProgressPhotoViewerScreen> createState() =>
      _ProgressPhotoViewerScreenState();
}

class _ProgressPhotoViewerScreenState
    extends State<ProgressPhotoViewerScreen> {
  late final List<ProgressPhotoAngle> _angles = [
    for (final angle in ProgressPhotoAngle.values)
      if (angle.pathFor(widget.entry) != null) angle,
  ];
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final initialIndex = _angles.indexOf(widget.initialAngle);
    _currentIndex = initialIndex < 0 ? 0 : initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dateLabel = DateFormat.yMMMd(localeTag).format(widget.entry.date);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('$dateLabel · ${_angles[_currentIndex].label(context)}'),
      ),
      body: Semantics(
        identifier: 'progress-photo-viewer',
        child: PageView.builder(
          controller: _pageController,
          itemCount: _angles.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            final path = _angles[index].pathFor(widget.entry)!;
            return FutureBuilder<String>(
              future: UserImageStorage.absolutePath(path),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                return InteractiveViewer(
                  child: Center(
                    child: Image.file(
                      File(snapshot.data!),
                      errorBuilder: (_, error, stack) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
