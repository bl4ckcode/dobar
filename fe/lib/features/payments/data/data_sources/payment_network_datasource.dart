import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/core/utils/idempotency.dart';
import 'package:barz/features/payments/domain/models/payment_method.dart';
import 'package:barz/features/payments/domain/models/transaction.dart';
import 'package:barz/features/payments/domain/models/payment_model.dart';
import 'package:dio/dio.dart';

abstract class PaymentDatasource {
  Future<List<PaymentMethod>> getPaymentMethods();
  Future<PaymentMethod> addPaymentMethod(
    PaymentMethod method,
    String? cardToken,
  );
  Future<PaymentMethod> setDefaultPaymentMethod(int methodId);
  Future<bool> removePaymentMethod(int methodId);
  Future<List<PaymentMethod>> getSavedCards();
  Future<PaymentMethod> addSavedCard({
    required String cardToken,
    required String lastFour,
    required String brand,
    required int expMonth,
    required int expYear,
    bool isDefault = false,
  });
  Future<bool> deleteSavedCard(int cardId);
  Future<Transaction> processPayment(
    PaymentRequest request, {
    String? idempotencyKey,
  });
  Future<PixPaymentResponse> initiatePixPayment(
    PaymentRequest request, {
    String? idempotencyKey,
  });
  Future<Transaction> checkPaymentStatus(int transactionId);
  Future<List<Transaction>> getTransactionHistory({int? limit, int? offset});
  Future<Transaction> refundTransaction(
    int transactionId, {
    double? amount,
    String? idempotencyKey,
  });
  Future<Transaction> topUpWallet(
    double amount,
    PaymentType paymentType, {
    int? paymentMethodId,
    String? idempotencyKey,
  });
}

class PaymentNetworkDatasource implements PaymentDatasource {
  final Dio dio;

  PaymentNetworkDatasource({required this.dio});

  @override
  Future<List<PaymentMethod>> getPaymentMethods() async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.paymentMethods}',
      );
      return (response.data as List)
          .map((json) => PaymentMethod.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get payment methods',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<PaymentMethod> addPaymentMethod(
    PaymentMethod method,
    String? cardToken,
  ) async {
    try {
      final data = method.toJson();
      if (cardToken != null) data['card_token'] = cardToken;
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.paymentMethods}',
        data: data,
      );
      return PaymentMethod.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to add payment method',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<PaymentMethod> setDefaultPaymentMethod(int methodId) async {
    try {
      final response = await dio.put(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.paymentMethods}/$methodId/default',
      );
      return PaymentMethod.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to set default payment method',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<bool> removePaymentMethod(int methodId) async {
    try {
      await dio.delete(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.paymentMethods}/$methodId',
      );
      return true;
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to remove payment method',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<List<PaymentMethod>> getSavedCards() async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.savedCards}',
      );
      return (response.data as List)
          .map((json) => PaymentMethod.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get saved cards',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<PaymentMethod> addSavedCard({
    required String cardToken,
    required String lastFour,
    required String brand,
    required int expMonth,
    required int expYear,
    bool isDefault = false,
  }) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.savedCards}',
        data: {
          'card_token': cardToken,
          'last_four': lastFour,
          'brand': brand,
          'exp_month': expMonth,
          'exp_year': expYear,
          'is_default': isDefault,
        },
      );
      return PaymentMethod.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to add card',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<bool> deleteSavedCard(int cardId) async {
    try {
      await dio.delete(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.savedCard(cardId)}',
      );
      return true;
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to delete card',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<Transaction> processPayment(
    PaymentRequest request, {
    String? idempotencyKey,
  }) async {
    try {
      final key = idempotencyKey ?? IdempotencyKey.forPayment(request.orderId);
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.payments}',
        data: request.toJson(),
        options: Options(headers: {'X-Idempotency-Key': key}),
      );
      return Transaction.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to process payment',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<PixPaymentResponse> initiatePixPayment(
    PaymentRequest request, {
    String? idempotencyKey,
  }) async {
    try {
      final key = idempotencyKey ?? IdempotencyKey.forPayment(request.orderId);
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.pixPayment}',
        data: request.toJson(),
        options: Options(headers: {'X-Idempotency-Key': key}),
      );
      return PixPaymentResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to initiate PIX payment',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<Transaction> checkPaymentStatus(int transactionId) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.payments}/$transactionId/status',
      );
      return Transaction.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to check payment status',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<List<Transaction>> getTransactionHistory({
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.transactions}',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      return (response.data as List)
          .map((json) => Transaction.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get transaction history',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<Transaction> refundTransaction(
    int transactionId, {
    double? amount,
    String? idempotencyKey,
  }) async {
    try {
      final key =
          idempotencyKey ?? IdempotencyKey.forOrder(transactionId, 'refund');
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.payments}/$transactionId/refund',
        data: amount != null ? {'amount': amount} : null,
        options: Options(headers: {'X-Idempotency-Key': key}),
      );
      return Transaction.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to refund transaction',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<Transaction> topUpWallet(
    double amount,
    PaymentType paymentType, {
    int? paymentMethodId,
    String? idempotencyKey,
  }) async {
    try {
      final key = idempotencyKey ?? IdempotencyKey.generate();
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.walletTopUp}',
        data: {
          'amount': amount,
          'payment_type': paymentType.name,
          if (paymentMethodId != null) 'payment_method_id': paymentMethodId,
        },
        options: Options(headers: {'X-Idempotency-Key': key}),
      );
      return Transaction.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to top up wallet',
        e.response?.statusCode,
      );
    }
  }
}
