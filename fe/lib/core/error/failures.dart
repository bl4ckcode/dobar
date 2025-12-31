import 'package:equatable/equatable.dart';
import 'error_codes.dart';

abstract class Failure extends Equatable {
  final ErrorCode errorCode;
  final String? message;
  final int? statusCode;

  const Failure({
    required this.errorCode,
    this.message,
    this.statusCode,
  });

  String get displayMessage => message ?? errorCode.defaultMessage;

  @override
  List<Object?> get props => [errorCode, message, statusCode];
}

class ServerFailure extends Failure {
  const ServerFailure({
    required super.errorCode,
    super.message,
    super.statusCode,
  });

  factory ServerFailure.fromCode(ErrorCode code, [String? message]) {
    return ServerFailure(errorCode: code, message: message);
  }

  factory ServerFailure.unknown([String? message]) {
    return ServerFailure(errorCode: ErrorCode.unknown, message: message);
  }
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.errorCode,
    super.message,
  });

  factory NetworkFailure.timeout() {
    return const NetworkFailure(errorCode: ErrorCode.networkTimeout);
  }

  factory NetworkFailure.noInternet() {
    return const NetworkFailure(errorCode: ErrorCode.noInternet);
  }

  factory NetworkFailure.connectionError([String? message]) {
    return NetworkFailure(errorCode: ErrorCode.networkError, message: message);
  }
}

class AuthFailure extends Failure {
  const AuthFailure({
    required super.errorCode,
    super.message,
  });

  factory AuthFailure.unauthorized() {
    return const AuthFailure(errorCode: ErrorCode.unauthorized);
  }

  factory AuthFailure.sessionExpired() {
    return const AuthFailure(errorCode: ErrorCode.sessionExpired);
  }
}

class PaymentFailure extends Failure {
  final String? gatewayCode;
  final String? transactionId;

  const PaymentFailure({
    required super.errorCode,
    super.message,
    super.statusCode,
    this.gatewayCode,
    this.transactionId,
  });

  factory PaymentFailure.declined([String? message]) {
    return PaymentFailure(errorCode: ErrorCode.paymentDeclined, message: message);
  }

  factory PaymentFailure.insufficientFunds() {
    return const PaymentFailure(errorCode: ErrorCode.insufficientFunds);
  }

  factory PaymentFailure.invalidCard([String? message]) {
    return PaymentFailure(errorCode: ErrorCode.invalidCard, message: message);
  }

  factory PaymentFailure.pixExpired() {
    return const PaymentFailure(errorCode: ErrorCode.pixExpired);
  }

  @override
  List<Object?> get props => [...super.props, gatewayCode, transactionId];
}

class ValidationFailure extends Failure {
  final Map<String, List<String>>? fieldErrors;

  const ValidationFailure({
    super.message,
    this.fieldErrors,
  }) : super(errorCode: ErrorCode.validationError);

  String? getFieldError(String field) {
    return fieldErrors?[field]?.firstOrNull;
  }

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

class LocationFailure extends Failure {
  const LocationFailure({
    required super.errorCode,
    super.message,
  });

  factory LocationFailure.permissionDenied() {
    return const LocationFailure(errorCode: ErrorCode.locationPermissionDenied);
  }

  factory LocationFailure.serviceDisabled() {
    return const LocationFailure(errorCode: ErrorCode.locationServiceDisabled);
  }
}
