import 'invitation_storage.dart'
    if (dart.library.js_interop) 'invitation_storage_web.dart'
    as storage;

class InvitationIntentStore {
  static final instance = InvitationIntentStore();
  String? code;
  Future<void> _writes = Future.value();
  Future<void> restore() async {
    code = await storage.readInvitation();
  }

  Future<void> save(String? value) {
    code = value;
    _writes = _writes.then(
      (_) => storage.writeInvitation(value),
      onError: (Object _) => storage.writeInvitation(value),
    );
    return _writes;
  }

  Future<void> clearIfMatching(String value) async {
    if (code == value) await save(null);
  }
}
