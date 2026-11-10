import 'package:flutter/foundation.dart';

/// Native wallet identity (C10). Pix and saved cards are separate concepts.
enum NativeWallet { applePay, googlePay }

/// Build-time merchant configuration. Identifiers are environment values
/// (`--dart-define`), never repository secrets.
class NativeWalletConfig {
  const NativeWalletConfig({
    this.appleMerchantId = '',
    this.googleMerchantId = '',
    this.googleGatewayMerchantId = '',
  });

  static const fromEnvironment = NativeWalletConfig(
    appleMerchantId: String.fromEnvironment('APPLE_PAY_MERCHANT_ID'),
    googleMerchantId: String.fromEnvironment('GOOGLE_PAY_MERCHANT_ID'),
    googleGatewayMerchantId: String.fromEnvironment(
      'GOOGLE_PAY_GATEWAY_MERCHANT_ID',
    ),
  );

  final String appleMerchantId;
  final String googleMerchantId;
  final String googleGatewayMerchantId;

  bool isConfigured(NativeWallet wallet) => switch (wallet) {
    NativeWallet.applePay => appleMerchantId.isNotEmpty,
    NativeWallet.googlePay =>
      googleMerchantId.isNotEmpty && googleGatewayMerchantId.isNotEmpty,
  };
}

/// Asks the OS wallet whether a payment sheet can really be presented
/// (e.g. a provisioned card exists). The default implementation reports
/// unavailable: no wallet plugin or provider-token acquisition is integrated.
abstract class NativeWalletProbe {
  const NativeWalletProbe();
  Future<bool> canPay(NativeWallet wallet);
}

class UnavailableNativeWalletProbe extends NativeWalletProbe {
  const UnavailableNativeWalletProbe();
  @override
  Future<bool> canPay(NativeWallet wallet) async => false;
}

class NativeWalletAvailability {
  const NativeWalletAvailability({
    this.applePay = false,
    this.googlePay = false,
  });
  static const none = NativeWalletAvailability();
  final bool applePay;
  final bool googlePay;
}

/// A wallet is offered only when ALL of these hold; OS detection alone never is:
///  1. the matching OS (iOS for Apple Pay, Android for Google Pay), not web;
///  2. merchant configuration is present;
///  3. the backend advertises the wallet for the customer's gateway
///     (Brazil/PagarMe does not today);
///  4. the OS wallet reports it can present a payment sheet.
class NativeWalletCapability {
  const NativeWalletCapability({
    this.config = NativeWalletConfig.fromEnvironment,
    this.probe = const UnavailableNativeWalletProbe(),
  });
  final NativeWalletConfig config;
  final NativeWalletProbe probe;

  Future<NativeWalletAvailability> evaluate({
    required Iterable<String> gatewayPaymentMethods,
    TargetPlatform? platform,
    bool? isWeb,
  }) async {
    final web = isWeb ?? kIsWeb;
    final os = platform ?? defaultTargetPlatform;
    if (web) return NativeWalletAvailability.none;

    Future<bool> offered(
      NativeWallet wallet,
      TargetPlatform required,
      String key,
    ) async {
      if (os != required) return false;
      if (!config.isConfigured(wallet)) return false;
      if (!gatewayPaymentMethods.contains(key)) return false;
      try {
        return await probe.canPay(wallet);
      } catch (_) {
        return false;
      }
    }

    return NativeWalletAvailability(
      applePay: await offered(
        NativeWallet.applePay,
        TargetPlatform.iOS,
        'apple_pay',
      ),
      googlePay: await offered(
        NativeWallet.googlePay,
        TargetPlatform.android,
        'google_pay',
      ),
    );
  }
}
