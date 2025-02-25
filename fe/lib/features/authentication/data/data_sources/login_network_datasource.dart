import 'dart:async';

import 'package:barz/core/network/dio_network.dart';
import 'package:dio/dio.dart';
import 'package:barz/core/network/api_response.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:barz/core/network/api_config.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginNetworkDataSource {
  final Dio dio;
  final FirebaseAuth _firebaseAuth;

  LoginNetworkDataSource(
      {required this.dio, required FirebaseAuth firebaseAuth})
      : _firebaseAuth = firebaseAuth;

  Future<ApiResponse<String?>> login(LoginParams params) async {
    try {
      String? firebaseUid = params.firebaseUid;

      // If Firebase UID is not provided, perform Firebase phone authentication
      if (firebaseUid == null && params.phoneNumber != null) {
        final verificationId = await _loginWithPhone(params.phoneNumber!);
        firebaseUid = verificationId; // Use verificationId as a temporary UID
      }

      // Call back-end API to complete the login process
      final response = await DioNetwork.appAPI.post(
        '${baseUrl}login/', // Use the baseUrl from api_config.dart
        data: {
          'firebase_uid': firebaseUid,
          'phone_number': params.phoneNumber,
        },
        options:
            Options(headers: getHeaders()), // Use headers from api_config.dart
      );

      if (response.statusCode == 200) {
        return ApiResponse.success(response.data['token']);
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
