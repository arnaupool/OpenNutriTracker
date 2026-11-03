import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/sync/sync_engine.dart';
import 'package:opennutritracker/core/sync/sync_remote.dart';
import 'package:opennutritracker/core/sync/sync_state_store.dart';
import 'package:opennutritracker/core/sync/synced_box.dart';

/// In-memory stand-in for `public.sync_records` and `public.account_records`:
/// the same rules as the SQL (one server clock per write statement, older
/// `modified_at` ignored, rows scoped by token or user).
class FakeSyncServer {
  final Map<String, SyncRow> rows = {};
  var _tick = DateTime.utc(2026, 1, 1);

  int pushes = 0;
  int pulls = 0;
  int deletes = 0;

  /// Makes the next pushes fail (network down, server error).
  bool failPush = false;
  bool failDelete = false;

  FakeSyncRemote remote(String set) => FakeSyncRemote(this, set);

  List<SyncRow> rowsOf(String set) => [
    for (final e in rows.entries)
      if (e.key.startsWith('$set|')) e.value,
  ];
}

class FakeSyncRemote implements SyncRemote {
  final FakeSyncServer server;
  final String set;

  FakeSyncRemote(this.server, this.set);

  static int _compare(SyncRow a, SyncRow b) {
    final byTime = a.updatedAt!.compareTo(b.updatedAt!);
    if (byTime != 0) return byTime;
    final byBox = a.box.compareTo(b.box);
    return byBox != 0 ? byBox : a.id.compareTo(b.id);
  }

  @override
  Future<List<SyncRow>> pull({DateTime? since, SyncRow? after, int limit = 500}) async {
    server.pulls++;
    final matching = server.rowsOf(set).where((r) {
      if (after != null) return _compare(r, after) > 0;
      return since == null || r.updatedAt!.isAfter(since);
    }).toList()..sort(_compare);
    return matching.take(limit).toList();
  }

  @override
  Future<void> push(List<SyncRow> batch) async {
    if (server.failPush) throw const SyncRemoteException(503, 'down');
    server.pushes++;
    // One statement, one now(): every row of a batch shares updated_at.
    server._tick = server._tick.add(const Duration(seconds: 1));
    for (final r in batch) {
      final key = '$set|${r.box}|${r.id}';
      final existing = server.rows[key];
      if (existing != null && r.modifiedAt.isBefore(existing.modifiedAt)) continue;
      server.rows[key] = SyncRow(
        box: r.box,
        id: r.id,
        payload: r.payload,
        modifiedAt: r.modifiedAt,
        updatedAt: server._tick,
        deleted: r.deleted,
      );
    }
  }

  @override
  Future<SyncRow?> fetch(String box, String id) async => server.rows['$set|$box|$id'];

  @override
  Future<void> deleteAll() async {
    if (server.failDelete) throw const SyncRemoteException(503, 'down');
    server.deletes++;
    server.rows.removeWhere((k, _) => k.startsWith('$set|'));
  }
}

/// One simulated device: a "diary" box with auto-increment keys (records
/// matched by their own id) and a "profile" box keyed by a fixed key.
class FakeSyncDevice {
  final Box<Map> diary;
  final Box<Map> profile;
  final Box<dynamic> stateBox;
  final SyncEngine engine;

  FakeSyncDevice(this.diary, this.profile, this.stateBox, this.engine);

  static int _n = 0;

  static Future<FakeSyncDevice> create() async {
    final id = _n++;
    final diary = await Hive.openBox<Map>('diary$id', bytes: Uint8List(0));
    final profile = await Hive.openBox<Map>('profile$id', bytes: Uint8List(0));
    final stateBox = await Hive.openBox<dynamic>('state$id', bytes: Uint8List(0));
    final engine = SyncEngine(
      boxes: [
        SyncedBox<Map>(
          name: 'diary',
          box: diary,
          identityOf: (v, _) => v['id'] as String?,
          toJson: (v) => Map<String, dynamic>.from(v),
          fromJson: (j) => j,
        ),
        SyncedBox<Map>(
          name: 'profile',
          box: profile,
          identityOf: (_, k) => k?.toString(),
          toJson: (v) => Map<String, dynamic>.from(v),
          fromJson: (j) => j,
          naturalKey: true,
        ),
      ],
    );
    return FakeSyncDevice(diary, profile, stateBox, engine);
  }

  SyncStateStore get tokenState => SyncStateStore(stateBox);

  SyncStateStore accountState(String userId) => SyncStateStore.account(stateBox, userId);

  Map<String, Map> get entries => {for (final v in diary.values) v['id'] as String: v};

  Future<void> deleteEntry(String id) async {
    final key = diary.keys.firstWhere((k) => diary.get(k)!['id'] == id);
    await diary.delete(key);
  }

  Future<void> putEntry(String id, Map<String, dynamic> value) async {
    final key = diary.keys.where((k) => diary.get(k)!['id'] == id).firstOrNull;
    if (key == null) {
      await diary.add({'id': id, ...value});
    } else {
      await diary.put(key, {'id': id, ...value});
    }
  }
}
