import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:barz/features/payments/domain/models/payment_method.dart';
import 'package:barz/features/payments/domain/models/transaction.dart';
import 'package:barz/features/payments/domain/models/payment_model.dart';

part 'payment_state.freezed.dart';

@freezed
abstract class PaymentState with _$PaymentState {
  const factory PaymentState({
    @Default([]) List<PaymentMethod> paymentMethods,
    @Default([]) List<Transaction> transactions,
    @Default(false) bool isLoading,
    @Default(false) bool isProcessing,
    String? error,
    Transaction? currentTransaction,
    PixPaymentResponse? pixPayment,
  }) = _PaymentState;
}
