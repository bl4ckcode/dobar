import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:barz/features/session/data/invitation_link_handler.dart';
import 'package:barz/features/session/data/storage/invitation_intent_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Links extends Mock implements AppLinks {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cold and warm links share validation and deduplicate initial stream delivery',
    () async {
      final links = _Links();
      final stream = StreamController<Uri>();
      final cold = Uri.parse(
        'https://dobar.app/staff/invitations/accept?code=CaseSensitive_Token123',
      );
      when(() => links.getInitialLink()).thenAnswer((_) async => cold);
      when(() => links.uriLinkStream).thenAnswer((_) => stream.stream);
      final navigated = <String>[];
      final handler = InvitationLinkHandler(
        links: links,
        onCode: (code) async => navigated.add(code),
      );
      await handler.start();
      stream.add(cold);
      await Future<void>.delayed(Duration.zero);
      await handler.handle(
        Uri.parse('https://evil.com/convite/Untrusted_Token123'),
      );
      await handler.handle(
        Uri.parse('https://dobar.app/other?code=Untrusted_Token123'),
      );
      await handler.handle(
        Uri.parse('https://dobar.app/convite/Warm_CaseSensitive_123'),
      );
      expect(navigated, ['CaseSensitive_Token123', 'Warm_CaseSensitive_123']);
      await handler.dispose();
      await stream.close();
    },
  );
  test(
    'native authentication intent survives restoration and clears without token changes',
    () async {
      final values = <String, String>{'access_token': 'existing-session'};
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            switch (call.method) {
              case 'write':
                values[args['key'] as String] = args['value'] as String;
                return null;
              case 'read':
                return values[args['key']];
              case 'delete':
                values.remove(args['key']);
                return null;
            }
            throw StateError('Unexpected storage operation');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final store = InvitationIntentStore();
      await store.save('CaseSensitive_Token123');
      final restored = InvitationIntentStore();
      await restored.restore();
      expect(restored.code, 'CaseSensitive_Token123');
      await restored.save(null);
      await store.restore();
      expect(store.code, null);
      expect(values['access_token'], 'existing-session');
    },
  );
}
