import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_event.freezed.dart';

@freezed
sealed class OnboardingEvent with _$OnboardingEvent {
  /// Select user type (client or business)
  const factory OnboardingEvent.selectUserType(String userType) = SelectUserType;
  
  /// Select country
  const factory OnboardingEvent.selectCountry(String countryCode) = SelectCountry;
  
  /// Detect country from phone number
  const factory OnboardingEvent.detectCountryFromPhone(String phoneNumber) = DetectCountryFromPhone;
  
  /// Submit onboarding (user type + country)
  const factory OnboardingEvent.submitOnboarding() = SubmitOnboarding;
  
  /// Load payment gateway after onboarding
  const factory OnboardingEvent.loadPaymentGateway() = LoadPaymentGateway;
}
