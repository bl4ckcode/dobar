import 'payment_method.dart';

class CustomerInfo {
  final String name;
  final String email;
  final String document;
  final String? phone;

  CustomerInfo({
    required this.name,
    required this.email,
    required this.document,
    this.phone,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'document': document,
      if (phone != null) 'phone': phone,
    };
  }
}

class PaymentRequest {
  final int orderId;
  final int barId;
  final double amount;
  final String currency;
  final String country;
  final PaymentType paymentType;
  final int? paymentMethodId;
  final String? cardToken;
  final String? provider;
  final int installments;
  final CustomerInfo? customerInfo;
  final String? description;
  final double? tip;

  PaymentRequest({
    required this.orderId,
    required this.barId,
    required this.amount,
    this.currency = 'BRL',
    this.country = 'BR',
    required this.paymentType,
    this.paymentMethodId,
    this.cardToken,
    this.provider,
    this.installments = 1,
    this.customerInfo,
    this.description,
    this.tip,
  });

  Map<String, dynamic> toJson() {
    final method = {
      'type': paymentType.name,
      if (cardToken != null) 'token': cardToken,
      if (paymentMethodId != null) 'payment_method_id': paymentMethodId,
      if (provider != null) 'provider': provider,
      'installments': installments,
    };

    return {
      'order_id': orderId,
      'bar_id': barId,
      'amount': amount,
      'currency': currency,
      'country': country,
      'payment_method': method,
      if (customerInfo != null) 'customer_info': customerInfo!.toJson(),
      if (description != null) 'description': description,
      if (tip != null) 'tip': tip,
    };
  }
}

class PixPaymentResponse {
  final String paymentId;
  final String qrCode;
  final String copyPaste;
  final DateTime expiresAt;
  final double amount;
  final int? orderId;

  PixPaymentResponse({
    required this.paymentId,
    required this.qrCode,
    required this.copyPaste,
    required this.expiresAt,
    required this.amount,
    this.orderId,
  });

  factory PixPaymentResponse.fromJson(Map<String, dynamic> json) {
    return PixPaymentResponse(
      paymentId: json['payment_id'] ?? json['transaction_id']?.toString() ?? '',
      qrCode: json['pix_qr_code'] ?? json['qr_code'] ?? '',
      copyPaste: json['pix_copia_e_cola'] ?? json['copy_paste'] ?? '',
      expiresAt: json['pix_expires_at'] != null
          ? DateTime.parse(json['pix_expires_at'])
          : (json['expires_at'] != null
              ? DateTime.parse(json['expires_at'])
              : DateTime.now().add(const Duration(minutes: 30))),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      orderId: json['order_id'] as int?,
    );
  }
}
