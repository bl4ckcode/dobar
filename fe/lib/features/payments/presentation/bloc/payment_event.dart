import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:barz/features/payments/domain/models/payment_method.dart';
import 'package:barz/features/payments/domain/models/payment_model.dart';

part 'payment_event.freezed.dart';

@freezed
class PaymentEvent with _$PaymentEvent {
  const factory PaymentEvent.loadPaymentMethods() = LoadPaymentMethods;
  const factory PaymentEvent.addPaymentMethod(PaymentMethod method, {String? cardToken}) = AddPaymentMethod;
  const factory PaymentEvent.setDefaultPaymentMethod(int methodId) = SetDefaultPaymentMethod;
  const factory PaymentEvent.removePaymentMethod(int methodId) = RemovePaymentMethod;
  const factory PaymentEvent.processPayment(PaymentRequest request) = ProcessPayment;
  const factory PaymentEvent.initiatePixPayment(PaymentRequest request) = InitiatePixPayment;
  const factory PaymentEvent.checkPaymentStatus(int transactionId) = CheckPaymentStatus;
  const factory PaymentEvent.loadTransactionHistory({int? limit, int? offset}) = LoadTransactionHistory;
  const factory PaymentEvent.refundTransaction(int transactionId, {double? amount}) = RefundTransaction;
  const factory PaymentEvent.topUpWallet(double amount, PaymentType paymentType, {int? paymentMethodId}) = TopUpWallet;
  const factory PaymentEvent.clearPixPayment() = ClearPixPayment;
  const factory PaymentEvent.clearError() = ClearPaymentError;
}
