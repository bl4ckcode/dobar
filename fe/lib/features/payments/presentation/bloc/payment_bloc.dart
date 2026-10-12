import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/payments/domain/models/payment_method.dart';
import 'package:barz/features/payments/domain/usecases/payment_usecase.dart';
import 'package:barz/features/payments/presentation/bloc/payment_event.dart';
import 'package:barz/features/payments/presentation/bloc/payment_state.dart';

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  final PaymentUsecase _usecase;

  PaymentBloc(this._usecase) : super(const PaymentState()) {
    on<LoadPaymentMethods>(_onLoadPaymentMethods);
    on<AddPaymentMethod>(_onAddPaymentMethod);
    on<SetDefaultPaymentMethod>(_onSetDefaultPaymentMethod);
    on<RemovePaymentMethod>(_onRemovePaymentMethod);
    on<ProcessPayment>(_onProcessPayment);
    on<InitiatePixPayment>(_onInitiatePixPayment);
    on<GenerateStandalonePix>(_onGenerateStandalonePix);
    on<CheckPaymentStatus>(_onCheckPaymentStatus);
    on<LoadTransactionHistory>(_onLoadTransactionHistory);
    on<RefundTransaction>(_onRefundTransaction);
    on<TopUpWallet>(_onTopUpWallet);
    on<ClearPixPayment>(_onClearPixPayment);
    on<ClearPaymentError>(_onClearError);
    on<LoadSavedCards>(_onLoadSavedCards);
    on<AddSavedCard>(_onAddSavedCard);
    on<DeleteSavedCard>(_onDeleteSavedCard);
  }

  Future<void> _onLoadPaymentMethods(
    LoadPaymentMethods event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await _usecase.getPaymentMethods();
    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.errorMessage)),
      (methods) =>
          emit(state.copyWith(isLoading: false, paymentMethods: methods)),
    );
  }

  Future<void> _onAddPaymentMethod(
    AddPaymentMethod event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true, error: null));
    final result = await _usecase.addPaymentMethod(
      event.method,
      cardToken: event.cardToken,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isProcessing: false, error: failure.errorMessage),
      ),
      (method) {
        final methods = [...state.paymentMethods, method];
        emit(state.copyWith(isProcessing: false, paymentMethods: methods));
      },
    );
  }

  Future<void> _onSetDefaultPaymentMethod(
    SetDefaultPaymentMethod event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true, error: null));
    final result = await _usecase.setDefaultPaymentMethod(event.methodId);
    result.fold(
      (failure) => emit(
        state.copyWith(isProcessing: false, error: failure.errorMessage),
      ),
      (method) {
        final methods = state.paymentMethods.map((m) {
          if (m.id == method.id) return method;
          if (m.isDefault) {
            return PaymentMethod(
              id: m.id,
              externalId: m.externalId,
              gateway: m.gateway,
              type: m.type,
              brand: m.brand,
              lastFourDigits: m.lastFourDigits,
              holderName: m.holderName,
              expiryMonth: m.expiryMonth,
              expiryYear: m.expiryYear,
              isDefault: false,
              createdAt: m.createdAt,
            );
          }
          return m;
        }).toList();
        emit(state.copyWith(isProcessing: false, paymentMethods: methods));
      },
    );
  }

  Future<void> _onRemovePaymentMethod(
    RemovePaymentMethod event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true, error: null));
    final result = await _usecase.removePaymentMethod(event.methodId);
    result.fold(
      (failure) => emit(
        state.copyWith(isProcessing: false, error: failure.errorMessage),
      ),
      (_) {
        final methods = state.paymentMethods
            .where((m) => m.id != event.methodId)
            .toList();
        emit(state.copyWith(isProcessing: false, paymentMethods: methods));
      },
    );
  }

  Future<void> _onProcessPayment(
    ProcessPayment event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true, error: null));
    final result = await _usecase.processPayment(event.request);
    result.fold(
      (failure) => emit(
        state.copyWith(isProcessing: false, error: failure.errorMessage),
      ),
      (transaction) => emit(
        state.copyWith(isProcessing: false, currentTransaction: transaction),
      ),
    );
  }

  Future<void> _onInitiatePixPayment(
    InitiatePixPayment event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true, error: null));
    final result = await _usecase.initiatePixPayment(event.request);
    result.fold(
      (failure) => emit(
        state.copyWith(isProcessing: false, error: failure.errorMessage),
      ),
      (pix) => emit(state.copyWith(isProcessing: false, pixPayment: pix)),
    );
  }

  Future<void> _onGenerateStandalonePix(
    GenerateStandalonePix event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true, error: null));
    final result = await _usecase.generateStandalonePix(
      barId: event.barId,
      amount: event.amount,
      description: event.description,
      payerName: event.payerName,
      payerDocument: event.payerDocument,
      expiresIn: event.expiresIn ?? 3600,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isProcessing: false, error: failure.errorMessage),
      ),
      (pix) => emit(state.copyWith(isProcessing: false, pixPayment: pix)),
    );
  }

  Future<void> _onCheckPaymentStatus(
    CheckPaymentStatus event,
    Emitter<PaymentState> emit,
  ) async {
    final result = await _usecase.checkPaymentStatus(event.transactionId);
    result.fold(
      (failure) => emit(state.copyWith(error: failure.errorMessage)),
      (transaction) => emit(state.copyWith(currentTransaction: transaction)),
    );
  }

  Future<void> _onLoadTransactionHistory(
    LoadTransactionHistory event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await _usecase.getTransactionHistory(
      limit: event.limit,
      offset: event.offset,
    );
    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.errorMessage)),
      (transactions) =>
          emit(state.copyWith(isLoading: false, transactions: transactions)),
    );
  }

  Future<void> _onRefundTransaction(
    RefundTransaction event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true, error: null));
    final result = await _usecase.refundTransaction(
      event.transactionId,
      amount: event.amount,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isProcessing: false, error: failure.errorMessage),
      ),
      (transaction) => emit(
        state.copyWith(isProcessing: false, currentTransaction: transaction),
      ),
    );
  }

  Future<void> _onTopUpWallet(
    TopUpWallet event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true, error: null));
    final result = await _usecase.topUpWallet(
      event.amount,
      event.paymentType,
      paymentMethodId: event.paymentMethodId,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isProcessing: false, error: failure.errorMessage),
      ),
      (transaction) => emit(
        state.copyWith(isProcessing: false, currentTransaction: transaction),
      ),
    );
  }

  void _onClearPixPayment(ClearPixPayment event, Emitter<PaymentState> emit) {
    emit(state.copyWith(pixPayment: null));
  }

  void _onClearError(ClearPaymentError event, Emitter<PaymentState> emit) {
    emit(state.copyWith(error: null));
  }

  Future<void> _onLoadSavedCards(
    LoadSavedCards event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await _usecase.getSavedCards();
    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.errorMessage)),
      (cards) => emit(state.copyWith(isLoading: false, savedCards: cards)),
    );
  }

  Future<void> _onAddSavedCard(
    AddSavedCard event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true, error: null));
    final result = await _usecase.addSavedCard(
      cardToken: event.cardToken,
      lastFour: event.lastFour,
      brand: event.brand,
      expMonth: event.expMonth,
      expYear: event.expYear,
      isDefault: event.isDefault,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isProcessing: false, error: failure.errorMessage),
      ),
      (card) => emit(
        state.copyWith(
          isProcessing: false,
          savedCards: [...state.savedCards, card],
        ),
      ),
    );
  }

  Future<void> _onDeleteSavedCard(
    DeleteSavedCard event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true, error: null));
    final result = await _usecase.deleteSavedCard(event.cardId);
    result.fold(
      (failure) => emit(
        state.copyWith(isProcessing: false, error: failure.errorMessage),
      ),
      (_) => emit(
        state.copyWith(
          isProcessing: false,
          savedCards: state.savedCards
              .where((c) => c.id != event.cardId)
              .toList(),
        ),
      ),
    );
  }
}
