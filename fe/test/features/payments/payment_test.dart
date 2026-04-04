import 'package:barz/core/error/error_codes.dart';
import 'package:barz/core/error/failures.dart' as new_failures;
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/payments/domain/models/payment_method.dart';
import 'package:barz/features/payments/domain/models/payment_model.dart';
import 'package:barz/features/payments/domain/models/transaction.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/payment_fixtures.dart';
import '../../mocks/payment_mocks.dart';

void main() {
  late MockPaymentRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakePaymentRequest());
  });

  setUp(() {
    mockRepository = MockPaymentRepository();
  });

  group('Payment Models', () {
    test('PaymentMethod.fromJson creates correct instance', () {
      final json = PaymentFixtures.paymentMethodJson();
      final method = PaymentMethod.fromJson(json);
      expect(method.id, 1);
      expect(method.gateway, PaymentGateway.pagarme);
      expect(method.type, PaymentType.credit);
      expect(method.brand, 'Visa');
      expect(method.lastFourDigits, '4242');
      expect(method.isDefault, true);
    });

    test('PaymentMethod.toJson creates correct map', () {
      final method = PaymentFixtures.creditCardBrazil();
      final json = method.toJson();
      expect(json['gateway'], 'pagarme');
      expect(json['type'], 'credit');
      expect(json['brand'], 'Visa');
      expect(json['last_four_digits'], '4242');
    });

    test('Transaction.fromJson creates correct instance', () {
      final json = PaymentFixtures.transactionJson();
      final transaction = Transaction.fromJson(json);
      expect(transaction.id, 1002);
      expect(transaction.gateway, PaymentGateway.stripe);
      expect(transaction.status, TransactionStatus.approved);
      expect(transaction.amount, 150.00);
      expect(transaction.currency, 'BRL');
    });

    test('PixPaymentResponse.fromJson creates correct instance', () {
      final json = PaymentFixtures.pixResponseJson();
      final response = PixPaymentResponse.fromJson(json);
      expect(response.paymentId, '1001');
      expect(response.amount, 59.90);
      expect(response.qrCode, isNotEmpty);
      expect(response.copyPaste, isNotEmpty);
    });

    test('PaymentRequest.toJson creates correct map', () {
      final request = PaymentFixtures.brazilCreditRequest();
      final json = request.toJson();
      expect(json['order_id'], 101);
      expect(json['bar_id'], 12);
      expect(json['amount'], 150.00);
      expect(json['currency'], 'BRL');
      expect(json['payment_method']['type'], 'credit');
      expect(json['tip'], 15.00);
      expect(json['customer_info']['name'], 'João Silva');
    });

    test('PaymentMethod.displayName returns correct format', () {
      expect(PaymentFixtures.creditCardBrazil().displayName, contains('Visa'));
      expect(PaymentFixtures.pixBrazil().displayName, 'PIX');
      expect(PaymentFixtures.walletGlobal().displayName, 'dobar Wallet');
      expect(PaymentFixtures.applePayLatam().displayName, 'Apple Pay');
    });

    test('Transaction status checks work correctly', () {
      expect(PaymentFixtures.pendingPixTransaction().isPending, true);
      expect(PaymentFixtures.approvedCreditTransaction().isPending, false);
    });
  });

  group('Brazil Region (Pagar.me)', () {
    test('PIX payment generates QR code successfully', () async {
      when(
        () => mockRepository.initiatePixPayment(any()),
      ).thenAnswer((_) async => Right(PaymentFixtures.pixResponse()));
      final result = await mockRepository.initiatePixPayment(
        PaymentFixtures.brazilPixRequest(),
      );
      expect(result.isRight(), true);
      result.fold((_) => fail('Expected Right'), (pix) {
        expect(pix.qrCode, isNotEmpty);
        expect(pix.copyPaste, isNotEmpty);
        expect(pix.amount, 59.90);
      });
    });

    test('PIX payment failure returns error', () async {
      when(
        () => mockRepository.initiatePixPayment(any()),
      ).thenAnswer((_) async => Left(ServerFailure('PIX expired', 400)));
      final result = await mockRepository.initiatePixPayment(
        PaymentFixtures.brazilPixRequest(),
      );
      expect(result.isLeft(), true);
    });

    test('Brazil uses BRL currency', () {
      expect(PaymentFixtures.brazilPixRequest().currency, 'BRL');
    });

    test('Brazil supports PIX payment type', () {
      final pix = PaymentFixtures.pixBrazil();
      expect(pix.gateway, PaymentGateway.pagarme);
      expect(pix.type, PaymentType.pix);
    });

    test('Brazil credit card uses Pagar.me gateway', () {
      expect(
        PaymentFixtures.creditCardBrazil().gateway,
        PaymentGateway.pagarme,
      );
    });
  });

  group('Latin America Region (Stripe)', () {
    test('Credit card payment with Stripe succeeds', () async {
      when(() => mockRepository.processPayment(any())).thenAnswer(
        (_) async => Right(PaymentFixtures.approvedCreditTransaction()),
      );
      final result = await mockRepository.processPayment(
        PaymentFixtures.latamCreditRequest(),
      );
      expect(result.isRight(), true);
    });

    test('Apple Pay payment in LATAM works', () async {
      when(
        () => mockRepository.getPaymentMethods(),
      ).thenAnswer((_) async => Right([PaymentFixtures.applePayLatam()]));
      final result = await mockRepository.getPaymentMethods();
      expect(result.isRight(), true);
    });

    test('LATAM uses CLP currency for Chile', () {
      expect(PaymentFixtures.latamCreditRequest().currency, 'CLP');
    });

    test('LATAM uses Stripe gateway', () {
      expect(PaymentFixtures.creditCardLatam().gateway, PaymentGateway.stripe);
    });

    test('Payment declined returns failure', () async {
      when(
        () => mockRepository.processPayment(any()),
      ).thenAnswer((_) async => Left(ServerFailure('Card declined', 400)));
      final result = await mockRepository.processPayment(
        PaymentFixtures.latamCreditRequest(),
      );
      expect(result.isLeft(), true);
    });
  });

  group('United States Region (Stripe)', () {
    test('Credit card payment with tip succeeds', () async {
      when(() => mockRepository.processPayment(any())).thenAnswer(
        (_) async => Right(PaymentFixtures.approvedCreditTransaction()),
      );
      final result = await mockRepository.processPayment(
        PaymentFixtures.usCreditRequest(),
      );
      expect(result.isRight(), true);
      expect(PaymentFixtures.usCreditRequest().tip, 9.20);
    });

    test('Google Pay payment in US works', () async {
      when(
        () => mockRepository.getPaymentMethods(),
      ).thenAnswer((_) async => Right([PaymentFixtures.googlePayUS()]));
      final result = await mockRepository.getPaymentMethods();
      expect(result.isRight(), true);
    });

    test('US uses USD currency', () {
      expect(PaymentFixtures.usCreditRequest().currency, 'USD');
    });

    test('US uses Stripe gateway', () {
      expect(PaymentFixtures.creditCardUS().gateway, PaymentGateway.stripe);
    });

    test('Insufficient funds returns failure', () async {
      when(
        () => mockRepository.processPayment(any()),
      ).thenAnswer((_) async => Left(ServerFailure('Insufficient funds', 400)));
      final result = await mockRepository.processPayment(
        PaymentFixtures.usCreditRequest(),
      );
      expect(result.isLeft(), true);
    });
  });

  group('Rest of World Region (PayPal)', () {
    test('PayPal payment succeeds', () async {
      when(() => mockRepository.processPayment(any())).thenAnswer(
        (_) async => Right(PaymentFixtures.approvedCreditTransaction()),
      );
      final result = await mockRepository.processPayment(
        PaymentFixtures.rowPaypalRequest(),
      );
      expect(result.isRight(), true);
    });

    test('ROW uses PayPal gateway', () {
      expect(PaymentFixtures.paypalROW().gateway, PaymentGateway.paypal);
    });

    test('ROW uses EUR currency for Europe', () {
      expect(PaymentFixtures.rowPaypalRequest().currency, 'EUR');
    });

    test('Refund transaction processed correctly', () {
      final refund = PaymentFixtures.refundedTransaction();
      expect(refund.transactionType, TransactionType.refund);
      expect(refund.status, TransactionStatus.approved);
      expect(refund.gateway, PaymentGateway.paypal);
    });

    test('Transaction history returns mixed statuses', () async {
      when(() => mockRepository.getTransactionHistory()).thenAnswer(
        (_) async => Right([
          PaymentFixtures.approvedCreditTransaction(),
          PaymentFixtures.declinedTransaction(),
          PaymentFixtures.refundedTransaction(),
        ]),
      );
      final result = await mockRepository.getTransactionHistory();
      expect(result.isRight(), true);
      result.fold((_) => fail('Expected Right'), (list) {
        expect(list.length, 3);
      });
    });
  });

  group('Error Handling', () {
    test('Network timeout returns failure', () async {
      when(() => mockRepository.getPaymentMethods()).thenAnswer(
        (_) async => Left(ServerFailure('Connection timed out', 504)),
      );
      final result = await mockRepository.getPaymentMethods();
      expect(result.isLeft(), true);
      result.fold((failure) {
        expect(failure.errorMessage, 'Connection timed out');
        expect((failure as ServerFailure).statusCode, 504);
      }, (_) => fail('Expected Left'));
    });

    test('Session expired returns 401 failure', () async {
      when(
        () => mockRepository.getPaymentMethods(),
      ).thenAnswer((_) async => Left(ServerFailure('Session expired', 401)));
      final result = await mockRepository.getPaymentMethods();
      result.fold(
        (failure) => expect((failure as ServerFailure).statusCode, 401),
        (_) => fail('Expected Left'),
      );
    });

    test('Server error returns 500 failure', () async {
      when(() => mockRepository.getPaymentMethods()).thenAnswer(
        (_) async => Left(ServerFailure('Internal server error', 500)),
      );
      final result = await mockRepository.getPaymentMethods();
      result.fold(
        (failure) => expect((failure as ServerFailure).statusCode, 500),
        (_) => fail('Expected Left'),
      );
    });
  });

  group('New Error Codes System', () {
    test('ErrorCode fromCode returns correct code', () {
      expect(ErrorCode.fromCode('PAYMENT_DECLINED'), ErrorCode.paymentDeclined);
      expect(ErrorCode.fromCode('PIX_EXPIRED'), ErrorCode.pixExpired);
      expect(ErrorCode.fromCode('UNAUTHORIZED'), ErrorCode.unauthorized);
      expect(ErrorCode.fromCode('INVALID_CODE'), ErrorCode.unknown);
    });

    test('ErrorCode fromHttpStatus returns correct code', () {
      expect(ErrorCode.fromHttpStatus(400), ErrorCode.badRequest);
      expect(ErrorCode.fromHttpStatus(401), ErrorCode.unauthorized);
      expect(ErrorCode.fromHttpStatus(404), ErrorCode.notFound);
      expect(ErrorCode.fromHttpStatus(500), ErrorCode.serverUnavailable);
    });

    test('New failures have displayMessage', () {
      final failure = new_failures.PaymentFailure.declined('Card declined');
      expect(failure.displayMessage, 'Card declined');
      expect(failure.errorCode, ErrorCode.paymentDeclined);
    });

    test('New network failures work correctly', () {
      final failure = new_failures.NetworkFailure.timeout();
      expect(failure.errorCode, ErrorCode.networkTimeout);
      expect(failure.displayMessage, 'Connection timed out');
    });

    test('New auth failures work correctly', () {
      final failure = new_failures.AuthFailure.sessionExpired();
      expect(failure.errorCode, ErrorCode.sessionExpired);
    });

    test('New PIX failure works correctly', () {
      final failure = new_failures.PaymentFailure.pixExpired();
      expect(failure.errorCode, ErrorCode.pixExpired);
    });
  });
}
