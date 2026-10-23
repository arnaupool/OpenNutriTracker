import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:path_provider/path_provider.dart';

/// Three flavours of user-attached photo the app persists locally.
///
/// Recipes live under `recipe_images/`, custom meals live under
/// `meal_images/`, progress photos live under `progress_photos/`. The
/// subdirectory split keeps the namespaces distinct (so export zips can
/// label them clearly and a runaway filename collision on one side can't
/// quietly overwrite the other) while sharing one compression pipeline.
enum UserImageKind {
  recipe('recipe_images'),
  meal('meal_images'),
  progressPhoto('progress_photos');

  const UserImageKind(this.subdir);

  final String subdir;
}

/// Resolves the storage location of user-attached photos for recipes,
/// custom meals and progress photos. Only the *relative* slug (e.g.
/// `meal_images/<code>.webp`) is persisted on the matching DBO; the
/// concrete storage location is resolved on demand so the data survives
/// across app reinstalls and iOS sandbox refreshes.
///
/// Native (Android/iOS) keeps the original on-disk layout under the
/// app's documents directory. The web build has no real filesystem, so
/// it stores the same compressed bytes in a Hive box
/// (`UserImageBytesBox`, opened alongside every other box in
/// `HiveDBProvider` — same AES cipher, so progress photos stay
/// encrypted at rest there too) keyed by the relative slug. `dart:io`'s
/// `File`/`Directory` compile fine for web (Flutter ships stub types)
/// but throw at runtime, so the split below is a plain `kIsWeb` branch
/// rather than a separate conditional-import file.
///
/// Photos are stored as WebP at quality 80, capped at 1024px on the
/// longest edge — small enough that an export zip of a few dozen
/// recipes and meals stays in the low-megabyte range, while still
/// being plenty crisp for a list thumbnail and the detail-screen
/// header. WebP roughly halves the bytes of an equivalent-quality JPEG
/// and is supported natively on every Android and iOS version the app
/// targets, and by `flutter_image_compress`'s web (canvas-based)
/// implementation.
class UserImageStorage {
  static const String _extension = 'webp';
  // The active profile's physical box name (see ProfileScope).
  static String get webBoxName => ProfileScope.box('UserImageBytesBox');

  static Box<Uint8List> get _webBox => Hive.box<Uint8List>(webBoxName);

  /// The relative slug stored on the DBO for a given owner id.
  static String relativePathFor(UserImageKind kind, String ownerId) =>
      '${kind.subdir}/$ownerId.$_extension';

  /// Splits a relative slug back into its parts. Returns null for any
  /// path that doesn't sit inside one of the known image
  /// subdirectories. Defensive so that a malformed value from an old
  /// export can't escape its images directory.
  static String? sanitizeRelative(String relative) {
    final parts = relative.split('/');
    if (parts.length != 2) return null;
    final knownDirs = {for (final k in UserImageKind.values) k.subdir};
    if (!knownDirs.contains(parts[0])) return null;
    if (parts[1].isEmpty || parts[1].contains('..')) return null;
    return '${parts[0]}/${parts[1]}';
  }

  /// True when `relative` is one of our user-image slugs. Used by
  /// import to decide whether a zip entry should be restored.
  static bool isUserImagePath(String relative) =>
      sanitizeRelative(relative) != null;

  /// Absolute on-disk path for `relativePath`. Native only — has no
  /// meaning on web, where photos live in a Hive box instead. Kept for
  /// the native file-writing paths below and for callers that only ever
  /// run on native (e.g. the Android/iOS-only parts of import/export).
  static Future<String> absolutePath(String relativePath) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$relativePath';
  }

  /// Absolute path to the relevant images directory itself. Created
  /// if missing. Native only, same caveat as [absolutePath].
  static Future<Directory> ensureDirectory(UserImageKind kind) async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${dir.path}/${kind.subdir}');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  /// Re-encodes `sourceBytes` to WebP (quality 80, longest edge
  /// 1024px) and persists it under `<ownerId>.webp` in the matching
  /// image kind's storage, returning the relative slug to persist on
  /// the owning DBO.
  ///
  /// If the on-device WebP encoder is unavailable for some reason
  /// (very old hardware, simulator quirks), `FlutterImageCompress`
  /// returns `null` and we fall back to the source bytes verbatim —
  /// the file extension stays `.webp` either way so callers don't have
  /// to branch on it.
  static Future<String> importFrom({
    required UserImageKind kind,
    required String ownerId,
    required Uint8List sourceBytes,
  }) async {
    final relative = relativePathFor(kind, ownerId);
    final compressed = await _compressToWebP(sourceBytes) ?? sourceBytes;
    if (kIsWeb) {
      await _webBox.put(relative, compressed);
    } else {
      final imagesDir = await ensureDirectory(kind);
      final destPath = '${imagesDir.path}/$ownerId.$_extension';
      await File(destPath).writeAsBytes(compressed, flush: true);
    }
    return relative;
  }

  /// Removes the photo at `relativePath` if it exists. Silent no-op
  /// when it's already gone — callers don't need to special-case that.
  static Future<void> delete(String relativePath) async {
    final sanitized = sanitizeRelative(relativePath);
    if (sanitized == null) return;
    if (kIsWeb) {
      await _webBox.delete(sanitized);
      return;
    }
    final absolute = await absolutePath(sanitized);
    final file = File(absolute);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Reads the raw (already-compressed) bytes for `relativePath`, or
  /// null if missing. The one place export/import and any custom
  /// display widget should go through instead of touching `File`
  /// directly, since it works the same on native and web.
  static Future<Uint8List?> readBytes(String relativePath) async {
    final sanitized = sanitizeRelative(relativePath);
    if (sanitized == null) return null;
    if (kIsWeb) return _webBox.get(sanitized);
    final absolute = await absolutePath(sanitized);
    final file = File(absolute);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// Writes raw (already-compressed) bytes directly at `relativePath`
  /// without going through the WebP re-encode step — used by import,
  /// which restores bytes that were already compressed on export.
  static Future<void> writeBytes(
    String relativePath,
    Uint8List bytes,
  ) async {
    final sanitized = sanitizeRelative(relativePath);
    if (sanitized == null) return;
    if (kIsWeb) {
      await _webBox.put(sanitized, bytes);
      return;
    }
    final parts = sanitized.split('/');
    final imagesDir = await ensureDirectory(
      UserImageKind.values.firstWhere((k) => k.subdir == parts[0]),
    );
    await File('${imagesDir.path}/${parts[1]}').writeAsBytes(
      bytes,
      flush: true,
    );
  }

  /// An [ImageProvider] for `relativePath` (`FileImage` on native,
  /// `MemoryImage` on web), or null if the photo is missing. This is
  /// the one thing every display call site (list thumbnails, avatars,
  /// `DecorationImage` backgrounds, the full-screen viewer) should use
  /// instead of building `Image.file(File(await absolutePath(...)))`
  /// by hand, so the native/web split lives in exactly one place.
  static Future<ImageProvider?> imageProvider(String relativePath) async {
    if (kIsWeb) {
      final bytes = await readBytes(relativePath);
      return bytes == null ? null : MemoryImage(bytes);
    }
    final sanitized = sanitizeRelative(relativePath);
    if (sanitized == null) return null;
    final absolute = await absolutePath(sanitized);
    final file = File(absolute);
    if (!await file.exists()) return null;
    return FileImage(file);
  }

  /// Busts Flutter's image cache for `relativePath` after its bytes
  /// have been replaced in place (same relative path, new content) —
  /// otherwise `Image`/`CircleAvatar`/`DecorationImage` would keep
  /// showing the previous photo since the cache key is unchanged.
  static Future<void> evictCache(String relativePath) async {
    final provider = await imageProvider(relativePath);
    await provider?.evict();
  }

  static Future<Uint8List?> _compressToWebP(Uint8List sourceBytes) async {
    try {
      return await FlutterImageCompress.compressWithList(
        sourceBytes,
        format: CompressFormat.webp,
        quality: 80,
        minWidth: 1024,
        minHeight: 1024,
        // `minWidth`/`minHeight` are upper bounds for the *longest*
        // edge when the source exceeds them; the compressor preserves
        // aspect ratio. Shorter-edge images pass through untouched.
      );
    } catch (_) {
      return null;
    }
  }
}
