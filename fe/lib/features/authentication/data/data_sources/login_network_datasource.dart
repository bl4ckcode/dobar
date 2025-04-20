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

  // Phone Number Authentication
  Future<ApiResponse<String?>> loginWithPhone(LoginParams params) async {
    try {
      // Perform Firebase phone authentication
      final verificationId = await _loginWithPhone(params.phoneNumber!);

      // Call back-end API to complete the login process
      final response = await dio.post(
        '${baseUrl}auth/phone',
        data: {
          "firebase_uid": verificationId,
          "phone_number": params.phoneNumber,
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
    } catch (e) {
      throw ServerException(e.toString(), null);
    }
  }

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
    } catch (e) {
      throw ServerException(e.toString(), null);
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
    } catch (e) {
      throw ServerException(e.toString(), null);
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
    } catch (e) {
      throw ServerException(e.toString(), null);
    }
  }

  // Helper function for Firebase phone authentication
  Future<String> _loginWithPhone(String phoneNumber) async {
    final completer = Completer<String>();

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Automatically sign in the user if verification completes
        await _firebaseAuth.signInWithCredential(credential);
        completer.complete(_firebaseAuth.currentUser?.uid); // Use Firebase UID
      },
      verificationFailed: (FirebaseAuthException e) {
        completer.completeError(
          ServerException(e.message ?? "Unknown Firebase Error", null),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        // Complete with the verificationId for later verification
        completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Handle timeout
        completer.completeError(
          ServerException("Code retrieval timed out: $verificationId", null),
        );
      },
    );

    return completer.future;
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

      // Return the Firebase UID
      return ApiResponse.success(userCredential.user?.uid);
    } on FirebaseAuthException catch (e) {
      throw ServerException(e.message ?? "Firebase verification failed", null);
    } catch (e) {
      throw ServerException(e.toString(), null);
    }
  }
}
