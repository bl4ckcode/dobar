import 'package:barz/features/payments/domain/models/payment_method.dart';
import 'package:barz/features/payments/domain/models/payment_model.dart';
import 'package:barz/features/payments/domain/models/transaction.dart';

class PaymentFixtures {
  static PaymentMethod creditCardBrazil() => PaymentMethod(
    id: 1,
    externalId: 'card_pagarme_123',
    gateway: PaymentGateway.pagarme,
    type: PaymentType.credit,
    brand: 'Visa',
    lastFourDigits: '4242',
    holderName: 'João Silva',
    expiryMonth: 12,
    expiryYear: 2027,
    isDefault: true,
    createdAt: DateTime(2024, 1, 1),
  );

  static PaymentMethod pixBrazil() => PaymentMethod(
    id: 2,
    gateway: PaymentGateway.pagarme,
    type: PaymentType.pix,
    isDefault: false,
  );

  static PaymentMethod creditCardLatam() => PaymentMethod(
    id: 3,
    externalId: 'pm_stripe_456',
    gateway: PaymentGateway.stripe,
    type: PaymentType.credit,
    brand: 'Mastercard',
    lastFourDigits: '5555',
    holderName: 'Carlos Mendez',
    expiryMonth: 6,
    expiryYear: 2026,
    isDefault: true,
    createdAt: DateTime(2024, 2, 1),
  );

  static PaymentMethod applePayLatam() => PaymentMethod(
    id: 4,
    gateway: PaymentGateway.stripe,
    type: PaymentType.applePay,
    isDefault: false,
  );

  static PaymentMethod creditCardUS() => PaymentMethod(
    id: 5,
    externalId: 'pm_stripe_789',
    gateway: PaymentGateway.stripe,
    type: PaymentType.credit,
    brand: 'Amex',
    lastFourDigits: '1234',
    holderName: 'John Doe',
    expiryMonth: 3,
    expiryYear: 2028,
    isDefault: true,
    createdAt: DateTime(2024, 3, 1),
  );

  static PaymentMethod googlePayUS() => PaymentMethod(
    id: 6,
    gateway: PaymentGateway.stripe,
    type: PaymentType.googlePay,
    isDefault: false,
  );

  static PaymentMethod paypalROW() => PaymentMethod(
    id: 7,
    externalId: 'pp_account_abc',
    gateway: PaymentGateway.paypal,
    type: PaymentType.credit,
    brand: 'PayPal',
    isDefault: true,
    createdAt: DateTime(2024, 4, 1),
  );

  static PaymentMethod walletGlobal() => PaymentMethod(
    id: 8,
    gateway: PaymentGateway.pagarme,
    type: PaymentType.wallet,
    isDefault: false,
  );

  static PaymentRequest brazilPixRequest() => PaymentRequest(
    orderId: 100,
    amount: 59.90,
    currency: 'BRL',
    paymentType: PaymentType.pix,
  );

  static PaymentRequest brazilCreditRequest() => PaymentRequest(
    orderId: 101,
    amount: 150.00,
    currency: 'BRL',
    paymentType: PaymentType.credit,
    paymentMethodId: 1,
    tip: 15.00,
  );

  static PaymentRequest latamCreditRequest() => PaymentRequest(
    orderId: 102,
    amount: 25000.00,
    currency: 'CLP',
    paymentType: PaymentType.credit,
    paymentMethodId: 3,
  );

  static PaymentRequest usCreditRequest() => PaymentRequest(
    orderId: 103,
    amount: 45.99,
    currency: 'USD',
    paymentType: PaymentType.credit,
    paymentMethodId: 5,
    tip: 9.20,
  );

  static PaymentRequest rowPaypalRequest() => PaymentRequest(
    orderId: 104,
    amount: 35.50,
    currency: 'EUR',
    paymentType: PaymentType.credit,
    paymentMethodId: 7,
  );

  static PixPaymentResponse pixResponse() => PixPaymentResponse(
    transactionId: 1001,
    qrCode:
        '00020126580014br.gov.bcb.pix0136a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    copyPaste:
        '00020126580014br.gov.bcb.pix0136a1b2c3d4-e5f6-7890-abcd-ef12345678905204000053039865802BR5913DOBAR LTDA6014BELO HORIZONTE62070503***63041234',
    expiresAt: DateTime.now().add(const Duration(minutes: 30)),
    amount: 59.90,
  );

  static Transaction pendingPixTransaction() => Transaction(
    id: 1001,
    externalId: 'pix_pagarme_001',
    userId: 1,
    orderId: 100,
    gateway: PaymentGateway.pagarme,
    paymentType: PaymentType.pix,
    transactionType: TransactionType.payment,
    status: TransactionStatus.pending,
    amount: 59.90,
    currency: 'BRL',
    pixQrCode: '00020126580014br.gov.bcb.pix...',
    pixCopyPaste: '00020126580014br.gov.bcb.pix...',
    pixExpiresAt: DateTime.now().add(const Duration(minutes: 30)),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  static Transaction approvedCreditTransaction() => Transaction(
    id: 1002,
    externalId: 'ch_stripe_002',
    userId: 1,
    orderId: 101,
    gateway: PaymentGateway.stripe,
    paymentType: PaymentType.credit,
    transactionType: TransactionType.payment,
    status: TransactionStatus.approved,
    amount: 150.00,
    currency: 'BRL',
    fee: 4.50,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  static Transaction declinedTransaction() => Transaction(
    id: 1003,
    externalId: 'ch_stripe_003',
    userId: 1,
    orderId: 102,
    gateway: PaymentGateway.stripe,
    paymentType: PaymentType.credit,
    transactionType: TransactionType.payment,
    status: TransactionStatus.declined,
    amount: 25000.00,
    currency: 'CLP',
    failureReason: 'Insufficient funds',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  static Transaction refundedTransaction() => Transaction(
    id: 1004,
    externalId: 'rf_paypal_001',
    userId: 1,
    orderId: 104,
    gateway: PaymentGateway.paypal,
    paymentType: PaymentType.credit,
    transactionType: TransactionType.refund,
    status: TransactionStatus.approved,
    amount: 35.50,
    currency: 'EUR',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  static Map<String, dynamic> pixResponseJson() => {
    'transaction_id': 1001,
    'qr_code':
        '00020126580014br.gov.bcb.pix0136a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'copy_paste':
        '00020126580014br.gov.bcb.pix0136a1b2c3d4-e5f6-7890-abcd-ef12345678905204000053039865802BR5913DOBAR LTDA6014BELO HORIZONTE62070503***63041234',
    'expires_at': DateTime.now()
        .add(const Duration(minutes: 30))
        .toIso8601String(),
    'amount': 59.90,
  };

  static Map<String, dynamic> transactionJson() => {
    'id': 1002,
    'external_id': 'ch_stripe_002',
    'user_id': 1,
    'order_id': 101,
    'gateway': 'stripe',
    'payment_type': 'credit',
    'transaction_type': 'payment',
    'status': 'approved',
    'amount': 150.00,
    'currency': 'BRL',
    'fee': 4.50,
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };

  static Map<String, dynamic> paymentMethodJson() => {
    'id': 1,
    'external_id': 'card_pagarme_123',
    'gateway': 'pagarme',
    'type': 'credit',
    'brand': 'Visa',
    'last_four_digits': '4242',
    'holder_name': 'João Silva',
    'expiry_month': 12,
    'expiry_year': 2027,
    'is_default': true,
    'created_at': DateTime(2024, 1, 1).toIso8601String(),
  };

  static List<Map<String, dynamic>> transactionListJson() => [
    transactionJson(),
    {
      ...transactionJson(),
      'id': 1003,
      'status': 'declined',
      'failure_reason': 'Insufficient funds',
    },
  ];
}
