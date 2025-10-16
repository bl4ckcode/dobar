import 'dart:async';
import 'package:dio/dio.dart';
import 'package:barz/core/network/api_response.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:barz/core/network/api_config.dart';
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
        '${baseUrl}auth/google',
        data: {
          "email": params.email,
          "google_id": params.googleId,
        },
        options: Options(headers: getHeaders()),
      );

      if (response.statusCode == 200) {
        return ApiResponse.success(response.data['access_token']);
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
        '${baseUrl}auth/apple',
        data: {
          "email": params.email,
          "apple_id": params.appleId,
        },
        options: Options(headers: getHeaders()),
      );

      if (response.statusCode == 200) {
        return ApiResponse.success(response.data['access_token']);
      } else {
        throw ServerException('Failed to login: ${response.statusCode}', null);
      }
    } on DioException catch (e) {
      throw ServerException(
          e.message ?? 'Dio error occurred', e.response?.statusCode);
    }
  }

  // Facebook Sign-In Authentication
  Future<ApiResponse<String?>> loginWithFacebook(LoginParams params) async {
    try {
      // Call back-end API to complete the login process
      final response = await dio.post(
        '${baseUrl}auth/facebook',
        data: {
          "email": params.email,
          "facebook_id": params.facebookId,
        },
        options: Options(headers: getHeaders()),
      );

      if (response.statusCode == 200) {
        return ApiResponse.success(response.data['access_token']);
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
      await completeLoginWithBackend(userCredential.user);

      // Return the Firebase UID
      return ApiResponse.success(userCredential.user?.uid);
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
    // Set token globally
    setAuthToken(idToken ?? "");
    // Call the backend login route using shared headers
    final response = await dio.post(
      '${baseUrl}auth/phone',
      options: Options(
        headers: getHeaders(),
      ),
    );
    // Extract token from response and return
    final token = response.data['access_token'] as String;
    return ApiResponse.success(token);
  }
}
