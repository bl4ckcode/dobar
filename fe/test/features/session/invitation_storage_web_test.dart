@TestOn('browser')
library;

import 'package:barz/features/session/data/storage/invitation_intent_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('browser refresh restores invitation using session storage', () async {
    final store = InvitationIntentStore();
    await store.save('CaseSensitive_Token123');
    expect(
      web.window.sessionStorage.getItem('pending_staff_invitation'),
      'CaseSensitive_Token123',
    );
    expect(web.window.localStorage.getItem('pending_staff_invitation'), null);
    final refreshed = InvitationIntentStore();
    await refreshed.restore();
    expect(refreshed.code, 'CaseSensitive_Token123');
    await refreshed.save(null);
    await store.restore();
    expect(store.code, null);
  });
}
