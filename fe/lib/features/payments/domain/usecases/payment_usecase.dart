import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/payments/domain/models/payment_method.dart';
import 'package:barz/features/payments/domain/models/transaction.dart';
import 'package:barz/features/payments/domain/models/payment_model.dart';
import 'package:barz/features/payments/domain/repositories/abstract_payment_repository.dart';

class PaymentUsecase {
  final PaymentRepository _repository;

  PaymentUsecase(this._repository);

  Future<Either<Failure, List<PaymentMethod>>> getPaymentMethods() {
    return _repository.getPaymentMethods();
  }

  Future<Either<Failure, PaymentMethod>> addPaymentMethod(PaymentMethod method, {String? cardToken}) {
    return _repository.addPaymentMethod(method, cardToken);
  }

  Future<Either<Failure, PaymentMethod>> setDefaultPaymentMethod(int methodId) {
    return _repository.setDefaultPaymentMethod(methodId);
  }

  Future<Either<Failure, bool>> removePaymentMethod(int methodId) {
    return _repository.removePaymentMethod(methodId);
  }

  Future<Either<Failure, Transaction>> processPayment(PaymentRequest request) {
    return _repository.processPayment(request);
  }

  Future<Either<Failure, PixPaymentResponse>> initiatePixPayment(PaymentRequest request) {
    return _repository.initiatePixPayment(request);
  }

  Future<Either<Failure, Transaction>> checkPaymentStatus(int transactionId) {
    return _repository.checkPaymentStatus(transactionId);
  }

  Future<Either<Failure, List<Transaction>>> getTransactionHistory({int? limit, int? offset}) {
    return _repository.getTransactionHistory(limit: limit, offset: offset);
  }

  Future<Either<Failure, Transaction>> refundTransaction(int transactionId, {double? amount}) {
    return _repository.refundTransaction(transactionId, amount: amount);
  }

  Future<Either<Failure, Transaction>> topUpWallet(double amount, PaymentType paymentType, {int? paymentMethodId}) {
    return _repository.topUpWallet(amount, paymentType, paymentMethodId: paymentMethodId);
  }
}
