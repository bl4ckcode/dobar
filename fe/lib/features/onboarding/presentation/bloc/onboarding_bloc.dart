import 'package:barz/core/utils/country_helper.dart';
import 'package:barz/features/onboarding/domain/models/onboarding_request.dart';
import 'package:barz/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:barz/features/onboarding/presentation/bloc/onboarding_event.dart';
import 'package:barz/features/onboarding/presentation/bloc/onboarding_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final OnboardingRepository _repository;

  OnboardingBloc({required OnboardingRepository repository})
      : _repository = repository,
        super(const OnboardingState()) {
    on<SelectUserType>(_onSelectUserType);
    on<SelectCountry>(_onSelectCountry);
    on<DetectCountryFromPhone>(_onDetectCountryFromPhone);
    on<SubmitOnboarding>(_onSubmitOnboarding);
    on<LoadPaymentGateway>(_onLoadPaymentGateway);
  }

  void _onSelectUserType(SelectUserType event, Emitter<OnboardingState> emit) {
    emit(state.copyWith(
      selectedUserType: event.userType,
      error: null,
    ));
  }

  void _onSelectCountry(SelectCountry event, Emitter<OnboardingState> emit) {
    emit(state.copyWith(
      selectedCountryCode: event.countryCode,
      error: null,
    ));
  }

  void _onDetectCountryFromPhone(
    DetectCountryFromPhone event,
    Emitter<OnboardingState> emit,
  ) {
    final countryCode = CountryHelper.detectCountryFromPhone(event.phoneNumber);
    emit(state.copyWith(
      phoneNumber: event.phoneNumber,
      selectedCountryCode: countryCode,
      error: null,
    ));
  }

  Future<void> _onSubmitOnboarding(
    SubmitOnboarding event,
    Emitter<OnboardingState> emit,
  ) async {
    if (!state.canSubmit) return;

    emit(state.copyWith(isSubmitting: true, error: null));

    final request = OnboardingRequest(
      userType: state.selectedUserType!,
      countryCode: state.selectedCountryCode!,
    );

    final result = await _repository.completeOnboarding(request);

    result.fold(
      (failure) => emit(state.copyWith(
        isSubmitting: false,
        error: failure.errorMessage,
      )),
      (user) => emit(state.copyWith(
        isSubmitting: false,
        isComplete: true,
      )),
    );
  }

  Future<void> _onLoadPaymentGateway(
    LoadPaymentGateway event,
    Emitter<OnboardingState> emit,
  ) async {
    final result = await _repository.getPaymentGateway();

    result.fold(
      (failure) => emit(state.copyWith(error: failure.errorMessage)),
      (gateway) => emit(state.copyWith(paymentGateway: gateway)),
    );
  }
}
