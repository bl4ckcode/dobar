import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/session/domain/models/invitation_preview.dart';
import 'package:barz/features/session/domain/usecases/session_usecase.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/domain/models/invitation_intent.dart';
import 'invitation_state.dart';

class InvitationCubit extends Cubit<InvitationState> {
  final SessionUsecase _sessionUsecase;
  final SessionBloc _sessionBloc;
  final Future<bool> Function() _isAuthenticated;
  final Future<void> Function(String?) _persistIntent;
  final Future<bool> Function() _prepareSession;
  final Future<void> Function(String)? _clearIntent;
  int _request = 0;
  bool _accepting = false;
  BarAccess? _acceptedAccess;

  static const _codeExpired = 'INVITATION_EXPIRED';
  static const _codeRevoked = 'INVITATION_REVOKED';
  static const _codeMismatch = 'INVITATION_CONTACT_MISMATCH';
  static const _codeUnverified = 'INVITATION_CONTACT_UNVERIFIED';
  static const _codeAlreadyUsed = 'INVITATION_ALREADY_USED';
  static const _codeInvalid = 'INVITATION_INVALID';

  InvitationCubit({
    required this._sessionUsecase,
    required this._sessionBloc,
    String? initialCode,
    Future<bool> Function()? isAuthenticated,
    Future<void> Function(String?)? persistIntent,
    Future<bool> Function()? prepareSession,
    this._clearIntent,
  }) : _prepareSession = prepareSession ?? (() async => true),
       _persistIntent = persistIntent ?? ((_) async {}),
       _isAuthenticated = isAuthenticated ?? DioNetwork.isAuthenticated,
       super(
         initialCode != null && initialCode.isNotEmpty
             ? InvitationLoading(code: initialCode)
             : const InvitationManualCode(),
       ) {
    if (initialCode != null && initialCode.isNotEmpty) {
      submitCode(initialCode);
    }
  }

  Future<void> submitCode(String raw) async {
    final request = ++_request;
    final code = parseInvitationCode(raw);
    if (code == null) {
      emit(InvitationLoadError(code: raw, message: 'INVALID_FORMAT'));
      return;
    }
    await _persistIntent(code);
    if (isClosed || request != _request) return;
    await _loadPreview(code, request);
  }

  Future<void> _loadPreview(String code, int request) async {
    emit(InvitationLoading(code: code));
    final isAuth = await _isAuthenticated();
    if (isClosed || request != _request) return;
    if (!isAuth) {
      emit(InvitationSignedOut(code: code));
      return;
    }
    final prepared = await _prepareSession();
    if (isClosed || request != _request) return;
    if (!prepared) {
      emit(InvitationLoadError(code: code, message: 'SESSION_LOAD_FAILED'));
      return;
    }
    final result = await _sessionUsecase.previewInvitation(code);
    if (isClosed || request != _request) return;
    await result.fold<Future<void>>(
      (failure) => _mapPreviewFailureToState(failure, code),
      (preview) async => emit(InvitationReady(code: code, preview: preview)),
    );
  }

  Future<void> onLoginReturned(String code) => submitCode(code);

  Future<void> acceptInvitation(String code, InvitationPreview preview) async {
    if (_accepting || _acceptedAccess != null) return;
    _accepting = true;
    emit(InvitationAccepting(code: code, preview: preview));
    final result = await _sessionUsecase.acceptInvitation(code);
    _accepting = false;
    await result.fold(
      (failure) async {
        if (!isClosed) await _mapAcceptFailureToState(failure, code, preview);
      },
      (barAccess) async {
        _acceptedAccess = barAccess;
        await _clear(code);
        if (isClosed) return;
        _sessionBloc.forgetPendingInvitation(code);
        emit(
          InvitationAccepted(code: code, preview: preview, access: barAccess),
        );
      },
    );
  }

  Future<bool> enterWorkspace(int barId) async {
    await _sessionBloc.initializeForEntry();
    return _sessionBloc.refreshAndSelectVenue(barId);
  }

  Future<void> retry(String code) => submitCode(code);

  Future<void> _mapPreviewFailureToState(Failure failure, String code) async {
    final request = _request;
    final errorCode = failure.errorMessage;
    if ([
      _codeExpired,
      _codeRevoked,
      _codeAlreadyUsed,
      _codeInvalid,
    ].contains(errorCode)) {
      await _clear(code);
      if (isClosed || request != _request) return;
    }
    switch (errorCode) {
      case _codeExpired:
        emit(InvitationExpired(code: code));
        break;
      case _codeRevoked:
        emit(InvitationRevoked(code: code));
        break;
      case _codeMismatch:
        emit(InvitationWrongAccount(code: code));
        break;
      case _codeUnverified:
        emit(
          InvitationUnverified(code: code, contactType: _contactType(failure)),
        );
        break;
      case _codeAlreadyUsed:
      case _codeInvalid:
        emit(InvitationInvalid(code: code));
        break;
      default:
        emit(InvitationLoadError(code: code, message: errorCode));
    }
  }

  Future<void> _mapAcceptFailureToState(
    Failure failure,
    String code,
    InvitationPreview preview,
  ) async {
    if ([
      _codeExpired,
      _codeRevoked,
      _codeMismatch,
      _codeUnverified,
      _codeAlreadyUsed,
      _codeInvalid,
    ].contains(failure.errorMessage)) {
      await _mapPreviewFailureToState(failure, code);
    } else {
      emit(
        InvitationAcceptError(
          code: code,
          preview: preview,
          message: failure.errorMessage,
        ),
      );
    }
  }

  Future<void> _clear(String code) =>
      _clearIntent == null ? _persistIntent(null) : _clearIntent(code);

  static String _contactType(Failure failure) {
    if (failure is ServerFailure) {
      final raw = failure.details['contact_type'];
      if (raw is List && raw.contains('phone')) return 'phone';
      if (raw == 'phone') return 'phone';
    }
    return 'email';
  }
}
