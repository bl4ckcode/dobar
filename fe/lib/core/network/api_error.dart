import 'package:dio/dio.dart';

enum ErrorCode {
  unknown,
  networkTimeout,
  networkError,
  noInternet,
  serverUnavailable,
  badRequest,
  notFound,
  conflict,
  validationError,
  rateLimited,
  maintenanceMode,
  unauthorized,
  forbidden,
  sessionExpired,
  invalidToken,
  paymentDeclined,
  paymentExpired,
  insufficientFunds,
  invalidCard,
  cardExpired,
  pixExpired,
  paymentProcessing,
  refundFailed,
  walletLimitExceeded,
  minimumAmountNotMet,
  maximumAmountExceeded,
  orderNotFound,
  orderCancelled,
  orderAlreadyPaid,
  orderExpired,
  userNotFound,
  emailInUse,
  phoneInUse,
  invalidCpf,
  invalidRg,
  documentInUse,
  partnerNotFound,
  partnerClosed,
  itemUnavailable,
  locationPermissionDenied,
  locationServiceDisabled,
  promotionExpired,
  promotionNotApplicable,
  offerAlreadyRedeemed,
}

class ApiError {
  final ErrorCode code;
  final String message;
  final Map<String, List<String>>? details;
  final String? gatewayCode;
  final String? transactionId;
  final int? statusCode;

  const ApiError({
    required this.code,
    required this.message,
    this.details,
    this.gatewayCode,
    this.transactionId,
    this.statusCode,
  });

  factory ApiError.fromJson(Map<String, dynamic> json, {int? statusCode}) {
    return ApiError(
      code: _parseErrorCode(json['error_code'] as String?),
      message: json['message'] as String? ?? 'Unknown error',
      details: (json['details'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as List).cast<String>()),
      ),
      gatewayCode: json['gateway_code'] as String?,
      transactionId: json['transaction_id'] as String?,
      statusCode: statusCode,
    );
  }

  factory ApiError.fromDioException(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data.containsKey('error_code')) {
      return ApiError.fromJson(data, statusCode: e.response?.statusCode);
    }
    return ApiError(
      code: _codeFromStatus(e.response?.statusCode),
      message: e.message ?? 'Network error',
      statusCode: e.response?.statusCode,
    );
  }

  static ErrorCode _parseErrorCode(String? code) {
    if (code == null) return ErrorCode.unknown;
    final normalized = code.toLowerCase().replaceAll('_', '');
    return ErrorCode.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => ErrorCode.unknown,
    );
  }

  static ErrorCode _codeFromStatus(int? status) {
    switch (status) {
      case 400: return ErrorCode.badRequest;
      case 401: return ErrorCode.unauthorized;
      case 403: return ErrorCode.forbidden;
      case 404: return ErrorCode.notFound;
      case 409: return ErrorCode.conflict;
      case 422: return ErrorCode.validationError;
      case 429: return ErrorCode.rateLimited;
      case 500: return ErrorCode.serverUnavailable;
      case 502: return ErrorCode.serverUnavailable;
      case 503: return ErrorCode.maintenanceMode;
      case 504: return ErrorCode.networkTimeout;
      default: return ErrorCode.unknown;
    }
  }

  bool get isAuthError => code == ErrorCode.unauthorized || 
                          code == ErrorCode.forbidden ||
                          code == ErrorCode.sessionExpired ||
                          code == ErrorCode.invalidToken;

  bool get isPaymentError => code.name.contains('payment') || 
                             code.name.contains('card') ||
                             code.name.contains('pix') ||
                             code.name.contains('wallet') ||
                             code.name.contains('funds');

  @override
  String toString() => 'ApiError($code): $message';
}
