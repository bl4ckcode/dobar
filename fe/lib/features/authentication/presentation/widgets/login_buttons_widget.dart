import 'dart:async';
import 'package:barz/core/design/design_system.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:barz/features/authentication/presentation/bloc/login_bloc.dart';
import 'package:barz/features/authentication/presentation/bloc/login_event.dart';

// Conditional import for Platform
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
    _authSubscription = signIn.authenticationEvents.listen((event) async {
      switch (event) {
        case GoogleSignInAuthenticationEventSignIn():
          await _handleGoogleSignInSuccess(event.user);
        case GoogleSignInAuthenticationEventSignOut():
          // User signed out
          break;
      }
    });

    // Initialize (no clientId needed for mobile platforms)
    try {
      await signIn.initialize();
      // Try lightweight auth first
      await signIn.attemptLightweightAuthentication();
    } catch (e) {
      debugPrint("Error initializing Google Sign-In: $e");
    }
  }

  Future<void> _handleGoogleSignInSuccess(GoogleSignInAccount user) async {
    try {
      // Get authorization for basic scopes
      final authorization = await user.authorizationClient.authorizationForScopes([
        'email',
        'profile',
      ]);
      
      if (authorization != null) {
        debugPrint("Google User Token: ${authorization.accessToken}");
        widget.loginBloc.add(LoginEvent.googleLoginPressed(
          key: user.email,
          token: authorization.accessToken,
        ));
      }
    } catch (e) {
      debugPrint("Error getting Google auth: $e");
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
