import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/dbo/app_theme_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/features/fasting/data/repository/fasting_repository.dart';
import 'package:opennutritracker/features/fasting/domain/entity/fasting_session_entity.dart';
import 'package:opennutritracker/features/fasting/domain/usecase/acknowledge_fasting_warning_usecase.dart';
import 'package:opennutritracker/features/fasting/domain/fasting_safety.dart';
import 'package:opennutritracker/features/fasting/domain/usecase/delete_fasting_session_usecase.dart';
import 'package:opennutritracker/features/fasting/domain/usecase/end_fasting_usecase.dart';
import 'package:opennutritracker/features/fasting/domain/usecase/get_active_fasting_session_usecase.dart';
import 'package:opennutritracker/features/fasting/domain/usecase/get_fasting_history_usecase.dart';
import 'package:opennutritracker/features/fasting/domain/usecase/save_fasting_session_usecase.dart';
import 'package:opennutritracker/features/fasting/domain/usecase/start_fasting_usecase.dart';
import 'package:opennutritracker/features/fasting/presentation/bloc/fasting_bloc.dart';

/// In-memory fake of [FastingRepository]. Holds sessions by id and tracks
/// add/update calls so the bloc tests can assert side-effects without needing
/// Hive or a mocking library.
class _FakeFastingRepository implements FastingRepository {
  final Map<String, FastingSessionEntity> _sessions = {};
  int addCalls = 0;
  int updateCalls = 0;
  FastingSessionEntity? lastUpdated;

  @override
  Future<void> addSession(FastingSessionEntity session) async {
    addCalls++;
    _sessions[session.id] = session;
  }

  @override
  Future<void> updateSession(FastingSessionEntity session) async {
    updateCalls++;
    lastUpdated = session;
    _sessions[session.id] = session;
  }

  @override
  Future<FastingSessionEntity?> getActiveSession() async {
    for (final s in _sessions.values) {
      if (s.isActive) return s;
    }
    return null;
  }

  @override
  Future<void> deleteSession(String id) async {
    _sessions.remove(id);
  }

  @override
  Future<FastingSessionEntity?> getSession(String id) async => _sessions[id];

  @override
  Future<List<FastingSessionEntity>> allSessions() async =>
      _sessions.values.toList();
}

/// Minimal stub for [ConfigRepository] — only the surface the bloc reaches
/// (getConfig + setFastingWarningAcknowledged) needs to behave.
class _FakeConfigRepository implements ConfigRepository {
  bool acknowledged;
  int version;

  _FakeConfigRepository(this.acknowledged, {this.version = 0});

  @override
  Future<ConfigEntity> getConfig() async {
    return ConfigEntity(
      true,
      true,
      false,
      AppThemeEntity.system,
      fastingWarningAcknowledged: acknowledged,
      fastingWarningVersion: version,
    );
  }

  @override
  Future<void> setFastingWarningAcknowledged(bool value) async {
    acknowledged = value;
  }

  @override
  Future<void> setFastingWarningVersion(int value) async {
    version = value;
  }

  // The bloc never touches anything else, so satisfy the remaining surface
  // with noClassReflection-style no-ops.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Hide an unused import warning by mentioning the symbol where the
  // analyzer can see it. AppThemeDBO is reachable via fromConfigDBO but not
  // otherwise referenced in this file.
  // ignore: unused_local_variable
  final _ = AppThemeDBO.system;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  FastingSessionEntity closed(
    String id,
    DateTime start,
    Duration length, {
    int targetMinutes = 16 * 60,
  }) {
    return FastingSessionEntity(
      id: id,
      startedAt: start,
      targetDurationMinutes: targetMinutes,
    ).endedAtTime(start.add(length));
  }

  group('FastingBloc', () {
    late _FakeFastingRepository fastingRepo;
    late _FakeConfigRepository configRepo;
    late FastingBloc bloc;

    setUp(() {
      fastingRepo = _FakeFastingRepository();
      configRepo = _FakeConfigRepository(
        true,
        version: FastingSafety.warningVersion,
      );
      bloc = FastingBloc(
        GetConfigUsecase(configRepo),
        GetActiveFastingSessionUseCase(fastingRepo),
        GetFastingHistoryUseCase(fastingRepo),
        StartFastingUseCase(fastingRepo),
        EndFastingUseCase(fastingRepo),
        SaveFastingSessionUseCase(fastingRepo),
        DeleteFastingSessionUseCase(fastingRepo),
        AcknowledgeFastingWarningUseCase(configRepo),
      );
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state is FastingInitial', () {
      expect(bloc.state, isA<FastingInitial>());
    });

    test(
      'ending before the target records cancelledAt, not completedAt',
      () async {
        bloc.add(const FastingStartRequested(60));
        await settle();
        expect(bloc.state, isA<FastingActive>());
        expect(fastingRepo.addCalls, 1);

        bloc.add(const FastingEndRequested());
        await settle();

        expect(bloc.state, isA<FastingIdle>());
        expect(fastingRepo.updateCalls, 1);
        expect(fastingRepo.lastUpdated!.cancelledAt, isNotNull);
        expect(
          fastingRepo.lastUpdated!.completedAt,
          isNull,
          reason:
              'A session closed before its target must not be recorded as '
              'completed; the two outcomes are tracked separately so neither '
              'path reads as failure.',
        );
        final idle = bloc.state as FastingIdle;
        expect(idle.lastEnded, isNotNull);
        expect(idle.history, hasLength(1));
      },
    );

    test(
      'reaching the target keeps the session open until the user ends it',
      () async {
        bloc.add(const FastingStartRequested(0));
        await settle();
        bloc.add(FastingTicked(DateTime.now().add(const Duration(hours: 1))));
        await settle();

        final active = bloc.state as FastingActive;
        expect(active.hasReachedTarget, isTrue);
        expect(active.session.isActive, isTrue);
        expect(
          fastingRepo.updateCalls,
          0,
          reason:
              'The timer must not write an end time on its own, or the '
              'record would say the fast ended when the app happened to tick.',
        );
      },
    );

    test(
      'ending at a picked time stores that time, as completedAt once the '
      'target was reached',
      () async {
        final start = DateTime.now().subtract(const Duration(hours: 20));
        await fastingRepo.addSession(
          FastingSessionEntity(
            id: 'a',
            startedAt: start,
            targetDurationMinutes: 16 * 60,
          ),
        );
        bloc.add(const FastingLoadRequested());
        await settle();
        expect(bloc.state, isA<FastingActive>());

        final ateAt = start.add(const Duration(hours: 17));
        bloc.add(FastingEndRequested(end: ateAt));
        await settle();

        expect(fastingRepo.lastUpdated!.completedAt, ateAt);
        expect(fastingRepo.lastUpdated!.cancelledAt, isNull);
      },
    );

    test('an end time in the future is ignored', () async {
      bloc.add(const FastingStartRequested(60));
      await settle();
      bloc.add(
        FastingEndRequested(end: DateTime.now().add(const Duration(hours: 1))),
      );
      await settle();
      expect(bloc.state, isA<FastingActive>());
      expect(fastingRepo.updateCalls, 0);
    });

    test('targets above the 72 h cap are refused', () async {
      bloc.add(const FastingStartRequested(73 * 60));
      await settle();
      expect(fastingRepo.addCalls, 0);
    });

    test(
      'an accepted warning from before versioning shows the new one',
      () async {
        configRepo
          ..acknowledged = true
          ..version = 0;
        bloc.add(const FastingLoadRequested());
        await settle();
        expect(bloc.state, isA<FastingWarningRequired>());

        bloc.add(const FastingWarningAcknowledged());
        await settle();
        expect(bloc.state, isA<FastingIdle>());
        expect(configRepo.version, FastingSafety.warningVersion);
      },
    );

    test('saving and deleting a past fast updates the history', () async {
      final start = DateTime.now().subtract(const Duration(days: 2));
      bloc.add(
        FastingSessionSaved(closed('p', start, const Duration(hours: 15))),
      );
      await settle();
      expect((bloc.state as FastingIdle).history.single.id, 'p');

      bloc.add(const FastingSessionDeleted('p'));
      await settle();
      expect((bloc.state as FastingIdle).history, isEmpty);
    });

    test('an overlapping past fast is not stored', () async {
      final start = DateTime.now().subtract(const Duration(days: 2));
      bloc.add(
        FastingSessionSaved(closed('p', start, const Duration(hours: 16))),
      );
      await settle();
      bloc.add(
        FastingSessionSaved(
          closed(
            'q',
            start.add(const Duration(hours: 4)),
            const Duration(hours: 16),
          ),
        ),
      );
      await settle();
      expect((bloc.state as FastingIdle).history.map((s) => s.id), ['p']);
    });
  });

  group('FastingSafety.validateWindow', () {
    final now = DateTime(2026, 10, 22, 12);

    test('accepts a normal past window', () {
      expect(
        FastingSafety.validateWindow(
          start: now.subtract(const Duration(hours: 20)),
          end: now.subtract(const Duration(hours: 4)),
          now: now,
          others: const [],
        ),
        isNull,
      );
    });

    test('rejects future start and end', () {
      expect(
        FastingSafety.validateWindow(
          start: now.add(const Duration(minutes: 1)),
          end: null,
          now: now,
          others: const [],
        ),
        FastingWindowError.startInFuture,
      );
      expect(
        FastingSafety.validateWindow(
          start: now.subtract(const Duration(hours: 1)),
          end: now.add(const Duration(minutes: 1)),
          now: now,
          others: const [],
        ),
        FastingWindowError.endInFuture,
      );
    });

    test('rejects an end at or before the start', () {
      final t = now.subtract(const Duration(hours: 3));
      expect(
        FastingSafety.validateWindow(
          start: t,
          end: t,
          now: now,
          others: const [],
        ),
        FastingWindowError.endBeforeStart,
      );
    });

    test('rejects records longer than 7 days', () {
      expect(
        FastingSafety.validateWindow(
          start: now.subtract(const Duration(days: 8)),
          end: now.subtract(const Duration(hours: 1)),
          now: now,
          others: const [],
        ),
        FastingWindowError.tooLong,
      );
    });

    test(
      'rejects overlaps, including with the running session, but not with '
      'itself or back-to-back windows',
      () {
        final running = FastingSessionEntity(
          id: 'run',
          startedAt: now.subtract(const Duration(hours: 2)),
          targetDurationMinutes: 960,
        );
        final past = closed(
          'past',
          now.subtract(const Duration(hours: 30)),
          const Duration(hours: 16),
        );
        expect(
          FastingSafety.validateWindow(
            start: now.subtract(const Duration(hours: 5)),
            end: now.subtract(const Duration(hours: 1)),
            now: now,
            others: [running],
          ),
          FastingWindowError.overlaps,
        );
        expect(
          FastingSafety.validateWindow(
            start: past.startedAt,
            end: past.endedAt,
            now: now,
            others: [past],
            ignoreId: 'past',
          ),
          isNull,
        );
        expect(
          FastingSafety.validateWindow(
            start: past.endedAt!,
            end: running.startedAt,
            now: now,
            others: [past, running],
          ),
          isNull,
        );
      },
    );

    test('targets: 1 to 72 h valid, over 24 h needs confirmation', () {
      expect(FastingSafety.isValidTargetHours(0), isFalse);
      expect(FastingSafety.isValidTargetHours(72), isTrue);
      expect(FastingSafety.isValidTargetHours(73), isFalse);
      expect(FastingSafety.needsExtendedConfirmation(24 * 60), isFalse);
      expect(FastingSafety.needsExtendedConfirmation(24 * 60 + 1), isTrue);
      expect(
        FastingSafety.presetHours.every(
          (h) => h <= FastingSafety.extendedFastHours,
        ),
        isTrue,
        reason: 'No one-tap preset may skip the extended-fast confirmation.',
      );
    });
  });
}
