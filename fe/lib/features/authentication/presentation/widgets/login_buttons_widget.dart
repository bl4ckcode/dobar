import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:barz/features/authentication/presentation/bloc/login_bloc.dart';
import 'package:barz/features/authentication/presentation/bloc/login_event.dart';

class LoginButtonsWidget extends StatefulWidget {
  final LoginBloc loginBloc;

  const LoginButtonsWidget({super.key, required this.loginBloc});

  @override
  State<LoginButtonsWidget> createState() => _LoginButtonsWidgetState();
}

class _LoginButtonsWidgetState extends State<LoginButtonsWidget> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      debugPrint("Google User Token: ${googleAuth.accessToken}");

      widget.loginBloc.add(LoginEvent.googleLoginPressed(
        key: googleUser.email,
        token: googleAuth.accessToken!,
      ));
    } catch (e) {
      debugPrint("Error signing in with Google: $e");
    }
  }

  Future<void> _signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      debugPrint("Apple Identity Token: ${credential.identityToken}");

      widget.loginBloc.add(LoginEvent.googleLoginPressed(
        key: credential.email ?? 'apple_user',
        token: credential.identityToken!,
      ));
    } catch (e) {
      debugPrint("Error signing in with Apple: $e");
    }
  }

  Future<void> _signInWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login();
      if (result.status != LoginStatus.success) return;

      final userEmail =
          await FacebookAuth.instance.getUserData(fields: "email");
      final accessToken = result.accessToken!;
      debugPrint("Facebook User Token: ${accessToken.tokenString}");

      if (userEmail.containsKey("email")) {
        widget.loginBloc.add(LoginEvent.googleLoginPressed(
          key: userEmail['email'],
          token: accessToken.tokenString,
        ));
      }
    } catch (e) {
      debugPrint("Error signing in with Facebook: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (Platform.isAndroid)
          IconButton(
            padding: EdgeInsets.zero,
            onPressed: _signInWithGoogle,
            icon: Image.asset(
              "assets/icons/google.png",
              height: 64,
              width: 64,
              color: Colors.white,
            ),
          ),
        if (Platform.isIOS)
          IconButton(
            padding: EdgeInsets.zero,
            onPressed: _signInWithApple,
            icon: Image.asset(
              "assets/icons/apple.png",
              height: 64,
              width: 64,
              color: Colors.white,
            ),
          ),
        IconButton(
          padding: const EdgeInsets.only(left: 32),
          onPressed: _signInWithFacebook,
          icon: Image.asset(
            "assets/icons/facebook.png",
            height: 64,
            width: 64,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
