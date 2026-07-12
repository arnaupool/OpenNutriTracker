import 'dart:io';

import 'package:flutter/material.dart';

/// A tappable-looking photo slot: an empty placeholder with an icon/label
/// until [imagePath] is set, then the picked image with a small remove
/// button overlaid. Shared between any screen that lets the user attach a
/// single photo for AI analysis (FR-02's Magic screen, FR-04's scan-label
/// fallback) — the picking/removal logic itself lives in the caller.
class PhotoPickerCard extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onRemove;
  final String placeholderLabel;
  final String removeButtonSemanticsId;

  const PhotoPickerCard({
    super.key,
    required this.imagePath,
    required this.onRemove,
    required this.placeholderLabel,
    required this.removeButtonSemanticsId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: imagePath == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(placeholderLabel),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(imagePath!), fit: BoxFit.cover),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Semantics(
                    identifier: removeButtonSemanticsId,
                    child: IconButton.filled(
                      icon: const Icon(Icons.close),
                      onPressed: onRemove,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
