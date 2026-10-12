import 'payment_method.dart';

enum TransactionStatus {
  pending,
  processing,
  approved,
  declined,
  refunded,
  cancelled,
}

enum TransactionType { payment, refund, cashback, walletTopUp, walletWithdraw }

class Transaction {
  final int id;
  final String? externalId;
  final int userId;
  final int? orderId;
  final PaymentGateway gateway;
  final PaymentType paymentType;
  final TransactionType transactionType;
  final TransactionStatus status;
  final double amount;
  final String currency;
  final double? fee;
  final String? pixQrCode;
  final String? pixCopyPaste;
  final DateTime? pixExpiresAt;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction({
    required this.id,
    this.externalId,
    required this.userId,
    this.orderId,
    required this.gateway,
    required this.paymentType,
    required this.transactionType,
    required this.status,
    required this.amount,
    this.currency = 'BRL',
    this.fee,
    this.pixQrCode,
    this.pixCopyPaste,
    this.pixExpiresAt,
    this.failureReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      externalId: json['external_id'],
      userId: json['user_id'],
      orderId: json['order_id'],
      gateway: PaymentGateway.values.firstWhere(
        (e) => e.name == json['gateway'],
        orElse: () => PaymentGateway.pagarme,
      ),
      paymentType: PaymentType.values.firstWhere(
        (e) => e.name == json['payment_type'],
        orElse: () => PaymentType.credit,
      ),
      transactionType: TransactionType.values.firstWhere(
        (e) => e.name == json['transaction_type'],
        orElse: () => TransactionType.payment,
      ),
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransactionStatus.pending,
      ),
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] ?? 'BRL',
      fee: (json['fee'] as num?)?.toDouble(),
      pixQrCode: json['pix_qr_code'],
      pixCopyPaste: json['pix_copy_paste'],
      pixExpiresAt: json['pix_expires_at'] != null
          ? DateTime.parse(json['pix_expires_at'])
          : null,
      failureReason: json['failure_reason'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'external_id': externalId,
      'user_id': userId,
      'order_id': orderId,
      'gateway': gateway.name,
      'payment_type': paymentType.name,
      'transaction_type': transactionType.name,
      'status': status.name,
      'amount': amount,
      'currency': currency,
      'fee': fee,
      'pix_qr_code': pixQrCode,
      'pix_copy_paste': pixCopyPaste,
      'pix_expires_at': pixExpiresAt?.toIso8601String(),
      'failure_reason': failureReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isPending => status == TransactionStatus.pending;
  bool get isProcessing => status == TransactionStatus.processing;
  bool get isApproved => status == TransactionStatus.approved;
  bool get isFailed =>
      status == TransactionStatus.declined ||
      status == TransactionStatus.cancelled;
}
