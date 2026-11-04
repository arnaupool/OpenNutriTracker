import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/sync/photo_sync/photo_crypto.dart';
import 'package:opennutritracker/core/sync/photo_sync/photo_remote.dart';
import 'package:opennutritracker/core/sync/photo_sync/photo_sync_service.dart';
import 'package:opennutritracker/core/sync/sync_crypto.dart';
import 'package:opennutritracker/core/sync/sync_remote.dart';

const _profile = 'p1';
const _userId = 'user-1';
const _slug = 'meal_images/0f8e-meal.webp';
final _base = Uri.parse('https://ont.example/photos-api/v1/');

String _jwt(String sub, [String jti = 'a']) {
  String part(Map<String, dynamic> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'sub': sub, 'jti': jti})}.sig';
}

Future<String> _token({bool forceRefresh = false}) async => _jwt(_userId, forceRefresh ? 'fresh' : 'a');

class _FakeAccounts implements AccountSessionService {
  AccountLink? linked = const AccountLink(userId: _userId, email: 'ana@example.com');

  @override
  Future<AccountLink?> link(String profileId) async => profileId == _profile ? linked : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _FakeLocal implements PhotoLocalStore {
  final Map<String, Uint8List> files = {};

  @override
  Future<bool> exists(String slug) async => files.containsKey(slug);

  @override
  Future<Uint8List?> read(String slug) async => files[slug];

  @override
  Future<void> writeDownloaded(String slug, Uint8List bytes) async => files[slug] = bytes;
}

/// The photo service in memory, behind a [MockClient]: per-user storage, a
/// token is required, etags change on every write.
class _FakePhotoServer {
  final Map<String, Map<String, Uint8List>> users = {};
  final Map<String, String> etags = {};
  final List<String> requests = [];
  int _version = 0;

  /// While true, every request fails as if offline.
  bool offline = false;

  late final http.Client client = MockClient((request) async {
    requests.add('${request.method} ${request.url.path}');
    if (offline) throw http.ClientException('offline');
    final auth = request.headers['Authorization'] ?? '';
    if (!auth.startsWith('Bearer ')) return http.Response('', 401);
    final user = AccountSyncRemote.subjectOf(auth.substring(7));
    if (user == null) return http.Response('', 401);
    final store = users.putIfAbsent(user, () => {});
    final id = request.url.pathSegments.last;
    if (id.isEmpty) {
      return http.Response(
        jsonEncode({
          'photos': {for (final k in store.keys) k: etags['$user/$k']},
        }),
        200,
      );
    }
    switch (request.method) {
      case 'PUT':
        store[id] = request.bodyBytes;
        final etag = 'e${_version++}';
        etags['$user/$id'] = etag;
        return http.Response(jsonEncode({'etag': etag}), 200);
      case 'GET':
        final blob = store[id];
        return blob == null ? http.Response('', 404) : http.Response.bytes(blob, 200);
      case 'DELETE':
        store.remove(id);
        return http.Response('', 204);
    }
    return http.Response('', 405);
  });
}

class _Device {
  final _FakeAccounts accounts;
  final _FakeLocal local = _FakeLocal();
  final List<String?> referenced = [];
  final Box<dynamic> stateBox;
  int downloadedCalls = 0;
  late final PhotoSyncService service;

  _Device(this.stateBox, _FakePhotoServer server, {_FakeAccounts? accounts, bool enabled = true})
    : accounts = accounts ?? _FakeAccounts() {
    service = PhotoSyncService(
      accounts: this.accounts,
      stateBox: stateBox,
      referencedSlugs: () => referenced,
      remote: enabled ? (userId, token) => HttpPhotoRemote(_base, userId, token, client: server.client) : null,
      local: local,
      onDownloaded: () => downloadedCalls++,
      activeProfile: () => _profile,
    );
  }

  Future<PhotoSyncResult> sync(Uint8List key) => service.sync(_profile, _userId, key, _token);

  PhotoSyncState get state => PhotoSyncState(stateBox, _userId);

  static int _n = 0;

  static Future<_Device> create(_FakePhotoServer server, {_FakeAccounts? accounts, bool enabled = true}) async {
    final box = await Hive.openBox<dynamic>('photo-state${_n++}', bytes: Uint8List(0));
    return _Device(box, server, accounts: accounts, enabled: enabled);
  }
}

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('PhotoCrypto', () {
    test('photo id is 64 lowercase hex, stable, and depends on slug and key', () async {
      final key = SyncCrypto.generateKey();
      final crypto = await PhotoCrypto.derive(key);
      final id = await crypto.photoId(_slug);
      expect(id, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(await (await PhotoCrypto.derive(key)).photoId(_slug), id);
      expect(await crypto.photoId('recipe_images/r1.webp'), isNot(id));
      expect(await (await PhotoCrypto.derive(SyncCrypto.generateKey())).photoId(_slug), isNot(id));
      // Not the record ids' keyed hash: the photo id key is its own.
      expect(id, isNot(contains(SyncCrypto(key).opaqueId(_slug))));
    });

    test('encrypt and decrypt round trip; each blob is fresh and hides the bytes', () async {
      final crypto = await PhotoCrypto.derive(SyncCrypto.generateKey());
      final id = await crypto.photoId(_slug);
      final plain = _bytes('RIFF....WEBPVP8 a photo of lentils');
      final a = await crypto.encrypt(plain, id);
      final b = await crypto.encrypt(plain, id);
      expect(a, isNot(b));
      expect(a[0], PhotoCrypto.version);
      expect(utf8.decode(a, allowMalformed: true), isNot(contains('lentils')));
      expect(await crypto.decrypt(a, id), plain);
      expect(await crypto.decrypt(b, id), plain);
    });

    test('tampering, another photo id, another key, truncation and unknown versions fail', () async {
      final key = SyncCrypto.generateKey();
      final crypto = await PhotoCrypto.derive(key);
      final id = await crypto.photoId(_slug);
      final otherId = await crypto.photoId('meal_images/other.webp');
      final blob = await crypto.encrypt(_bytes('photo'), id);

      for (final i in [1, 13, blob.length - 1]) {
        final altered = Uint8List.fromList(blob)..[i] ^= 0x01;
        await expectLater(crypto.decrypt(altered, id), throwsA(isA<PhotoCryptoException>()), reason: 'byte $i');
      }
      await expectLater(crypto.decrypt(blob, otherId), throwsA(isA<PhotoCryptoException>()));
      final stranger = await PhotoCrypto.derive(SyncCrypto.generateKey());
      await expectLater(stranger.decrypt(blob, id), throwsA(isA<PhotoCryptoException>()));
      await expectLater(crypto.decrypt(Uint8List.sublistView(blob, 0, 20), id), throwsA(isA<PhotoCryptoException>()));
      final v2 = Uint8List.fromList(blob)..[0] = 2;
      await expectLater(crypto.decrypt(v2, id), throwsA(isA<PhotoCryptoException>()));
    });
  });

  group('PhotoSyncService', () {
    late _FakePhotoServer server;
    late Uint8List key;

    setUp(() {
      server = _FakePhotoServer();
      key = SyncCrypto.generateKey();
    });

    test('a saved photo goes up encrypted under its photo id; the server never sees the slug', () async {
      final a = await _Device.create(server);
      a.local.files[_slug] = _bytes('meal photo');
      a.referenced.add(_slug);
      await a.service.photoWritten(_slug);
      expect(PhotoSyncState.opOf(a.state.pending[_slug]!), PhotoSyncState.put);

      final result = await a.sync(key);

      expect(result.uploaded, 1);
      expect(a.state.pending, isEmpty);
      final id = await (await PhotoCrypto.derive(key)).photoId(_slug);
      final stored = server.users[_userId]![id]!;
      expect(utf8.decode(stored, allowMalformed: true), isNot(contains('meal photo')));
      expect(server.requests.any((r) => r.contains('meal_images') || r.contains('0f8e')), isFalse);
      // In step: the next sync sends nothing.
      server.requests.clear();
      final again = await a.sync(key);
      expect(again.uploaded + again.downloaded, 0);
      expect(server.requests.where((r) => r.startsWith('PUT')), isEmpty);
    });

    test('a synced record whose photo is missing here downloads, decrypts and stores it', () async {
      final a = await _Device.create(server);
      final b = await _Device.create(server);
      a.local.files[_slug] = _bytes('meal photo');
      a.referenced.add(_slug);
      await a.service.photoWritten(_slug);
      await a.sync(key);

      b.referenced.add(_slug);
      final result = await b.sync(key);

      expect(result.downloaded, 1);
      expect(b.local.files[_slug], _bytes('meal photo'));
      expect(b.downloadedCalls, 1);
      expect(b.state.pending, isEmpty, reason: 'a download is not queued for upload');

      // Replaced on A: B picks up the new photo.
      a.local.files[_slug] = _bytes('better photo');
      await a.service.photoWritten(_slug);
      await a.sync(key);
      final second = await b.sync(key);
      expect(second.downloaded, 1);
      expect(b.local.files[_slug], _bytes('better photo'));

      // Nothing new: nothing downloaded.
      expect((await b.sync(key)).downloaded, 0);
    });

    test('existing local photos referenced by records go up on the first sync without a queue', () async {
      final a = await _Device.create(server);
      a.local.files[_slug] = _bytes('old photo');
      a.local.files['progress_photos/w1.webp'] = _bytes('progress');
      a.local.files['recipe_images/orphan.webp'] = _bytes('not referenced');
      a.referenced.addAll([_slug, 'progress_photos/w1.webp', null, '../escape.webp']);

      final result = await a.sync(key);

      expect(result.uploaded, 2);
      expect(server.users[_userId], hasLength(2));
    });

    test('the upload queue survives a failed sync and is sent by the next one', () async {
      final a = await _Device.create(server);
      a.local.files[_slug] = _bytes('meal photo');
      a.referenced.add(_slug);
      await a.service.photoWritten(_slug);

      server.offline = true;
      await expectLater(a.sync(key), throwsA(isA<http.ClientException>()));
      expect(a.state.pending.keys, [_slug]);

      server.offline = false;
      final result = await a.sync(key);
      expect(result.uploaded, 1);
      expect(a.state.pending, isEmpty);
      expect(server.users[_userId], hasLength(1));
    });

    test('a change queued while an upload runs stays queued', () async {
      final a = await _Device.create(server);
      a.local.files[_slug] = _bytes('first');
      a.referenced.add(_slug);
      await a.service.photoWritten(_slug);
      final entry = a.state.pending[_slug]!;
      await a.service.photoWritten(_slug);
      final newer = a.state.pending[_slug]!;
      expect(newer, isNot(entry));
      await a.state.clearPending(_slug, entry: entry);
      expect(a.state.pending[_slug], newer);
    });

    test('deleting a photo deletes it on the account', () async {
      final a = await _Device.create(server);
      a.local.files[_slug] = _bytes('meal photo');
      a.referenced.add(_slug);
      await a.service.photoWritten(_slug);
      await a.sync(key);
      expect(server.users[_userId], hasLength(1));

      a.local.files.remove(_slug);
      a.referenced.clear();
      await a.service.photoDeleted(_slug);
      final result = await a.sync(key);

      expect(result.deleted, 1);
      expect(server.users[_userId], isEmpty);
      expect(a.state.pending, isEmpty);
    });

    test('a blob the server swapped for another photo is refused, not stored', () async {
      final a = await _Device.create(server);
      final b = await _Device.create(server);
      const other = 'meal_images/other.webp';
      a.local.files[_slug] = _bytes('photo 1');
      a.local.files[other] = _bytes('photo 2');
      a.referenced.addAll([_slug, other]);
      await a.sync(key);
      final crypto = await PhotoCrypto.derive(key);
      final store = server.users[_userId]!;
      store[await crypto.photoId(_slug)] = store[await crypto.photoId(other)]!;

      b.referenced.addAll([_slug, other]);
      final result = await b.sync(key);

      expect(result.unreadable, 1);
      expect(result.downloaded, 1);
      expect(b.local.files.containsKey(_slug), isFalse);
      expect(b.local.files[other], _bytes('photo 2'));
    });

    test('local profiles never queue or upload anything', () async {
      final local = _FakeAccounts()..linked = null;
      final d = await _Device.create(server, accounts: local);
      d.local.files[_slug] = _bytes('meal photo');
      d.referenced.add(_slug);
      await d.service.photoWritten(_slug);
      await d.service.photoDeleted(_slug);

      expect(d.stateBox.isEmpty, isTrue);
      expect(server.requests, isEmpty);
    });

    test('a build without a photo service queues and sends nothing', () async {
      final d = await _Device.create(server, enabled: false);
      d.local.files[_slug] = _bytes('meal photo');
      d.referenced.add(_slug);
      await d.service.photoWritten(_slug);
      final result = await d.sync(key);

      expect(result.uploaded, 0);
      expect(d.stateBox.isEmpty, isTrue);
      expect(server.requests, isEmpty);
    });

    test('another profile than the active one is not synced', () async {
      final a = await _Device.create(server);
      a.local.files[_slug] = _bytes('meal photo');
      a.referenced.add(_slug);
      await a.service.sync('p2', _userId, key, _token);
      expect(server.requests, isEmpty);
    });
  });

  group('HttpPhotoRemote', () {
    test('a 401 refreshes the token once and retries', () async {
      final tokens = <String>[];
      final client = MockClient((request) async {
        tokens.add(request.headers['Authorization']!);
        if (tokens.length == 1) return http.Response('', 401);
        return http.Response(jsonEncode({'photos': {}}), 200);
      });
      final remote = HttpPhotoRemote(_base, _userId, _token, client: client);
      expect(await remote.list(), isEmpty);
      expect(tokens, hasLength(2));
      expect(tokens[0], isNot(tokens[1]));
    });

    test('a token for another user is never sent', () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        return http.Response('', 200);
      });
      final remote = HttpPhotoRemote(
        _base,
        _userId,
        ({bool forceRefresh = false}) async => _jwt('someone-else'),
        client: client,
      );
      await expectLater(remote.list(), throwsA(isA<AccountTokenMismatchException>()));
      expect(requests, 0);
    });

    test('photo ids are validated before building a URL', () async {
      final remote = HttpPhotoRemote(_base, _userId, _token, client: MockClient((_) async => http.Response('', 200)));
      await expectLater(remote.get('../x'), throwsArgumentError);
    });

    test('service URL is the web origin', () {
      expect(
        photoServiceBaseUri(base: Uri.parse('https://nas.local:8443/#/home'))!.toString(),
        'https://nas.local:8443/photos-api/v1/',
      );
    });
  });
}
