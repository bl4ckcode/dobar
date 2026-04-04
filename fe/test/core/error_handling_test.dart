import 'package:barz/core/error/error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorCode', () {
    test('fromCode returns correct ErrorCode', () {
      expect(ErrorCode.fromCode('PAYMENT_DECLINED'), ErrorCode.paymentDeclined);
      expect(ErrorCode.fromCode('PIX_EXPIRED'), ErrorCode.pixExpired);
      expect(ErrorCode.fromCode('UNAUTHORIZED'), ErrorCode.unauthorized);
      expect(ErrorCode.fromCode('INVALID_CODE'), ErrorCode.unknown);
    });

    test('fromHttpStatus returns correct ErrorCode', () {
      expect(ErrorCode.fromHttpStatus(400), ErrorCode.badRequest);
      expect(ErrorCode.fromHttpStatus(401), ErrorCode.unauthorized);
      expect(ErrorCode.fromHttpStatus(403), ErrorCode.forbidden);
      expect(ErrorCode.fromHttpStatus(404), ErrorCode.notFound);
      expect(ErrorCode.fromHttpStatus(409), ErrorCode.conflict);
      expect(ErrorCode.fromHttpStatus(422), ErrorCode.validationError);
      expect(ErrorCode.fromHttpStatus(429), ErrorCode.rateLimited);
      expect(ErrorCode.fromHttpStatus(500), ErrorCode.serverUnavailable);
      expect(ErrorCode.fromHttpStatus(502), ErrorCode.serverUnavailable);
      expect(ErrorCode.fromHttpStatus(503), ErrorCode.serverUnavailable);
      expect(ErrorCode.fromHttpStatus(504), ErrorCode.networkTimeout);
      expect(ErrorCode.fromHttpStatus(999), ErrorCode.unknown);
    });

    test('ErrorCode has correct default messages', () {
      expect(ErrorCode.paymentDeclined.defaultMessage, 'Payment was declined');
      expect(ErrorCode.pixExpired.defaultMessage, 'PIX payment has expired');
      expect(ErrorCode.noInternet.defaultMessage, 'No internet connection');
    });

    test('Cart error codes exist and have correct values', () {
      expect(
        ErrorCode.fromCode('CART_ITEM_NOT_FOUND'),
        ErrorCode.cartItemNotFound,
      );
      expect(ErrorCode.fromCode('CART_EMPTY'), ErrorCode.cartEmpty);
      expect(ErrorCode.cartItemNotFound.defaultMessage, 'Cart item not found');
      expect(ErrorCode.cartEmpty.defaultMessage, 'Cart is empty');
    });
  });

  group('ServerException', () {
    test('fromResponse creates exception with error_code', () {
      final data = {
        'error_code': 'PAYMENT_DECLINED',
        'message': 'Your payment was declined',
      };

      final exception = ServerException.fromResponse(data, 400);

      expect(exception.errorCode, ErrorCode.paymentDeclined);
      expect(exception.message, 'Your payment was declined');
      expect(exception.statusCode, 400);
    });

    test('fromResponse falls back to HTTP status when no error_code', () {
      final data = {'message': 'Not found'};

      final exception = ServerException.fromResponse(data, 404);

      expect(exception.errorCode, ErrorCode.notFound);
    });

    test('unknown factory creates correct exception', () {
      final exception = ServerException.unknown('Something went wrong');

      expect(exception.errorCode, ErrorCode.unknown);
      expect(exception.message, 'Something went wrong');
    });

    test('displayMessage returns message or default', () {
      final withMessage = ServerException.fromResponse({
        'message': 'Custom',
      }, 400);
      final withoutMessage = ServerException.unknown();

      expect(withMessage.displayMessage, 'Custom');
      expect(withoutMessage.displayMessage, ErrorCode.unknown.defaultMessage);
    });
  });

  group('NetworkException', () {
    test('timeout factory creates correct exception', () {
      final exception = NetworkException.timeout();

      expect(exception.errorCode, ErrorCode.networkTimeout);
      expect(exception.displayMessage, 'Connection timed out');
    });

    test('noInternet factory creates correct exception', () {
      final exception = NetworkException.noInternet();

      expect(exception.errorCode, ErrorCode.noInternet);
      expect(exception.displayMessage, 'No internet connection');
    });

    test('connectionError factory creates correct exception', () {
      final exception = NetworkException.connectionError('Custom error');

      expect(exception.errorCode, ErrorCode.networkError);
      expect(exception.message, 'Custom error');
    });
  });

  group('AuthException', () {
    test('unauthorized factory creates correct exception', () {
      final exception = AuthException.unauthorized();

      expect(exception.errorCode, ErrorCode.unauthorized);
    });

    test('sessionExpired factory creates correct exception', () {
      final exception = AuthException.sessionExpired();

      expect(exception.errorCode, ErrorCode.sessionExpired);
    });

    test('invalidToken factory creates correct exception', () {
      final exception = AuthException.invalidToken();

      expect(exception.errorCode, ErrorCode.invalidToken);
    });
  });

  group('PaymentException', () {
    test('declined factory creates correct exception', () {
      final exception = PaymentException.declined('Card declined');

      expect(exception.errorCode, ErrorCode.paymentDeclined);
      expect(exception.message, 'Card declined');
    });

    test('insufficientFunds factory creates correct exception', () {
      final exception = PaymentException.insufficientFunds();

      expect(exception.errorCode, ErrorCode.insufficientFunds);
    });

    test('pixExpired factory creates correct exception', () {
      final exception = PaymentException.pixExpired();

      expect(exception.errorCode, ErrorCode.pixExpired);
    });

    test('stores gateway code and transaction id', () {
      const exception = PaymentException(
        errorCode: ErrorCode.paymentDeclined,
        gatewayCode: 'insufficient_funds',
        transactionId: 'txn_123',
      );

      expect(exception.gatewayCode, 'insufficient_funds');
      expect(exception.transactionId, 'txn_123');
    });
  });

  group('ValidationException', () {
    test('fromResponse creates exception with field errors', () {
      final data = {
        'message': 'Validation failed',
        'errors': {
          'email': ['Invalid format'],
          'cpf': ['Required', 'Invalid'],
        },
      };

      final exception = ValidationException.fromResponse(data);

      expect(exception.errorCode, ErrorCode.validationError);
      expect(exception.message, 'Validation failed');
      expect(exception.fieldErrors?['email'], ['Invalid format']);
      expect(exception.fieldErrors?['cpf'], ['Required', 'Invalid']);
    });

    test('getFieldError returns first error for field', () {
      const exception = ValidationException(
        fieldErrors: {
          'email': ['Error 1', 'Error 2'],
        },
      );

      expect(exception.getFieldError('email'), 'Error 1');
      expect(exception.getFieldError('phone'), null);
    });
  });

  group('LocationException', () {
    test('permissionDenied factory creates correct exception', () {
      final exception = LocationException.permissionDenied();

      expect(exception.errorCode, ErrorCode.locationPermissionDenied);
    });

    test('serviceDisabled factory creates correct exception', () {
      final exception = LocationException.serviceDisabled();

      expect(exception.errorCode, ErrorCode.locationServiceDisabled);
    });
  });

  group('Failures', () {
    test('ServerFailure has correct properties', () {
      final failure = ServerFailure.fromCode(
        ErrorCode.notFound,
        'Resource not found',
      );

      expect(failure.errorCode, ErrorCode.notFound);
      expect(failure.displayMessage, 'Resource not found');
    });

    test('NetworkFailure factories work correctly', () {
      expect(NetworkFailure.timeout().errorCode, ErrorCode.networkTimeout);
      expect(NetworkFailure.noInternet().errorCode, ErrorCode.noInternet);
      expect(
        NetworkFailure.connectionError().errorCode,
        ErrorCode.networkError,
      );
    });

    test('AuthFailure factories work correctly', () {
      expect(AuthFailure.unauthorized().errorCode, ErrorCode.unauthorized);
      expect(AuthFailure.sessionExpired().errorCode, ErrorCode.sessionExpired);
    });

    test('PaymentFailure stores extra properties', () {
      const failure = PaymentFailure(
        errorCode: ErrorCode.paymentDeclined,
        gatewayCode: 'refused',
        transactionId: 'txn_456',
      );

      expect(failure.gatewayCode, 'refused');
      expect(failure.transactionId, 'txn_456');
    });

    test('ValidationFailure getFieldError works', () {
      const failure = ValidationFailure(
        fieldErrors: {
          'amount': ['Must be positive'],
        },
      );

      expect(failure.getFieldError('amount'), 'Must be positive');
    });

    test('LocationFailure factories work correctly', () {
      expect(
        LocationFailure.permissionDenied().errorCode,
        ErrorCode.locationPermissionDenied,
      );
      expect(
        LocationFailure.serviceDisabled().errorCode,
        ErrorCode.locationServiceDisabled,
      );
    });
  });

  group('ErrorHandler', () {
    test('handleDioException handles timeout', () {
      final dioException = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(),
      );

      final exception = ErrorHandler.handleDioException(dioException);

      expect(exception, isA<NetworkException>());
      expect(exception.errorCode, ErrorCode.networkTimeout);
    });

    test('handleDioException handles connection error', () {
      final dioException = DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(),
      );

      final exception = ErrorHandler.handleDioException(dioException);

      expect(exception, isA<NetworkException>());
      expect(exception.errorCode, ErrorCode.noInternet);
    });

    test('handleDioException handles 401 as AuthException', () {
      final dioException = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(),
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 401,
          data: {'error_code': 'UNAUTHORIZED'},
        ),
      );

      final exception = ErrorHandler.handleDioException(dioException);

      expect(exception, isA<AuthException>());
      expect(exception.errorCode, ErrorCode.unauthorized);
    });

    test('handleDioException handles 401 SESSION_EXPIRED', () {
      final dioException = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(),
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 401,
          data: {'error_code': 'SESSION_EXPIRED'},
        ),
      );

      final exception = ErrorHandler.handleDioException(dioException);

      expect(exception, isA<AuthException>());
      expect(exception.errorCode, ErrorCode.sessionExpired);
    });

    test('handleDioException handles 422 as ValidationException', () {
      final dioException = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(),
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 422,
          data: {
            'message': 'Validation failed',
            'errors': {
              'email': ['Invalid'],
            },
          },
        ),
      );

      final exception = ErrorHandler.handleDioException(dioException);

      expect(exception, isA<ValidationException>());
      expect((exception as ValidationException).fieldErrors?['email'], [
        'Invalid',
      ]);
    });

    test('handleDioException handles payment errors as PaymentException', () {
      final dioException = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(),
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 400,
          data: {
            'error_code': 'PAYMENT_DECLINED',
            'message': 'Card declined',
            'gateway_code': 'refused',
            'transaction_id': 'txn_789',
          },
        ),
      );

      final exception = ErrorHandler.handleDioException(dioException);

      expect(exception, isA<PaymentException>());
      expect(exception.errorCode, ErrorCode.paymentDeclined);
      expect((exception as PaymentException).gatewayCode, 'refused');
      expect(exception.transactionId, 'txn_789');
    });

    test('mapExceptionToFailure maps correctly', () {
      expect(
        ErrorHandler.mapExceptionToFailure(NetworkException.timeout()),
        isA<NetworkFailure>(),
      );
      expect(
        ErrorHandler.mapExceptionToFailure(AuthException.unauthorized()),
        isA<AuthFailure>(),
      );
      expect(
        ErrorHandler.mapExceptionToFailure(PaymentException.declined()),
        isA<PaymentFailure>(),
      );
      expect(
        ErrorHandler.mapExceptionToFailure(const ValidationException()),
        isA<ValidationFailure>(),
      );
      expect(
        ErrorHandler.mapExceptionToFailure(
          LocationException.permissionDenied(),
        ),
        isA<LocationFailure>(),
      );
    });

    test('handleException handles AppException', () {
      final failure = ErrorHandler.handleException(NetworkException.timeout());

      expect(failure, isA<NetworkFailure>());
      expect(failure.errorCode, ErrorCode.networkTimeout);
    });

    test('handleException handles DioException', () {
      final dioException = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(),
      );

      final failure = ErrorHandler.handleException(dioException);

      expect(failure, isA<NetworkFailure>());
      expect(failure.errorCode, ErrorCode.networkTimeout);
    });

    test('handleException handles unknown exception', () {
      final failure = ErrorHandler.handleException(Exception('Unknown'));

      expect(failure, isA<ServerFailure>());
      expect(failure.errorCode, ErrorCode.unknown);
    });
  });
}
