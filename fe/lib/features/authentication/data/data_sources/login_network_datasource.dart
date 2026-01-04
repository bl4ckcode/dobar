import 'dart:async';
import 'package:barz/core/network/dio_network.dart';
import 'package:dio/dio.dart';
import 'package:barz/core/network/api_response.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:barz/core/api/api_endpoints.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginNetworkDataSource {
  final Dio dio;
  final FirebaseAuth _firebaseAuth;

  LoginNetworkDataSource({
    required this.dio,
    required FirebaseAuth firebaseAuth,
  }) : _firebaseAuth = firebaseAuth;

  // Google Sign-In Authentication
  Future<ApiResponse<String?>> loginWithGoogle(LoginParams params) async {
    try {
      // Call back-end API to complete the login process
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.authGoogle}',
        data: {
          "email": params.email,
          "google_id": params.googleId,
        },
      );

      if (response.statusCode == 200) {
        final token = response.data['access_token'] as String?;
        if (token != null) {
          DioNetwork.setAuthToken(token);
        }
        return ApiResponse.success(token);
      } else {
        throw ServerException('Failed to login: ${response.statusCode}', null);
      }
    } on DioException catch (e) {
      throw ServerException(
          e.message ?? 'Dio error occurred', e.response?.statusCode);
    }
  }

  // Apple Sign-In Authentication
  Future<ApiResponse<String?>> loginWithApple(LoginParams params) async {
    try {
      // Call back-end API to complete the login process
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.authApple}',
        data: {
          "email": params.email,
          "apple_id": params.appleId,
        },
      );

      if (response.statusCode == 200) {
        final token = response.data['access_token'] as String?;
        if (token != null) {
          DioNetwork.setAuthToken(token);
        }
        return ApiResponse.success(token);
      } else {
        throw ServerException('Failed to login: ${response.statusCode}', null);
      }
    } on DioException catch (e) {
      throw ServerException(
          e.message ?? 'Dio error occurred', e.response?.statusCode);
    }
  }

  // Verify SMS code for phone authentication
  Future<ApiResponse<String?>> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // Sign in with the credential
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      // Call back-end API to complete the login process
      final result = await completeLoginWithBackend(userCredential.user);

      // Return the backend token
      return ApiResponse.success(result.result);
    } on FirebaseAuthException catch (e) {
      throw ServerException(e.message ?? "Firebase verification failed", null);
    } catch (e) {
      throw ServerException(e.toString(), null);
    }
  }

  Future<ApiResponse<String>> completeLoginWithBackend(User? user) async {
    if (user == null) throw ServerException("No user", null);
    
    // Get Firebase ID token
    final idToken = await user.getIdToken();
    
    // Temporarily set Firebase token for the backend call
    if (idToken != null) {
      DioNetwork.setAuthToken(idToken);
    }
    
    // Call the backend login route
    final response = await dio.post(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.authPhone}',
    );
    
    // Extract backend token from response
    final token = response.data['access_token'] as String;
    
    // Set the backend token (this persists it)
    DioNetwork.setAuthToken(token);
    
    return ApiResponse.success(token);
  }
}
