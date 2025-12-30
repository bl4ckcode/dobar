import 'payment_method.dart';

class PaymentRequest {
  final int orderId;
  final double amount;
  final String currency;
  final PaymentType paymentType;
  final int? paymentMethodId;
  final String? cardToken;
  final double? tip;

  PaymentRequest({
    required this.orderId,
    required this.amount,
    this.currency = 'BRL',
    required this.paymentType,
    this.paymentMethodId,
    this.cardToken,
    this.tip,
  });

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'amount': amount,
      'currency': currency,
      'payment_type': paymentType.name,
      'payment_method_id': paymentMethodId,
      'card_token': cardToken,
      'tip': tip,
    };
  }
}

class PixPaymentResponse {
  final int transactionId;
  final String qrCode;
  final String copyPaste;
  final DateTime expiresAt;
  final double amount;

  PixPaymentResponse({
    required this.transactionId,
    required this.qrCode,
    required this.copyPaste,
    required this.expiresAt,
    required this.amount,
  });

  factory PixPaymentResponse.fromJson(Map<String, dynamic> json) {
    return PixPaymentResponse(
      transactionId: json['transaction_id'],
      qrCode: json['qr_code'],
      copyPaste: json['copy_paste'],
      expiresAt: DateTime.parse(json['expires_at']),
      amount: (json['amount'] as num).toDouble(),
    );
  }
}
