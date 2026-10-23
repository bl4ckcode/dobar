import 'dart:convert';
import 'dart:io';

import 'package:barz/features/payments/domain/models/payment_method.dart';
import 'package:barz/features/payments/domain/models/payment_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture = jsonDecode(
    File('../tools/agent_workflow/fixtures/pix-checkout.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('Pix request serializes to the shared BE/DPE wire fixture', () {
    final expected = fixture['frontend_request'] as Map<String, dynamic>;
    final request = PaymentRequest(
      orderId: expected['order_id'] as int,
      barId: expected['bar_id'] as int,
      amount: (expected['amount'] as num).toDouble(),
      paymentType: PaymentType.pix,
    );

    expect(request.toJson(), expected);
    expect(request.toJson()['payment_method'], isNot(contains('card')));
  });

  test('Pix response preserves copy text, expiry, amount and payment identity', () {
    final json = fixture['backend_response'] as Map<String, dynamic>;
    final response = PixPaymentResponse.fromJson(json);

    expect(response.paymentId, json['payment_id']);
    expect(response.qrCode, json['pix_qr_code']);
    expect(response.copyPaste, json['pix_copia_e_cola']);
    expect(response.amount, json['amount']);
    expect(response.expiresAt, DateTime.parse(json['pix_expires_at'] as String));
  });
}
