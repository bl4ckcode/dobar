import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_gateway.freezed.dart';
part 'payment_gateway.g.dart';

/// Payment gateway information for user's country
@freezed
abstract class PaymentGateway with _$PaymentGateway {
  const factory PaymentGateway({
    /// Gateway name (stone, mercadopago, stripe)
    required String gateway,

    /// Country code
    @JsonKey(name: 'country_code') required String countryCode,

    /// Available payment methods
    @JsonKey(name: 'payment_methods') required List<String> paymentMethods,
  }) = _PaymentGateway;

  factory PaymentGateway.fromJson(Map<String, dynamic> json) =>
      _$PaymentGatewayFromJson(json);
}

/// Extension for payment method display
extension PaymentMethodsExtension on PaymentGateway {
  bool get supportsPix => paymentMethods.contains('pix');
  bool get supportsCreditCard => paymentMethods.contains('credit_card');
  bool get supportsDebitCard => paymentMethods.contains('debit_card');
  bool get supportsApplePay => paymentMethods.contains('apple_pay');
  bool get supportsGooglePay => paymentMethods.contains('google_pay');
  bool get supportsMPWallet => paymentMethods.contains('mp_wallet');
}
