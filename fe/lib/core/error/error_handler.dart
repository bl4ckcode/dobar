import 'package:dio/dio.dart';
import 'error_codes.dart';
import 'exceptions.dart';
import 'failures.dart';

class ErrorHandler {
  static AppException handleDioException(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException.timeout();
      
      case DioExceptionType.connectionError:
        return NetworkException.noInternet();
      
      case DioExceptionType.badResponse:
        return _handleBadResponse(exception);
      
      case DioExceptionType.cancel:
        return const NetworkException(errorCode: ErrorCode.unknown, message: 'Request cancelled');
      
      default:
        return NetworkException.connectionError(exception.message);
    }
  }

  static AppException _handleBadResponse(DioException exception) {
    final statusCode = exception.response?.statusCode;
    final data = exception.response?.data as Map<String, dynamic>?;
    final errorCode = data?['error_code'] as String?;

    if (statusCode == 401) {
      if (errorCode == 'SESSION_EXPIRED') {
        return AuthException.sessionExpired();
      }
      return AuthException.unauthorized();
    }

    if (statusCode == 422) {
      return ValidationException.fromResponse(data);
    }

    if (errorCode != null && _isPaymentError(errorCode)) {
      return PaymentException(
        errorCode: ErrorCode.fromCode(errorCode),
        message: data?['message'] as String?,
        statusCode: statusCode,
        gatewayCode: data?['gateway_code'] as String?,
        transactionId: data?['transaction_id'] as String?,
      );
    }

    return ServerException.fromResponse(data, statusCode);
  }

  static bool _isPaymentError(String code) {
    const paymentCodes = [
      'PAYMENT_DECLINED',
      'PAYMENT_EXPIRED',
      'INSUFFICIENT_FUNDS',
      'INVALID_CARD',
      'CARD_EXPIRED',
      'PIX_EXPIRED',
      'PAYMENT_PROCESSING',
      'REFUND_FAILED',
    ];
    return paymentCodes.contains(code);
  }

  static Failure mapExceptionToFailure(AppException exception) {
    if (exception is NetworkException) {
      return NetworkFailure(
        errorCode: exception.errorCode,
        message: exception.message,
      );
    }

    if (exception is AuthException) {
      return AuthFailure(
        errorCode: exception.errorCode,
        message: exception.message,
      );
    }

    if (exception is PaymentException) {
      return PaymentFailure(
        errorCode: exception.errorCode,
        message: exception.message,
        statusCode: exception.statusCode,
        gatewayCode: exception.gatewayCode,
        transactionId: exception.transactionId,
      );
    }

    if (exception is ValidationException) {
      return ValidationFailure(
        message: exception.message,
        fieldErrors: exception.fieldErrors,
      );
    }

    if (exception is LocationException) {
      return LocationFailure(
        errorCode: exception.errorCode,
        message: exception.message,
      );
    }

    return ServerFailure(
      errorCode: exception.errorCode,
      message: exception.message,
      statusCode: exception.statusCode,
    );
  }

  static Failure handleException(Object exception) {
    if (exception is AppException) {
      return mapExceptionToFailure(exception);
    }

    if (exception is DioException) {
      return mapExceptionToFailure(handleDioException(exception));
    }

    return ServerFailure.unknown(exception.toString());
  }
}
