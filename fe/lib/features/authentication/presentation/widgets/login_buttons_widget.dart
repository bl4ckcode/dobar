import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
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
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        if (kDebugMode) {
          print("Google User Token: ${googleAuth.accessToken}");
        }
        widget.loginBloc.add(LoginEvent.googleLoginPressed(
          key: googleUser.email,
          token: googleAuth.accessToken!,
        ));
      }
    } catch (error) {
      if (kDebugMode) {
        print("Error signing in with Google: $error");
      }
    }
  }

 // Future<void> _signInWithApple() async {
    // try {
    //   final credential = await SignInWithApple.getAppleIDCredential(
    //     scopes: [
    //       AppleIDAuthorizationScopes.email,
    //       AppleIDAuthorizationScopes.fullName,
    //     ],
    //   );
    //   if (kDebugMode) {
    //     print("Apple User Identity Token: ${credential.identityToken}");
    //   }
    //   widget.loginBloc.add(LoginEvent.googleLoginPressed(token: credential.identityToken!));
    // } catch (error) {
    //   if (kDebugMode) {
    //     print("Error signing in with Apple: $error");
    //   }
    // }
  // }

  Future<void> _signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final Map<String, dynamic> userEmail = await FacebookAuth.instance.getUserData(fields: "email");
        final AccessToken accessToken = result.accessToken!;

        if (kDebugMode) {
          print("Facebook User Token: ${accessToken.tokenString}");
        }

        if (userEmail.containsKey("email")) {
          widget.loginBloc
              .add(LoginEvent.googleLoginPressed(
              key: userEmail['email'], token: accessToken.tokenString));
        }
      }
    } catch (error) {
      if (kDebugMode) {
        print("Error signing in with Facebook: $error");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              padding: const EdgeInsets.only(right: 32),
              onPressed: () {
                // Add your email authentication logic here
              },
              icon: Image.asset(
                "assets/icons/email.png",
                height: 64,
                width: 64,
                color: Colors.white,
              ),
            ),
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
            // TODO: ENABLE APPLE SIGN-IN
            // IconButton(
            //   padding: const EdgeInsets.only(left: 32),
            //   onPressed: _signInWithApple,
            //   icon: Image.asset(
            //     "assets/icons/apple.png",
            //     height: 64,
            //     width: 64,
            //     color: Colors.white,
            //   ),
            // ),
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
        ),
      ],
    );
  }
}
