import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/onboarding/domain/models/onboarding_request.dart';
import 'package:barz/features/onboarding/domain/models/payment_gateway.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:dartz/dartz.dart';

abstract class OnboardingRepository {
  /// Complete onboarding with user type and country
  Future<Either<Failure, UserModel>> completeOnboarding(
    OnboardingRequest request,
  );

  /// Get payment gateway for user's country
  Future<Either<Failure, PaymentGateway>> getPaymentGateway();
}
