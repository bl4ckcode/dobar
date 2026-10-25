import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/features/session/domain/models/invitation_preview.dart';
import 'package:barz/features/session/domain/usecases/session_usecase.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'invitation_state.dart';

class InvitationCubit extends Cubit<InvitationState> {
  final SessionUsecase _sessionUsecase;
  final SessionBloc _sessionBloc;
  final Future<bool> Function() _isAuthenticated;

  static const _codeExpired = 'INVITATION_EXPIRED';
  static const _codeRevoked = 'INVITATION_REVOKED';
  static const _codeMismatch = 'INVITATION_CONTACT_MISMATCH';
  static const _codeUnverified = 'INVITATION_CONTACT_UNVERIFIED';
  static const _codeAlreadyUsed = 'INVITATION_ALREADY_USED';
  static const _codeInvalid = 'INVITATION_INVALID';

  InvitationCubit({
    required SessionUsecase sessionUsecase,
    required SessionBloc sessionBloc,
    String? initialCode,
    Future<bool> Function()? isAuthenticated,
  })  : _sessionUsecase = sessionUsecase,
        _sessionBloc = sessionBloc,
        _isAuthenticated = isAuthenticated ?? DioNetwork.isAuthenticated,
        super(
          initialCode != null && initialCode.isNotEmpty
              ? InvitationLoading(code: initialCode)
              : const InvitationManualCode(),
        ) {
    if (initialCode != null && initialCode.isNotEmpty) {
      _loadPreview(initialCode);
    }
  }

  Future<void> submitCode(String raw) async {
    final code = _parseCode(raw);
    if (code == null) {
      emit(InvitationLoadError(code: raw, message: 'INVALID_FORMAT'));
      return;
    }
    await _loadPreview(code);
  }

  Future<void> _loadPreview(String code) async {
    emit(InvitationLoading(code: code));
    final isAuth = await _isAuthenticated();
    if (!isAuth) {
      emit(InvitationSignedOut(code: code));
      return;
    }
    final result = await _sessionUsecase.previewInvitation(code);
    result.fold(
      (failure) => _mapFailureToState(failure.errorMessage, code),
      (preview) => emit(InvitationReady(code: code, preview: preview)),
    );
  }

  Future<void> onLoginReturned(String code) => _loadPreview(code);

  Future<void> acceptInvitation(String code, InvitationPreview preview) async {
    emit(InvitationAccepting(code: code, preview: preview));
    final result = await _sessionUsecase.acceptInvitation(code);
    result.fold(
      (failure) {
        final err = failure.errorMessage;
        if (err.contains(_codeAlreadyUsed)) {
          final s = _sessionBloc.state;
          if (s is SessionReady) {
            final existing =
                s.session.barAccess.where((b) => b.barName == preview.venueName);
            if (existing.isNotEmpty) {
              emit(InvitationAlreadyMember(code: code, access: existing.first));
              return;
            }
          }
        }
        emit(InvitationAcceptError(code: code, preview: preview, message: err));
      },
      (barAccess) {
        _sessionBloc
          ..add(SessionEvent.barCreated(newBar: barAccess))
          ..add(const SessionEvent.refreshBarAccess());
        emit(
          InvitationAccepted(code: code, preview: preview, access: barAccess),
        );
      },
    );
  }

  Future<void> retry(String code) => _loadPreview(code);

  void _mapFailureToState(String errorCode, String code) {
    switch (errorCode) {
      case _codeExpired:
        emit(InvitationExpired(code: code));
      case _codeRevoked:
        emit(InvitationRevoked(code: code));
      case _codeMismatch:
        emit(InvitationWrongAccount(code: code));
      case _codeUnverified:
        emit(InvitationUnverified(code: code, contactType: 'email'));
      case _codeAlreadyUsed:
      case _codeInvalid:
        emit(InvitationInvalid(code: code));
      default:
        emit(InvitationLoadError(code: code, message: errorCode));
    }
  }

  static String? _parseCode(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      try {
        final uri = Uri.parse(trimmed);
        const hosts = {'dobar.app', 'www.dobar.app'};
        if (!hosts.contains(uri.host.toLowerCase())) return null;
        final fromQuery = uri.queryParameters['codigo'];
        final pathMatch = RegExp(
          r'^/convite/([^/]+)/?$',
          caseSensitive: false,
        ).firstMatch(uri.path);
        final candidate = fromQuery ?? pathMatch?.group(1);
        if (candidate == null) return null;
        return _normalizeCode(Uri.decodeComponent(candidate));
      } catch (_) {
        return null;
      }
    }
    return _normalizeCode(trimmed);
  }

  static final _codeRe = RegExp(
    r'^DBR-?([A-Z0-9]{4})-?([A-Z0-9]{4})$',
    caseSensitive: false,
  );

  static String? _normalizeCode(String raw) {
    final m = _codeRe.firstMatch(raw.replaceAll(RegExp(r'\s+'), ''));
    if (m == null) return null;
    return 'DBR-${m.group(1)!.toUpperCase()}-${m.group(2)!.toUpperCase()}';
  }
}
