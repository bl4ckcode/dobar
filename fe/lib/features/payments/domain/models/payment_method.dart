enum PaymentGateway { pagarme, stripe, paypal }

enum PaymentType { credit, debit, pix, applePay, googlePay, wallet, cash }

class PaymentMethod {
  final int? id;
  final String? externalId;
  final PaymentGateway gateway;
  final PaymentType type;
  final String? brand;
  final String? lastFourDigits;
  final String? holderName;
  final int? expiryMonth;
  final int? expiryYear;
  final bool isDefault;
  final DateTime? createdAt;

  PaymentMethod({
    this.id,
    this.externalId,
    required this.gateway,
    required this.type,
    this.brand,
    this.lastFourDigits,
    this.holderName,
    this.expiryMonth,
    this.expiryYear,
    this.isDefault = false,
    this.createdAt,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'],
      externalId: json['external_id'],
      gateway: PaymentGateway.values.firstWhere(
        (e) => e.name == json['gateway'],
        orElse: () => PaymentGateway.pagarme,
      ),
      type: PaymentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PaymentType.credit,
      ),
      brand: json['brand'],
      lastFourDigits: json['last_four'],
      holderName: json['holder_name'],
      expiryMonth: json['exp_month'],
      expiryYear: json['exp_year'],
      isDefault: json['is_default'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'external_id': externalId,
      'gateway': gateway.name,
      'type': type.name,
      'brand': brand,
      'last_four': lastFourDigits,
      'holder_name': holderName,
      'exp_month': expiryMonth,
      'exp_year': expiryYear,
      'is_default': isDefault,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get displayName {
    if (type == PaymentType.pix) return 'PIX';
    if (type == PaymentType.applePay) return 'Apple Pay';
    if (type == PaymentType.googlePay) return 'Google Pay';
    if (type == PaymentType.wallet) return 'dobar Wallet';
    if (type == PaymentType.cash) return 'Cash';
    return '${brand ?? ''} •••• ${lastFourDigits ?? ''}';
  }
}
