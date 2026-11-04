import 'dart:async';
import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/sync/photo_sync/photo_crypto.dart';
import 'package:opennutritracker/core/sync/photo_sync/photo_remote.dart';
import 'package:opennutritracker/core/sync/sync_engine.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';

/// The photo bytes on this device, by slug (`meal_images/<code>.webp`).
abstract class PhotoLocalStore {
  Future<bool> exists(String slug);

  Future<Uint8List?> read(String slug);

  /// Stores bytes downloaded from the account. Must not report the write
  /// back as a local change (it would upload the photo again).
  Future<void> writeDownloaded(String slug, Uint8List bytes);
}

/// [PhotoLocalStore] over [UserImageStorage].
class UserImagePhotoLocalStore implements PhotoLocalStore {
  const UserImagePhotoLocalStore();

  @override
  Future<bool> exists(String slug) => UserImageStorage.exists(slug);

  @override
  Future<Uint8List?> read(String slug) => UserImageStorage.readBytes(slug);

  @override
  Future<void> writeDownloaded(String slug, Uint8List bytes) async {
    await UserImageStorage.writeBytes(slug, bytes, notify: false);
    await UserImageStorage.evictCache(slug);
  }
}

class PhotoSyncResult {
  final int uploaded;
  final int downloaded;
  final int deleted;
  final int unreadable;

  const PhotoSyncResult({this.uploaded = 0, this.downloaded = 0, this.deleted = 0, this.unreadable = 0});
}

/// What this device remembers about one account's photos, in the profile's
/// sync state box:
/// - `photos:<user id>/pending`: slug → `put:<n>` or `delete:<n>`, local
///   changes not on the account yet (the upload queue; it survives restarts
///   and waits while offline). `<n>` tells a change queued while an upload
///   ran from the one being uploaded.
/// - `photos:<user id>/<key id>/etags`: slug → etag of the copy this device
///   last uploaded or downloaded, to notice a photo replaced elsewhere. Per
///   data key, since a new key renames every photo.
class PhotoSyncState {
  static const String put = 'put';
  static const String delete = 'delete';

  final Box<dynamic> _box;
  final String _userId;

  PhotoSyncState(this._box, this._userId);

  String get _pendingKey => 'photos:$_userId/pending';

  String _etagsKey(String keyId) => 'photos:$_userId/$keyId/etags';

  static int _sequence = 0;

  /// slug → queue entry; [opOf] gives its operation.
  Map<String, String> get pending => _read(_pendingKey);

  static String opOf(String entry) => entry.split(':').first;

  Future<void> setPending(String slug, String op) =>
      _box.put(_pendingKey, {...pending, slug: '$op:${DateTime.now().microsecondsSinceEpoch}.${_sequence++}'});

  /// Removes [slug] from the queue, only if its entry is still [entry]
  /// when given (a newer change stays queued).
  Future<void> clearPending(String slug, {String? entry}) async {
    final current = pending;
    if (!current.containsKey(slug)) return;
    if (entry != null && current[slug] != entry) return;
    current.remove(slug);
    await _box.put(_pendingKey, current);
  }

  Map<String, String> etags(String keyId) => _read(_etagsKey(keyId));

  Future<void> setEtag(String keyId, String slug, String? etag) {
    final current = etags(keyId);
    if (etag == null) {
      current.remove(slug);
    } else {
      current[slug] = etag;
    }
    return _box.put(_etagsKey(keyId), current);
  }

  Map<String, String> _read(String key) {
    final raw = _box.get(key);
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
  }
}

/// Keeps the photos of the active profile's account in step with the
/// account photo store (photos-service/), end-to-end encrypted with
/// [PhotoCrypto].
///
/// - Saving or replacing a photo queues an upload, deleting one queues a
///   delete ([photoWritten], [photoDeleted], called by [UserImageStorage]).
///   Only profiles with an account queue anything; local profiles never
///   touch the network.
/// - After every account sync ([sync], called by [SyncService] once the
///   records are pulled), the queue is sent, every photo a synced record
///   references that exists here but not on the account goes up (the first
///   sync after signing in or after this update uploads existing photos
///   this way), and every referenced photo that is missing here or was
///   replaced elsewhere comes down, is decrypted and stored locally.
/// - A failure stops the run and leaves the queue as it was, so the next
///   sync (every few minutes, on resume, after any change) retries it.
class PhotoSyncService implements UserImageListener {
  /// Largest blob sent; the service refuses more than 4 MiB.
  static const int maxBlobBytes = 4 << 20;

  final _log = Logger('PhotoSyncService');
  final AccountSessionService _accounts;
  final Box<dynamic> _stateBox;
  final Iterable<String?> Function() _referencedSlugs;
  final PhotoLocalStore _local;

  /// Null when this build cannot reach a photo service (native): nothing
  /// is queued or sent.
  final PhotoRemote Function(String userId, AccessTokenSource accessToken)? _remote;
  final String Function() _activeProfile;

  /// Called after photos were downloaded, to redraw what shows them.
  final void Function() onDownloaded;

  /// For this app session: photo id → etag of an account copy that did not
  /// decrypt, and slugs too large to send, so each sync does not fetch or
  /// encrypt them again.
  final Map<String, String> _unreadable = {};
  final Set<String> _tooLarge = {};

  PhotoSyncService({
    required AccountSessionService accounts,
    required Box<dynamic> stateBox,
    required Iterable<String?> Function() referencedSlugs,
    required PhotoRemote Function(String userId, AccessTokenSource accessToken)? remote,
    PhotoLocalStore local = const UserImagePhotoLocalStore(),
    required this.onDownloaded,
    String Function()? activeProfile,
  }) : _accounts = accounts,
       _stateBox = stateBox,
       _referencedSlugs = referencedSlugs,
       _local = local,
       _remote = remote,
       _activeProfile = activeProfile ?? (() => ProfileScope.activeId);

  bool get enabled => _remote != null;

  @override
  Future<void> photoWritten(String slug) => _enqueue(slug, PhotoSyncState.put);

  @override
  Future<void> photoDeleted(String slug) => _enqueue(slug, PhotoSyncState.delete);

  Future<void> _enqueue(String slug, String op) async {
    if (!enabled) return;
    final clean = UserImageStorage.sanitizeRelative(slug);
    if (clean == null) return;
    try {
      final link = await _accounts.link(_activeProfile());
      if (link == null) return;
      await PhotoSyncState(_stateBox, link.userId).setPending(clean, op);
    } on Object catch (e) {
      _log.warning('Could not queue photo change', e);
    }
  }

  /// One photo sync for the account [userId] of [profileId] with data key
  /// [key]. Throws on a network or server error (the queue stays).
  Future<PhotoSyncResult> sync(String profileId, String userId, Uint8List key, AccessTokenSource accessToken) async {
    final factory = _remote;
    if (factory == null || profileId != _activeProfile()) return const PhotoSyncResult();
    final state = PhotoSyncState(_stateBox, userId);
    final referenced = <String>{
      for (final s in _referencedSlugs())
        if (s != null && UserImageStorage.sanitizeRelative(s) != null) UserImageStorage.sanitizeRelative(s)!,
    };
    final pending = state.pending;
    if (referenced.isEmpty && pending.isEmpty) return const PhotoSyncResult();

    final remote = factory(userId, accessToken);
    final crypto = await PhotoCrypto.derive(key);
    final keyId = SyncEngine.keyId(key);
    final ids = <String, String>{};
    Future<String> idOf(String slug) async => ids[slug] ??= await crypto.photoId(slug);

    var uploaded = 0;
    var downloaded = 0;
    var deleted = 0;
    var unreadable = 0;
    final uploads = <String>{};
    final skipDownload = <String>{};

    // 1. Queued deletions. A photo deleted and added again is an upload.
    for (final e in pending.entries.where((e) => PhotoSyncState.opOf(e.value) == PhotoSyncState.delete)) {
      final slug = e.key;
      if (referenced.contains(slug) && await _local.exists(slug)) {
        uploads.add(slug);
        continue;
      }
      await remote.delete(await idOf(slug));
      await state.clearPending(slug, entry: e.value);
      await state.setEtag(keyId, slug, null);
      skipDownload.add(slug);
      deleted++;
    }

    if (referenced.isEmpty) return PhotoSyncResult(deleted: deleted);
    final onServer = await remote.list();

    // 2. Uploads: queued photos the records reference, and referenced
    //    photos that exist here but not on the account. Queued photos no
    //    record references (an edit that was cancelled) wait.
    for (final e in pending.entries.where((e) => PhotoSyncState.opOf(e.value) == PhotoSyncState.put)) {
      if (referenced.contains(e.key)) {
        uploads.add(e.key);
      } else if (!await _local.exists(e.key)) {
        await state.clearPending(e.key, entry: e.value);
      }
    }
    for (final slug in referenced) {
      if (!onServer.containsKey(await idOf(slug)) && await _local.exists(slug)) uploads.add(slug);
    }
    uploads.removeAll(_tooLarge);
    for (final slug in uploads) {
      // The entry as of now: a change queued while this upload runs differs
      // and stays queued for the next sync.
      final entry = state.pending[slug];
      final bytes = await _local.read(slug);
      if (bytes == null) {
        if (entry != null) await state.clearPending(slug, entry: entry);
        continue;
      }
      final id = await idOf(slug);
      final blob = await crypto.encrypt(bytes, id);
      if (blob.length > maxBlobBytes) {
        _log.warning('Photo too large to sync (${blob.length} bytes)');
        _tooLarge.add(slug);
        if (entry != null) await state.clearPending(slug, entry: entry);
        continue;
      }
      final etag = await remote.put(id, blob);
      await state.setEtag(keyId, slug, etag);
      if (entry != null) await state.clearPending(slug, entry: entry);
      uploaded++;
    }

    // 3. Downloads: referenced photos missing here or replaced elsewhere.
    final known = state.etags(keyId);
    for (final slug in referenced) {
      if (uploads.contains(slug) || skipDownload.contains(slug)) continue;
      final id = await idOf(slug);
      final etag = onServer[id];
      if (etag == null) continue;
      // A photo this device never synced but already has is downloaded
      // too: the account's copy wins, as with records on the first sync.
      if (known[slug] == etag && await _local.exists(slug)) continue;
      if (_unreadable[id] == etag) continue;
      final blob = await remote.get(id);
      if (blob == null) continue;
      final Uint8List plain;
      try {
        plain = await crypto.decrypt(blob, id);
      } on PhotoCryptoException catch (e) {
        _log.warning('Unreadable photo on the account', e);
        _unreadable[id] = etag;
        unreadable++;
        continue;
      }
      await _local.writeDownloaded(slug, plain);
      await state.setEtag(keyId, slug, etag);
      downloaded++;
    }

    if (downloaded > 0) onDownloaded();
    _log.fine('Photo sync: up $uploaded, down $downloaded, deleted $deleted, unreadable $unreadable');
    return PhotoSyncResult(uploaded: uploaded, downloaded: downloaded, deleted: deleted, unreadable: unreadable);
  }
}
