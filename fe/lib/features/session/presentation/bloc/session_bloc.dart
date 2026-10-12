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

  SessionBloc({
    required this._sessionUsecase,
    required this._loginUsecase,
  }) : super(const SessionState.initial()) {
    on<InitializeSession>(_onInitialize);
    on<RefreshBarAccess>(_onRefreshBarAccess);
    on<SwitchActiveBar>(_onSwitchActiveBar);
    on<AcceptInvitation>(_onAcceptInvitation);
    on<BarCreated>(_onBarCreated);
    on<LogoutSession>(_onLogout);
    on<SwitchToClientMode>(_onSwitchToClientMode);
    on<SwitchToBusinessMode>(_onSwitchToBusinessMode);
  }

  Future<void> _onInitialize(
    InitializeSession event,
    Emitter<SessionState> emit,
  ) async {
    final currentForceClientMode = state.maybeMap(
      ready: (s) => s.forceClientMode,
      orElse: () => false,
    );

    emit(const SessionState.loading());

    final result = await _sessionUsecase.initializeSession();

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
    if (currentState is! SessionReady) return;

    final result = await _sessionUsecase.refreshBarAccess();

    result.fold(
      (failure) {
        // Keep current state on refresh failure
      },
      (bars) {
        final newSession = currentState.session.withBarAccess(bars);
        emit(
          SessionState.ready(
            session: newSession,
            forceClientMode: currentState.forceClientMode,
          ),
        );
      },
    );
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

  void _onBarCreated(BarCreated event, Emitter<SessionState> emit) {
    final currentState = state;
    if (currentState is! SessionReady) return;

    final updatedBars = [...currentState.session.barAccess, event.newBar];
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
