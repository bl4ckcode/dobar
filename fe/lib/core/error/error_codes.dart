enum ErrorCode {
  unknown('UNKNOWN', 'An unexpected error occurred'),

  networkTimeout('NETWORK_TIMEOUT', 'Connection timed out'),
  networkError('NETWORK_ERROR', 'Network connection failed'),
  noInternet('NO_INTERNET', 'No internet connection'),
  serverUnavailable('SERVER_UNAVAILABLE', 'Server is temporarily unavailable'),

  unauthorized('UNAUTHORIZED', 'Authentication required'),
  forbidden('FORBIDDEN', 'Access denied'),
  sessionExpired('SESSION_EXPIRED', 'Your session has expired'),
  invalidToken('INVALID_TOKEN', 'Invalid authentication token'),

  notFound('NOT_FOUND', 'Resource not found'),
  conflict('CONFLICT', 'Resource already exists'),
  validationError('VALIDATION_ERROR', 'Invalid data provided'),
  badRequest('BAD_REQUEST', 'Invalid request'),

  paymentDeclined('PAYMENT_DECLINED', 'Payment was declined'),
  paymentExpired('PAYMENT_EXPIRED', 'Payment has expired'),
  insufficientFunds('INSUFFICIENT_FUNDS', 'Insufficient funds'),
  invalidCard('INVALID_CARD', 'Invalid card details'),
  cardExpired('CARD_EXPIRED', 'Card has expired'),
  pixExpired('PIX_EXPIRED', 'PIX payment has expired'),
  paymentProcessing('PAYMENT_PROCESSING', 'Payment is being processed'),
  refundFailed('REFUND_FAILED', 'Refund could not be processed'),

  orderNotFound('ORDER_NOT_FOUND', 'Order not found'),
  orderCancelled('ORDER_CANCELLED', 'Order has been cancelled'),
  orderAlreadyPaid('ORDER_ALREADY_PAID', 'Order has already been paid'),
  orderExpired('ORDER_EXPIRED', 'Order has expired'),

  userNotFound('USER_NOT_FOUND', 'User not found'),
  emailInUse('EMAIL_IN_USE', 'Email is already registered'),
  phoneInUse('PHONE_IN_USE', 'Phone number is already registered'),
  invalidCpf('INVALID_CPF', 'Invalid CPF number'),
  invalidRg('INVALID_RG', 'Invalid RG number'),
  documentInUse('DOCUMENT_IN_USE', 'Document is already registered'),

  partnerNotFound('PARTNER_NOT_FOUND', 'Partner not found'),
  partnerClosed('PARTNER_CLOSED', 'Partner is currently closed'),
  itemUnavailable('ITEM_UNAVAILABLE', 'Item is not available'),

  cartItemNotFound('CART_ITEM_NOT_FOUND', 'Cart item not found'),
  cartEmpty('CART_EMPTY', 'Cart is empty'),

  locationPermissionDenied(
    'LOCATION_PERMISSION_DENIED',
    'Location permission denied',
  ),
  locationServiceDisabled(
    'LOCATION_SERVICE_DISABLED',
    'Location service is disabled',
  ),

  walletLimitExceeded('WALLET_LIMIT_EXCEEDED', 'Wallet limit exceeded'),
  minimumAmountNotMet('MINIMUM_AMOUNT_NOT_MET', 'Minimum amount not met'),
  maximumAmountExceeded('MAXIMUM_AMOUNT_EXCEEDED', 'Maximum amount exceeded'),

  promotionExpired('PROMOTION_EXPIRED', 'Promotion has expired'),
  promotionNotApplicable(
    'PROMOTION_NOT_APPLICABLE',
    'Promotion is not applicable',
  ),
  offerAlreadyRedeemed(
    'OFFER_ALREADY_REDEEMED',
    'Offer has already been redeemed',
  ),

  rateLimited('RATE_LIMITED', 'Too many requests, please try again later'),
  maintenanceMode('MAINTENANCE_MODE', 'Service is under maintenance');

  final String code;
  final String defaultMessage;

  const ErrorCode(this.code, this.defaultMessage);

  static ErrorCode fromCode(String code) {
    return ErrorCode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ErrorCode.unknown,
    );
  }

  static ErrorCode fromHttpStatus(int statusCode) {
    switch (statusCode) {
      case 400:
        return ErrorCode.badRequest;
      case 401:
        return ErrorCode.unauthorized;
      case 403:
        return ErrorCode.forbidden;
      case 404:
        return ErrorCode.notFound;
      case 409:
        return ErrorCode.conflict;
      case 422:
        return ErrorCode.validationError;
      case 429:
        return ErrorCode.rateLimited;
      case 500:
      case 502:
      case 503:
        return ErrorCode.serverUnavailable;
      case 504:
        return ErrorCode.networkTimeout;
      default:
        return ErrorCode.unknown;
    }
  }
}
