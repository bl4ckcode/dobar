import 'dart:async';
import 'dart:convert';
import 'package:barz/core/design/design_system.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barz/features/authentication/presentation/bloc/login_bloc.dart';
import 'package:barz/features/authentication/presentation/bloc/login_event.dart';

import 'login_buttons_platform.dart'
    if (dart.library.io) 'login_buttons_platform_io.dart';

class LoginButtonsWidget extends StatefulWidget {
  final LoginBloc loginBloc;

  const LoginButtonsWidget({super.key, required this.loginBloc});

  @override
  State<LoginButtonsWidget> createState() => _LoginButtonsWidgetState();
}

class _LoginButtonsWidgetState extends State<LoginButtonsWidget> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initGoogleSignIn();
  }

  Future<void> _initGoogleSignIn() async {
    final signIn = GoogleSignIn.instance;
    
    // Listen to authentication events
    _authSubscription = signIn.authenticationEvents.listen(
      (event) async {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn():
            await _handleGoogleSignInSuccess(event.user);
          case GoogleSignInAuthenticationEventSignOut():
            // User signed out
            break;
        }
      },
      onError: (error) {
        // Handle errors gracefully - FedCM can timeout on web if user is idle
        debugPrint("Google Sign-In stream error (non-fatal): $error");
      },
    );

    // Initialize (no clientId needed for mobile platforms)
    try {
      await signIn.initialize();
      // Try lightweight auth first - this can fail on web with FedCM timeout
      // That's okay, user can still click the button to sign in
      await signIn.attemptLightweightAuthentication();
    } catch (e) {
      // This is expected on web when FedCM times out or user dismisses
      // Also happens when user hasn't signed in before
      debugPrint("Google Sign-In init (non-fatal): $e");
    }
  }

  Future<void> _handleGoogleSignInSuccess(GoogleSignInAccount user) async {
    try {
      final idToken = user.authentication.idToken;
      final authorization = await user.authorizationClient.authorizationForScopes([
        'email',
        'profile',
      ]);
      
      if (idToken != null) {
        final credential = GoogleAuthProvider.credential(
          accessToken: authorization?.accessToken,
          idToken: idToken,
        );
        
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        final firebaseIdToken = await userCredential.user?.getIdToken();
        
        if (firebaseIdToken != null) {
          final tokenExpiration = _extractExpFromJwt(idToken);
          debugPrint("Firebase ID Token: ${firebaseIdToken.substring(0, 50)}...");
          widget.loginBloc.add(LoginEvent.googleLoginPressed(
            key: user.email,
            token: firebaseIdToken,
            tokenExpiration: tokenExpiration,
          ));
        } else {
          debugPrint("Error: Could not get Firebase ID token");
        }
      } else {
        debugPrint("Error: Google authentication returned null idToken");
      }
    } catch (e) {
      debugPrint("Error getting Google auth: $e");
    }
  }

  int? _extractExpFromJwt(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return json['exp'] as int?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final signIn = GoogleSignIn.instance;
      if (signIn.supportsAuthenticate()) {
        await signIn.authenticate();
      }
    } catch (e) {
      debugPrint("Error signing in with Google: $e");
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      debugPrint("Apple Identity Token: ${appleCredential.identityToken?.substring(0, 50)}...");

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final firebaseIdToken = await userCredential.user?.getIdToken();

      if (firebaseIdToken != null) {
        final tokenExpiration = appleCredential.identityToken != null 
            ? _extractExpFromJwt(appleCredential.identityToken!) 
            : null;
        debugPrint("Firebase ID Token from Apple: ${firebaseIdToken.substring(0, 50)}...");
        widget.loginBloc.add(LoginEvent.appleLoginPressed(
          key: appleCredential.email ?? userCredential.user?.email ?? 'apple_user',
          token: firebaseIdToken,
          tokenExpiration: tokenExpiration,
        ));
      } else {
        debugPrint("Error: Could not get Firebase ID token from Apple sign-in");
      }
    } catch (e) {
      debugPrint("Error signing in with Apple: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // On web: show both Google and Apple
        // On Android: show Google only
        // On iOS: show Apple only
        if (kIsWeb || isAndroidPlatform())
          _buildSocialButton(
            onPressed: _signInWithGoogle,
            icon: 'assets/icons/google.png',
            label: 'Continue with Google',
          ),
        if (kIsWeb) const SizedBox(height: BarzSpacing.md),
        if (kIsWeb || isIOSPlatform())
          _buildSocialButton(
            onPressed: _signInWithApple,
            icon: 'assets/icons/apple.png',
            label: 'Continue with Apple',
          ),
      ],
    );
  }

  Widget _buildSocialButton({
    required VoidCallback onPressed,
    required String icon,
    required String label,
  }) {
    return SizedBox(
      width: double.infinity,
      height: TouchTargets.minimum,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            vertical: ButtonSpacing.paddingVertical,
            horizontal: ButtonSpacing.paddingHorizontal,
          ),
          side: const BorderSide(color: barzDark, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BarzRadii.md),
          ),
        ),
        icon: Image.asset(
          icon,
          height: 24,
          width: 24,
        ),
        label: Text(
          label,
          style: barzTextTheme.labelLarge?.copyWith(
            color: barzDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
