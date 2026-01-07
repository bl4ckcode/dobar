import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/onboarding/domain/models/onboarding_request.dart';
import 'package:barz/features/onboarding/domain/models/payment_gateway.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:dio/dio.dart';

abstract class OnboardingDatasource {
  /// Complete onboarding with user type and country
  Future<UserModel> completeOnboarding(OnboardingRequest request);
  
  /// Get payment gateway for user's country
  Future<PaymentGateway> getPaymentGateway();
}

class OnboardingNetworkDatasource implements OnboardingDatasource {
  final Dio dio;

  OnboardingNetworkDatasource({required this.dio});

  @override
  Future<UserModel> completeOnboarding(OnboardingRequest request) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.onboarding}',
        data: request.toJson(),
      );
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to complete onboarding',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<PaymentGateway> getPaymentGateway() async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.paymentGateway}',
      );
      return PaymentGateway.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get payment gateway',
        e.response?.statusCode,
      );
    }
  }
}
