import 'dart:convert';
import 'dart:typed_data';
import 'package:barz/features/cart/data/data_sources/cart_network_datasource.dart';
import 'package:barz/features/payments/data/data_sources/payment_network_datasource.dart';
import 'package:barz/features/payments/data/services/pagarme_card_tokenizer.dart';
import 'package:barz/features/payments/domain/models/payment_method.dart';
import 'package:barz/features/payments/domain/models/payment_model.dart';
import 'package:barz/features/payments/domain/models/transaction.dart';
import 'package:barz/features/payments/domain/services/card_tokenizer.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class ScriptedAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) handle;
  ScriptedAdapter(this.handle);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handle(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object? value) => ResponseBody.fromString(
  jsonEncode(value),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  test(
    'checkout retries reuse one key and defer payment until the single charge step',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = ScriptedAdapter((request) async {
          requests.add(request);
          if (requests.length == 1) {
            throw DioException(
              requestOptions: request,
              type: DioExceptionType.receiveTimeout,
            );
          }
          return jsonResponse({
            'order_id': 42,
            'bar_id': 7,
            'total': 12.5,
            'payment_status': 'pending',
          });
        });
      final datasource = CartNetworkDataSource(dio: dio);
      await expectLater(
        datasource.checkout(orderType: 'dine_in', paymentMethod: 'pix'),
        throwsException,
      );
      final order = await datasource.checkout(
        orderType: 'dine_in',
        paymentMethod: 'pix',
      );
      final sameOrder = await datasource.checkout(
        orderType: 'dine_in',
        paymentMethod: 'pix',
      );
      expect(order.orderId, 42);
      expect(sameOrder.orderId, 42);
      expect(requests, hasLength(2));
      expect(requests[0].data['defer_payment'], isTrue);
      expect(
        requests[0].headers['X-Idempotency-Key'],
        requests[1].headers['X-Idempotency-Key'],
      );
    },
  );

  test(
    'pending checkout restores venue, items and backend payment attempt key',
    () async {
      final dio = Dio()
        ..httpClientAdapter = ScriptedAdapter(
          (request) async => jsonResponse({
            'order_id': 42,
            'bar_id': 7,
            'total': 12.5,
            'payment_attempt_key': 'attempt-1',
            'items': [
              {
                'menu_item_id': 3,
                'menu_item_name': 'Suco',
                'quantity': 1,
                'unit_price': 12.5,
              },
            ],
          }),
        );
      final result = await CartNetworkDataSource(dio: dio).getPendingCheckout();
      expect(result!.barId, 7);
      expect(result.paymentAttemptKey, 'attempt-1');
      expect(result.items.single.menuItemName, 'Suco');
    },
  );

  test(
    'card request uses card wire type and provider response retains opaque payment id',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = ScriptedAdapter((request) async {
          requests.add(request);
          return jsonResponse({
            'payment_id': 'pay_opaque-123',
            'status': 'succeeded',
            'amount': 12.5,
            'created_at': '2026-11-03T12:00:00Z',
          });
        });
      final datasource = PaymentNetworkDatasource(dio: dio);
      final request = PaymentRequest(
        orderId: 42,
        barId: 7,
        amount: 12.5,
        paymentType: PaymentType.credit,
        paymentMethodId: 9,
        idempotencyKey: 'stable-attempt',
      );
      final result = await datasource.processPayment(request);
      expect(
        requests.single.data['payment_method'],
        containsPair('type', 'card'),
      );
      expect(requests.single.headers['X-Idempotency-Key'], 'stable-attempt');
      expect(result.status, TransactionStatus.approved);
      expect(result.orderId, 42);
      expect(result.externalId, 'pay_opaque-123');
      await datasource.checkPaymentStatus('pay_opaque-123');
      expect(requests.last.path, endsWith('/payments/v2/pay_opaque-123'));
    },
  );

  test(
    'provider tokenization uses only public endpoint without app auth or raw-card forwarding',
    () async {
      RequestOptions? captured;
      final dio = Dio()
        ..httpClientAdapter = ScriptedAdapter((request) async {
          captured = request;
          return jsonResponse({'id': 'token_test_reference'});
        });
      final tokenizer = PagarmeCardTokenizer(
        dio: dio,
        publicKey: 'pk_test_public',
      );
      final token = await tokenizer.tokenize(
        number: '4111 1111 1111 1111',
        holderName: 'TEST USER',
        expMonth: 12,
        expYear: 2099,
        cvv: '123',
      );
      expect(token, 'token_test_reference');
      expect(captured!.uri.host, 'api.pagar.me');
      expect(captured!.queryParameters, {'appId': 'pk_test_public'});
      expect(
        captured!.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(captured!.data['card']['number'], '4111111111111111');
    },
  );

  test('missing public key fails locally without a request', () async {
    final tokenizer = PagarmeCardTokenizer(publicKey: '');
    await expectLater(
      tokenizer.tokenize(
        number: '4111111111111111',
        holderName: 'TEST',
        expMonth: 12,
        expYear: 2099,
        cvv: '123',
      ),
      throwsA(
        isA<CardTokenizationException>().having(
          (error) => error.unavailable,
          'unavailable',
          true,
        ),
      ),
    );
  });

  test('failed Pix charge never becomes a QR success response', () async {
    final dio = Dio()
      ..httpClientAdapter = ScriptedAdapter(
        (request) async =>
            jsonResponse({'payment_id': 'pay_failed', 'status': 'failed'}),
      );
    await expectLater(
      PaymentNetworkDatasource(dio: dio).initiatePixPayment(
        PaymentRequest(
          orderId: 42,
          barId: 7,
          amount: 12.5,
          paymentType: PaymentType.pix,
        ),
      ),
      throwsException,
    );
  });
}
