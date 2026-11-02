import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:barz/features/session/domain/models/invitation_intent.dart';

class InvitationLinkHandler {
  final Future<void> Function(String) onCode;
  final AppLinks _links;
  StreamSubscription<Uri>? _subscription;
  Future<void> _queue = Future.value();
  String? _lastCode;
  DateTime? _lastReceived;
  InvitationLinkHandler({required this.onCode, AppLinks? links})
    : _links = links ?? AppLinks();

  Future<void> start() async {
    _subscription = _links.uriLinkStream.listen(handle, onError: (Object _) {});
    final initial = await _links.getInitialLink();
    if (initial != null) await handle(initial);
  }

  Future<void> handle(Uri uri) {
    final code = parseInvitationCode(uri.toString(), allowManual: false);
    if (code == null) return Future.value();
    final now = DateTime.now();
    if (_lastCode == code &&
        _lastReceived != null &&
        now.difference(_lastReceived!) < const Duration(seconds: 2)) {
      return _queue;
    }
    _lastCode = code;
    _lastReceived = now;
    _queue = _queue.then((_) => onCode(code));
    return _queue;
  }

  Future<void> dispose() async => _subscription?.cancel();
}
