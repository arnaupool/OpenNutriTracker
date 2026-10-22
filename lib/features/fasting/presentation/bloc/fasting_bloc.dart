import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/features/fasting/domain/entity/fasting_session_entity.dart';
import 'package:opennutritracker/features/fasting/domain/fasting_safety.dart';
import 'package:opennutritracker/features/fasting/domain/usecase/acknowledge_fasting_warning_usecase.dart';
import 'package:opennutritracker/features/fasting/domain/usecase/delete_fasting_session_usecase.dart';
import 'package:opennutritracker/features/fasting/domain/usecase/end_fasting_usecase.dart';
import 'package:opennutritracker/features/fasting/domain/usecase/get_active_fasting_session_usecase.dart';
import 'package:opennutritracker/features/fasting/domain/usecase/get_fasting_history_usecase.dart';
import 'package:opennutritracker/features/fasting/domain/usecase/save_fasting_session_usecase.dart';
import 'package:opennutritracker/features/fasting/domain/usecase/start_fasting_usecase.dart';

sealed class FastingEvent extends Equatable {
  const FastingEvent();

  @override
  List<Object?> get props => [];
}

class FastingLoadRequested extends FastingEvent {
  const FastingLoadRequested();
}

class FastingWarningAcknowledged extends FastingEvent {
  const FastingWarningAcknowledged();
}

class FastingStartRequested extends FastingEvent {
  final int targetDurationMinutes;

  const FastingStartRequested(this.targetDurationMinutes);

  @override
  List<Object?> get props => [targetDurationMinutes];
}

/// Closes the running session. [end] is when the user actually ate; null
/// means now.
class FastingEndRequested extends FastingEvent {
  final DateTime? end;

  const FastingEndRequested({this.end});

  @override
  List<Object?> get props => [end];
}

/// Adds or edits a session: a past fast typed in by hand, an edited history
/// entry, or the running session with a corrected start time. Invalid
/// windows are dropped here; the screen validates first to explain why.
class FastingSessionSaved extends FastingEvent {
  final FastingSessionEntity session;

  const FastingSessionSaved(this.session);

  @override
  List<Object?> get props => [session];
}

class FastingSessionDeleted extends FastingEvent {
  final String id;

  const FastingSessionDeleted(this.id);

  @override
  List<Object?> get props => [id];
}

/// Internal tick driven by the bloc's own periodic timer. Surfaces so the UI
/// can re-render the elapsed/remaining strings every second.
class FastingTicked extends FastingEvent {
  final DateTime now;

  const FastingTicked(this.now);

  @override
  List<Object?> get props => [now];
}

sealed class FastingState extends Equatable {
  const FastingState();

  @override
  List<Object?> get props => [];
}

class FastingInitial extends FastingState {
  const FastingInitial();
}

class FastingWarningRequired extends FastingState {
  const FastingWarningRequired();
}

class FastingIdle extends FastingState {
  /// Closed sessions, newest first.
  final List<FastingSessionEntity> history;

  /// The session the user just ended, for a one-line summary.
  final FastingSessionEntity? lastEnded;

  const FastingIdle({this.history = const [], this.lastEnded});

  @override
  List<Object?> get props => [history, lastEnded];
}

class FastingActive extends FastingState {
  final FastingSessionEntity session;
  final DateTime now;
  final List<FastingSessionEntity> history;

  const FastingActive({
    required this.session,
    required this.now,
    this.history = const [],
  });

  Duration get elapsed => session.elapsedAt(now);
  Duration get target => session.targetDuration;
  Duration get remaining {
    final diff = target - elapsed;
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get hasReachedTarget => elapsed >= target;

  Duration get pastTarget => hasReachedTarget ? elapsed - target : Duration.zero;

  /// Past the point where fasting should be medically supervised.
  bool get isExtended =>
      elapsed >= const Duration(hours: FastingSafety.extendedFastHours);

  /// Open longer than any target the app allows: most likely a session the
  /// user forgot to end.
  bool get isStale =>
      elapsed > const Duration(hours: FastingSafety.maxTargetHours);

  @override
  List<Object?> get props => [session, now, history];
}

class FastingBloc extends Bloc<FastingEvent, FastingState> {
  final GetConfigUsecase _getConfig;
  final GetActiveFastingSessionUseCase _getActive;
  final GetFastingHistoryUseCase _getHistory;
  final StartFastingUseCase _start;
  final EndFastingUseCase _end;
  final SaveFastingSessionUseCase _save;
  final DeleteFastingSessionUseCase _delete;
  final AcknowledgeFastingWarningUseCase _acknowledge;

  Timer? _ticker;

  FastingBloc(
    this._getConfig,
    this._getActive,
    this._getHistory,
    this._start,
    this._end,
    this._save,
    this._delete,
    this._acknowledge,
  ) : super(const FastingInitial()) {
    on<FastingLoadRequested>(_onLoad);
    on<FastingWarningAcknowledged>(_onAcknowledged);
    on<FastingStartRequested>(_onStart);
    on<FastingEndRequested>(_onEnd);
    on<FastingSessionSaved>(_onSaved);
    on<FastingSessionDeleted>(_onDeleted);
    on<FastingTicked>(_onTick);
  }

  Future<void> _onLoad(
    FastingLoadRequested event,
    Emitter<FastingState> emit,
  ) async {
    final config = await _getConfig.getConfig();
    if (config.fastingWarningVersion < FastingSafety.warningVersion) {
      emit(const FastingWarningRequired());
      return;
    }
    await _emitFromCurrentSession(emit);
  }

  Future<void> _onAcknowledged(
    FastingWarningAcknowledged event,
    Emitter<FastingState> emit,
  ) async {
    await _acknowledge();
    await _emitFromCurrentSession(emit);
  }

  Future<void> _emitFromCurrentSession(
    Emitter<FastingState> emit, {
    FastingSessionEntity? lastEnded,
  }) async {
    final active = await _getActive();
    final history = await _getHistory();
    if (active == null) {
      _ticker?.cancel();
      emit(FastingIdle(history: history, lastEnded: lastEnded));
      return;
    }
    emit(FastingActive(session: active, now: DateTime.now(), history: history));
    _startTicker();
  }

  Future<void> _onStart(
    FastingStartRequested event,
    Emitter<FastingState> emit,
  ) async {
    if (state is FastingActive) return;
    if (event.targetDurationMinutes < 0 ||
        event.targetDurationMinutes > FastingSafety.maxTargetHours * 60) {
      return;
    }
    final current = state;
    final session = await _start(
      targetDurationMinutes: event.targetDurationMinutes,
    );
    emit(
      FastingActive(
        session: session,
        now: DateTime.now(),
        history: current is FastingIdle ? current.history : const [],
      ),
    );
    _startTicker();
  }

  Future<void> _onEnd(
    FastingEndRequested event,
    Emitter<FastingState> emit,
  ) async {
    final current = state;
    if (current is! FastingActive) return;
    final now = DateTime.now();
    final end = event.end;
    if (end != null && end.isAfter(now)) return;
    _ticker?.cancel();
    final ended = await _end(current.session, end: end ?? now);
    await _emitFromCurrentSession(emit, lastEnded: ended);
  }

  Future<void> _onSaved(
    FastingSessionSaved event,
    Emitter<FastingState> emit,
  ) async {
    await _save(event.session);
    await _emitFromCurrentSession(emit);
  }

  Future<void> _onDeleted(
    FastingSessionDeleted event,
    Emitter<FastingState> emit,
  ) async {
    await _delete(event.id);
    await _emitFromCurrentSession(emit);
  }

  Future<void> _onTick(FastingTicked event, Emitter<FastingState> emit) async {
    final current = state;
    if (current is! FastingActive) return;
    // Reaching the target only changes what the screen shows; the session
    // stays open until the user ends it, so the stored end is the real one.
    emit(
      FastingActive(
        session: current.session,
        now: event.now,
        history: current.history,
      ),
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      add(FastingTicked(DateTime.now()));
    });
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }
}
