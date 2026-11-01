import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/session/domain/models/invitation_preview.dart';
import 'package:barz/features/session/domain/usecases/session_usecase.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';
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
  }) : _sessionUsecase = sessionUsecase,
       _sessionBloc = sessionBloc,
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
      (failure) => _mapPreviewFailureToState(failure, code),
      (preview) => emit(InvitationReady(code: code, preview: preview)),
    );
  }

  Future<void> onLoginReturned(String code) => _loadPreview(code);

  Future<void> acceptInvitation(String code, InvitationPreview preview) async {
    emit(InvitationAccepting(code: code, preview: preview));
    final result = await _sessionUsecase.acceptInvitation(code);
    result.fold((failure) => _mapAcceptFailureToState(failure, code, preview), (
      barAccess,
    ) {
      _sessionBloc
        ..add(SessionEvent.barCreated(newBar: barAccess))
        ..add(const SessionEvent.refreshBarAccess());
      emit(InvitationAccepted(code: code, preview: preview, access: barAccess));
    });
  }

  Future<void> retry(String code) => _loadPreview(code);

  void _mapPreviewFailureToState(Failure failure, String code) {
    final errorCode = failure.errorMessage;
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

  void _mapAcceptFailureToState(
    Failure failure,
    String code,
    InvitationPreview preview,
  ) {
    final errorCode = failure.errorMessage;
    switch (errorCode) {
      case _codeExpired:
        emit(
          InvitationAcceptError(
            code: code,
            preview: preview,
            message: _codeExpired,
          ),
        );
        break;
      case _codeRevoked:
        emit(
          InvitationAcceptError(
            code: code,
            preview: preview,
            message: _codeRevoked,
          ),
        );
        break;
      case _codeMismatch:
        emit(
          InvitationAcceptError(
            code: code,
            preview: preview,
            message: _codeMismatch,
          ),
        );
        break;
      case _codeUnverified:
        emit(
          InvitationAcceptError(
            code: code,
            preview: preview,
            message: _codeUnverified,
          ),
        );
        break;
      case _codeAlreadyUsed:
        emit(
          InvitationAcceptError(
            code: code,
            preview: preview,
            message: _codeAlreadyUsed,
          ),
        );
        break;
      case _codeInvalid:
        emit(
          InvitationAcceptError(
            code: code,
            preview: preview,
            message: _codeInvalid,
          ),
        );
        break;
      default:
        emit(
          InvitationAcceptError(
            code: code,
            preview: preview,
            message: errorCode,
          ),
        );
    }
  }

  static String? _parseCode(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      try {
        final uri = Uri.parse(trimmed);
        final hosts = {
          'dobar.app',
          'www.dobar.app',
          'localhost',
          '127.0.0.1',
          if (Uri.base.host.isNotEmpty) Uri.base.host.toLowerCase(),
        };
        if (!hosts.contains(uri.host.toLowerCase())) return null;
        final fromQuery =
            uri.queryParameters['code'] ?? uri.queryParameters['codigo'];
        final pathMatch = RegExp(
          r'^/convite/([^/]+)/?$',
          caseSensitive: false,
        ).firstMatch(uri.path);
        final isCanonicalPath =
            uri.path.toLowerCase() == '/staff/invitations/accept';
        final candidate = fromQuery ?? pathMatch?.group(1);
        if (isCanonicalPath && fromQuery == null) return null;
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
  static final _opaqueCodeRe = RegExp(r'^[A-Za-z0-9_-]{16,128}$');

  static String? _normalizeCode(String raw) {
    final compact = raw.trim().replaceAll(RegExp(r'\s+'), '');
    final m = _codeRe.firstMatch(compact);
    if (m != null) {
      return 'DBR-${m.group(1)!.toUpperCase()}-${m.group(2)!.toUpperCase()}';
    }
    return _opaqueCodeRe.hasMatch(compact) ? compact : null;
  }

  static String _contactType(Failure failure) {
    if (failure is ServerFailure) {
      final raw = failure.details['contact_type'];
      if (raw is List && raw.contains('phone')) return 'phone';
      if (raw == 'phone') return 'phone';
    }
    return 'email';
  }
}
