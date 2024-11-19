import 'dart:async';

import 'package:barz/core/network/api_response.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/authentication/data/data_sources/abstract_login_api.dart';
import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginApi extends AbstractLoginApi {
  final FirebaseAuth _firebaseAuth;

  LoginApi(this._firebaseAuth);

  @override
  Future<ApiResponse<String?>> login(LoginParams params) async {
    try {
      // Create a completer to return the verificationId asynchronously
      final completer = Completer<ApiResponse<String?>>();

      // Start the phone number verification process using FirebaseAuth
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: params.phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // You can use this credential to sign in immediately or store it
          await _firebaseAuth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          completer.completeError(ServerException(e.message ?? "Unknown Firebase Error", null));
        },
        codeSent: (String verificationId, int? resendToken) {
          // Complete with success when the verification code is sent
          completer.complete(ApiResponse.success(verificationId)); // Verification ID for later verification
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Optionally handle timeouts
          completer.complete(ApiResponse.success(verificationId));
        },
      );

      // Wait for the completer to finish and return the result
      return completer.future;
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw ServerException(e.message ?? "Unknown Firebase Error", null);
      } else {
        throw ServerException(e.toString(), null);
      }
    }
  }
}
