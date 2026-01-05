import 'dart:async';
import 'package:barz/core/network/auth_response.dart';
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

  Future<ApiResponse<AuthResponse>> loginWithGoogle(LoginParams params) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.authGoogle}',
        data: {
          'id_token': params.idToken,
          if (params.email != null) 'email': params.email,
          if (params.tokenExpiration != null) 'token_expiration': params.tokenExpiration,
        },
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(response.data);
        DioNetwork.setTokens(authResponse.accessToken, authResponse.refreshToken);
        return ApiResponse.success(authResponse);
      }
      throw ServerException('Failed to login: ${response.statusCode}', null);
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'Login failed', e.response?.statusCode);
    }
  }

  Future<ApiResponse<AuthResponse>> loginWithApple(LoginParams params) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.authApple}',
        data: {
          'id_token': params.idToken,
          if (params.email != null) 'email': params.email,
          if (params.tokenExpiration != null) 'token_expiration': params.tokenExpiration,
        },
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(response.data);
        DioNetwork.setTokens(authResponse.accessToken, authResponse.refreshToken);
        return ApiResponse.success(authResponse);
      }
      throw ServerException('Failed to login: ${response.statusCode}', null);
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'Login failed', e.response?.statusCode);
    }
  }

  Future<ApiResponse<AuthResponse>> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      return await completeLoginWithBackend(userCredential.user);
    } on FirebaseAuthException catch (e) {
      throw ServerException(e.message ?? 'Firebase verification failed', null);
    } catch (e) {
      throw ServerException(e.toString(), null);
    }
  }

  Future<ApiResponse<AuthResponse>> completeLoginWithBackend(User? user) async {
    if (user == null) throw ServerException('No user', null);
    
    final idToken = await user.getIdToken();
    if (idToken == null) throw ServerException('No ID token', null);
    
    final response = await dio.post(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.authPhone}',
      options: Options(headers: {'Authorization': 'Bearer $idToken'}),
    );
    
    final authResponse = AuthResponse.fromJson(response.data);
    DioNetwork.setTokens(authResponse.accessToken, authResponse.refreshToken);
    return ApiResponse.success(authResponse);
  }

  Future<void> logout() async {
    try {
      final refreshToken = DioNetwork.refreshToken;
      if (refreshToken != null) {
        await dio.post(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.authLogout}',
          data: {'refresh_token': refreshToken},
        );
      }
    } catch (_) {}
    await DioNetwork.clearTokens();
    await _firebaseAuth.signOut();
  }
}
