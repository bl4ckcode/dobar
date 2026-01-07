import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_request.freezed.dart';
part 'onboarding_request.g.dart';

/// Request to complete user onboarding
@freezed
abstract class OnboardingRequest with _$OnboardingRequest {
  const factory OnboardingRequest({
    /// User type: "client" or "business"
    @JsonKey(name: 'user_type') required String userType,
    
    /// ISO 3166-1 alpha-2 country code (BR, AR, US, MX, CL, CO, PE)
    @JsonKey(name: 'country_code') required String countryCode,
  }) = _OnboardingRequest;

  factory OnboardingRequest.fromJson(Map<String, dynamic> json) =>
      _$OnboardingRequestFromJson(json);
}
