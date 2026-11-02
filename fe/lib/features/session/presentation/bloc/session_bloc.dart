import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:barz/features/session/domain/usecases/session_usecase.dart';
import 'session_event.dart';
import 'session_state.dart';

/// Manages the user session state across the entire app.
///
/// This BLoC is responsible for:
/// - Initializing the session after login
/// - Determining whether to show client or business experience
/// - Managing active bar selection for business users
/// - Handling staff invitation acceptance
class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final SessionUsecase _sessionUsecase;
  final LoginUsecase _loginUsecase;

  SessionBloc({required this._sessionUsecase, required this._loginUsecase})
    : super(const SessionState.initial()) {
    on<InitializeSession>(_onInitialize);
    on<ClearPendingInvitation>((event, emit) {
      final current = state;
      if (current is SessionReady) {
        emit(
          current.copyWith(
            session: current.session.withoutInvitation(event.code),
          ),
        );
      }
    });
    on<RefreshBarAccess>(_onRefreshBarAccess);
    on<SwitchActiveBar>(_onSwitchActiveBar);
    on<AcceptInvitation>(_onAcceptInvitation);
    on<BarCreated>(_onBarCreated);
    on<LogoutSession>(_onLogout);
    on<SwitchToClientMode>(_onSwitchToClientMode);
    on<SwitchToBusinessMode>(_onSwitchToBusinessMode);
  }

  Future<SessionState>? _entryInitialization;
  int _generation = 0;

  Future<SessionState> initializeForEntry({bool force = false}) async {
    if (_entryInitialization != null) return _entryInitialization!;
    if (!force && (state is SessionReady || state is SessionError)) {
      return state;
    }
    final completed = stream.firstWhere(
      (s) => s is SessionReady || s is SessionError || s is SessionLoggedOut,
    );
    _entryInitialization = completed;
    add(const SessionEvent.initialize());
    try {
      return await completed;
    } finally {
      _entryInitialization = null;
    }
  }

  void forgetPendingInvitation(String code) {
    add(SessionEvent.clearPendingInvitation(code: code));
  }

  Future<void> signOut() async {
    if (state is SessionLoggedOut) {
      await _loginUsecase.logout();
      await DioNetwork.clearTokens();
      return;
    }
    final completed = stream.firstWhere((s) => s is SessionLoggedOut);
    add(const SessionEvent.logout());
    await completed;
  }

  Future<void> _onInitialize(
    InitializeSession event,
    Emitter<SessionState> emit,
  ) async {
    final generation = _generation;
    final currentForceClientMode = state.maybeMap(
      ready: (s) => s.forceClientMode,
      orElse: () => false,
    );

    emit(const SessionState.loading());

    final result = await _sessionUsecase.initializeSession();

    if (generation != _generation) return;
    result.fold(
      (failure) => emit(SessionState.error(message: failure.errorMessage)),
      (session) => emit(
        SessionState.ready(
          session: session,
          forceClientMode: currentForceClientMode,
        ),
      ),
    );
  }

  Future<void> _onRefreshBarAccess(
    RefreshBarAccess event,
    Emitter<SessionState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SessionReady) {
      event.completion?.complete(false);
      return;
    }
    final result = await _sessionUsecase.refreshBarAccess();
    if (state.currentSession?.user.id != currentState.session.user.id) {
      event.completion?.complete(false);
      return;
    }
    result.fold((_) => event.completion?.complete(false), (bars) {
      if (event.selectBarId != null &&
          !bars.any((b) => b.barId == event.selectBarId)) {
        event.completion?.complete(false);
        return;
      }
      var session = currentState.session.withBarAccess(bars);
      if (event.selectBarId != null) {
        session = session.withActiveBar(event.selectBarId!);
      }
      emit(
        SessionState.ready(
          session: session,
          forceClientMode: event.selectBarId == null
              ? currentState.forceClientMode
              : false,
        ),
      );
      event.completion?.complete(true);
    });
  }

  void _onSwitchActiveBar(SwitchActiveBar event, Emitter<SessionState> emit) {
    final currentState = state;
    if (currentState is! SessionReady) return;

    final newSession = currentState.session.withActiveBar(event.barId);
    emit(
      SessionState.ready(
        session: newSession,
        forceClientMode: false, // Exit client mode when switching bars
      ),
    );
  }

  Future<void> _onAcceptInvitation(
    AcceptInvitation event,
    Emitter<SessionState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SessionReady) return;

    final result = await _sessionUsecase.acceptInvitation(event.invitationCode);

    result.fold(
      (failure) {
        emit(
          SessionState.ready(
            session: currentState.session,
            forceClientMode: currentState.forceClientMode,
            error: failure.errorMessage,
          ),
        );
      },
      (newBarAccess) {
        final updatedBars = [...currentState.session.barAccess, newBarAccess];
        final newSession = currentState.session.withBarAccess(updatedBars);
        emit(SessionState.ready(session: newSession, forceClientMode: false));
      },
    );
  }

  Future<bool> refreshAndSelectVenue(int barId) async {
    final completion = Completer<bool>();
    add(
      SessionEvent.refreshBarAccess(selectBarId: barId, completion: completion),
    );
    try {
      return await completion.future.timeout(const Duration(seconds: 35));
    } catch (_) {
      return false;
    }
  }

  void _onBarCreated(BarCreated event, Emitter<SessionState> emit) {
    final currentState = state;
    if (currentState is! SessionReady) return;

    final updatedBars = [
      ...currentState.session.barAccess.where(
        (b) => b.barId != event.newBar.barId,
      ),
      event.newBar,
    ];
    final newSession = currentState.session.withBarAccess(updatedBars);
    emit(
      SessionState.ready(
        session: newSession.withActiveBar(event.newBar.barId),
        forceClientMode: false,
      ),
    );
  }

  Future<void> _onLogout(
    LogoutSession event,
    Emitter<SessionState> emit,
  ) async {
    _generation++;
    await _loginUsecase.logout();
    await DioNetwork.clearTokens();
    emit(const SessionState.loggedOut());
  }

  void _onSwitchToClientMode(
    SwitchToClientMode event,
    Emitter<SessionState> emit,
  ) {
    final currentState = state;
    if (currentState is! SessionReady) return;

    emit(
      SessionState.ready(session: currentState.session, forceClientMode: true),
    );
  }

  void _onSwitchToBusinessMode(
    SwitchToBusinessMode event,
    Emitter<SessionState> emit,
  ) {
    final currentState = state;
    if (currentState is! SessionReady) return;

    if (currentState.session.barAccess.isEmpty) {
      // Can't switch to business mode without bar access
      return;
    }

    emit(
      SessionState.ready(session: currentState.session, forceClientMode: false),
    );
  }
}
