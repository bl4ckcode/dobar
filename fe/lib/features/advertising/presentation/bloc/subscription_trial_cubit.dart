import 'package:equatable/equatable.dart';
import 'package:barz/features/advertising/domain/models/models.dart';
import 'package:barz/features/advertising/domain/usecases/advertising_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SubscriptionTrialState extends Equatable {
  final bool isLoading;
  final SubscriptionTrialSetupResult? result;
  final String? error;
  final String? successMessage;

  const SubscriptionTrialState({
    this.isLoading = false,
    this.result,
    this.error,
    this.successMessage,
  });

  SubscriptionTrialState copyWith({
    bool? isLoading,
    SubscriptionTrialSetupResult? result,
    String? error,
    String? successMessage,
  }) {
    return SubscriptionTrialState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      error: error,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [isLoading, result, error, successMessage];
}

class SubscriptionTrialCubit extends Cubit<SubscriptionTrialState> {
  final AdvertisingUsecase _usecase;

  SubscriptionTrialCubit(this._usecase) : super(const SubscriptionTrialState());

  Future<void> setupTrial({
    required int barId,
    required int ownerId,
    required String plan,
    required String paymentMethodId,
    required String customerEmail,
    required String customerName,
  }) async {
    emit(state.copyWith(isLoading: true, error: null, successMessage: null));
    try {
      final result = await _usecase.setupSubscriptionTrial(
        barId: barId,
        ownerId: ownerId,
        plan: plan,
        paymentMethodId: paymentMethodId,
        customerEmail: customerEmail,
        customerName: customerName,
      );
      emit(
        state.copyWith(
          isLoading: false,
          result: result,
          successMessage: 'Trial started successfully',
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}
