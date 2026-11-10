import 'package:barz/features/payments/domain/native_wallet_capability.dart';
import 'package:barz/features/payments/presentation/widgets/digital_wallets_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Probe extends NativeWalletProbe {
  const Probe({this.apple = true, this.google = true, this.throws = false});
  final bool apple, google, throws;
  @override
  Future<bool> canPay(NativeWallet wallet) async {
    if (throws) throw StateError('plugin');
    return wallet == NativeWallet.applePay ? apple : google;
  }
}

const full = NativeWalletConfig(
  appleMerchantId: 'merchant.test',
  googleMerchantId: 'g-merchant',
  googleGatewayMerchantId: 'gw',
);
const both = ['credit_card', 'apple_pay', 'google_pay'];

void main() {
  Future<NativeWalletAvailability> run({
    NativeWalletConfig config = full,
    NativeWalletProbe probe = const Probe(),
    Iterable<String> methods = both,
    TargetPlatform os = TargetPlatform.iOS,
    bool web = false,
  }) => NativeWalletCapability(
    config: config,
    probe: probe,
  ).evaluate(gatewayPaymentMethods: methods, platform: os, isWeb: web);

  test(
    'OS detection alone offers nothing (default probe + no config)',
    () async {
      for (final os in [TargetPlatform.iOS, TargetPlatform.android]) {
        final a = await NativeWalletCapability().evaluate(
          gatewayPaymentMethods: both,
          platform: os,
          isWeb: false,
        );
        expect(a.applePay || a.googlePay, isFalse);
      }
    },
  );

  test(
    'fully supported iOS offers Apple Pay only; Android offers Google Pay only',
    () async {
      final ios = await run();
      expect([ios.applePay, ios.googlePay], [true, false]);
      final android = await run(os: TargetPlatform.android);
      expect([android.applePay, android.googlePay], [false, true]);
    },
  );

  test('each missing prerequisite hides the wallet', () async {
    expect((await run(config: const NativeWalletConfig())).applePay, isFalse);
    expect(
      (await run(methods: ['credit_card', 'pix'])).applePay,
      isFalse,
    ); // Brazil/PagarMe today
    expect((await run(probe: const Probe(apple: false))).applePay, isFalse);
    expect((await run(probe: const Probe(throws: true))).applePay, isFalse);
    expect((await run(web: true)).applePay, isFalse);
    expect(
      (await run(
        os: TargetPlatform.android,
        config: const NativeWalletConfig(googleMerchantId: 'x'),
      )).googlePay,
      isFalse,
    );
    expect((await run(os: TargetPlatform.macOS)).applePay, isFalse);
  });

  testWidgets(
    'checkout wallet section is hidden by default and shown only when available',
    (tester) async {
      Widget section(NativeWalletAvailability a) => MaterialApp(
        home: Scaffold(
          body: DigitalWalletsSection(
            onApplePay: () {},
            onGooglePay: () {},
            availability: a,
          ),
        ),
      );
      await tester.pumpWidget(section(NativeWalletAvailability.none));
      expect(find.text('Pay'), findsNothing);
      expect(find.text('or pay with'), findsNothing);
    },
  );
}
