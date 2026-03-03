import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/payments/data/data_sources/payment_network_datasource.dart';
import 'package:barz/features/payments/domain/models/payment_method.dart';
import 'package:barz/features/payments/domain/models/transaction.dart';
import 'package:barz/features/payments/domain/models/payment_model.dart';
import 'package:barz/features/payments/domain/repositories/abstract_payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentDatasource _datasource;

  PaymentRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<PaymentMethod>>> getPaymentMethods() async {
    try {
      final result = await _datasource.getPaymentMethods();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, PaymentMethod>> addPaymentMethod(
    PaymentMethod method,
    String? cardToken,
  ) async {
    try {
      final result = await _datasource.addPaymentMethod(method, cardToken);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, PaymentMethod>> setDefaultPaymentMethod(
    int methodId,
  ) async {
    try {
      final result = await _datasource.setDefaultPaymentMethod(methodId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, bool>> removePaymentMethod(int methodId) async {
    try {
      final result = await _datasource.removePaymentMethod(methodId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, Transaction>> processPayment(
    PaymentRequest request,
  ) async {
    try {
      final result = await _datasource.processPayment(request);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, PixPaymentResponse>> initiatePixPayment(
    PaymentRequest request,
  ) async {
    try {
      final result = await _datasource.initiatePixPayment(request);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, Transaction>> checkPaymentStatus(
    int transactionId,
  ) async {
    try {
      final result = await _datasource.checkPaymentStatus(transactionId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, List<Transaction>>> getTransactionHistory({
    int? limit,
    int? offset,
  }) async {
    try {
      final result = await _datasource.getTransactionHistory(
        limit: limit,
        offset: offset,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, Transaction>> refundTransaction(
    int transactionId, {
    double? amount,
  }) async {
    try {
      final result = await _datasource.refundTransaction(
        transactionId,
        amount: amount,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, Transaction>> topUpWallet(
    double amount,
    PaymentType paymentType, {
    int? paymentMethodId,
  }) async {
    try {
      final result = await _datasource.topUpWallet(
        amount,
        paymentType,
        paymentMethodId: paymentMethodId,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }
}
