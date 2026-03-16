import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/payments/domain/models/payment_method.dart';
import 'package:barz/features/payments/domain/models/transaction.dart';
import 'package:barz/features/payments/domain/models/payment_model.dart';

abstract class PaymentRepository {
  Future<Either<Failure, List<PaymentMethod>>> getPaymentMethods();
  Future<Either<Failure, PaymentMethod>> addPaymentMethod(
    PaymentMethod method,
    String? cardToken,
  );
  Future<Either<Failure, PaymentMethod>> setDefaultPaymentMethod(int methodId);
  Future<Either<Failure, bool>> removePaymentMethod(int methodId);
  Future<Either<Failure, List<PaymentMethod>>> getSavedCards();
  Future<Either<Failure, PaymentMethod>> addSavedCard({
    required String cardToken,
    required String lastFour,
    required String brand,
    required int expMonth,
    required int expYear,
    bool isDefault = false,
  });
  Future<Either<Failure, bool>> deleteSavedCard(int cardId);
  Future<Either<Failure, Transaction>> processPayment(PaymentRequest request);
  Future<Either<Failure, PixPaymentResponse>> initiatePixPayment(
    PaymentRequest request,
  );
  Future<Either<Failure, Transaction>> checkPaymentStatus(int transactionId);
  Future<Either<Failure, List<Transaction>>> getTransactionHistory({
    int? limit,
    int? offset,
  });
  Future<Either<Failure, Transaction>> refundTransaction(
    int transactionId, {
    double? amount,
  });
  Future<Either<Failure, Transaction>> topUpWallet(
    double amount,
    PaymentType paymentType, {
    int? paymentMethodId,
  });
}
