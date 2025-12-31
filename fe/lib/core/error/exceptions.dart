import 'error_codes.dart';

abstract class AppException implements Exception {
  final ErrorCode errorCode;
  final String? message;
  final int? statusCode;
  final dynamic originalError;

  const AppException({
    required this.errorCode,
    this.message,
    this.statusCode,
    this.originalError,
  });

  String get displayMessage => message ?? errorCode.defaultMessage;
}

class ServerException extends AppException {
  const ServerException({
    required super.errorCode,
    super.message,
    super.statusCode,
    super.originalError,
  });

  factory ServerException.fromResponse(Map<String, dynamic>? data, int? statusCode) {
    final errorCode = data?['error_code'] as String?;
    final message = data?['message'] ?? data?['detail'] as String?;
    
    return ServerException(
      errorCode: errorCode != null 
          ? ErrorCode.fromCode(errorCode) 
          : ErrorCode.fromHttpStatus(statusCode ?? 500),
      message: message,
      statusCode: statusCode,
    );
  }

  factory ServerException.unknown([String? message]) {
    return ServerException(
      errorCode: ErrorCode.unknown,
      message: message,
    );
  }
}

class NetworkException extends AppException {
  const NetworkException({
    required super.errorCode,
    super.message,
    super.originalError,
  });

  factory NetworkException.timeout() {
    return const NetworkException(errorCode: ErrorCode.networkTimeout);
  }

  factory NetworkException.noInternet() {
    return const NetworkException(errorCode: ErrorCode.noInternet);
  }

  factory NetworkException.connectionError([String? message]) {
    return NetworkException(errorCode: ErrorCode.networkError, message: message);
  }
}

class AuthException extends AppException {
  const AuthException({
    required super.errorCode,
    super.message,
    super.statusCode,
  });

  factory AuthException.unauthorized() {
    return const AuthException(errorCode: ErrorCode.unauthorized);
  }

  factory AuthException.sessionExpired() {
    return const AuthException(errorCode: ErrorCode.sessionExpired);
  }

  factory AuthException.invalidToken() {
    return const AuthException(errorCode: ErrorCode.invalidToken);
  }
}

class PaymentException extends AppException {
  final String? gatewayCode;
  final String? transactionId;

  const PaymentException({
    required super.errorCode,
    super.message,
    super.statusCode,
    this.gatewayCode,
    this.transactionId,
  });

  factory PaymentException.declined([String? message]) {
    return PaymentException(errorCode: ErrorCode.paymentDeclined, message: message);
  }

  factory PaymentException.insufficientFunds() {
    return const PaymentException(errorCode: ErrorCode.insufficientFunds);
  }

  factory PaymentException.invalidCard([String? message]) {
    return PaymentException(errorCode: ErrorCode.invalidCard, message: message);
  }

  factory PaymentException.pixExpired() {
    return const PaymentException(errorCode: ErrorCode.pixExpired);
  }
}

class ValidationException extends AppException {
  final Map<String, List<String>>? fieldErrors;

  const ValidationException({
    super.message,
    this.fieldErrors,
  }) : super(errorCode: ErrorCode.validationError);

  factory ValidationException.fromResponse(Map<String, dynamic>? data) {
    final errors = data?['errors'] as Map<String, dynamic>?;
    return ValidationException(
      message: data?['message'] as String?,
      fieldErrors: errors?.map((key, value) => MapEntry(
        key,
        (value as List).map((e) => e.toString()).toList(),
      )),
    );
  }

  String? getFieldError(String field) {
    return fieldErrors?[field]?.firstOrNull;
  }
}

class LocationException extends AppException {
  const LocationException({
    required super.errorCode,
    super.message,
  });

  factory LocationException.permissionDenied() {
    return const LocationException(errorCode: ErrorCode.locationPermissionDenied);
  }

  factory LocationException.serviceDisabled() {
    return const LocationException(errorCode: ErrorCode.locationServiceDisabled);
  }
}
