import 'package:barz/features/onboarding/domain/models/payment_gateway.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_state.freezed.dart';

@freezed
abstract class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    /// Selected user type: 'client' or 'business'
    String? selectedUserType,

    /// Selected country code (BR, AR, US, etc.)
    String? selectedCountryCode,

    /// Phone number used for country detection
    String? phoneNumber,

    /// Whether onboarding is being submitted
    @Default(false) bool isSubmitting,

    /// Whether onboarding was successful
    @Default(false) bool isComplete,

    /// Payment gateway info (loaded after onboarding)
    PaymentGateway? paymentGateway,

    /// Error message if any
    String? error,
  }) = _OnboardingState;

  const OnboardingState._();

  /// Check if we can submit onboarding
  bool get canSubmit =>
      selectedUserType != null && selectedCountryCode != null && !isSubmitting;

  /// Check if user selected client
  bool get isClient => selectedUserType == 'client';

  /// Check if user selected business
  bool get isBusiness => selectedUserType == 'business';
}
