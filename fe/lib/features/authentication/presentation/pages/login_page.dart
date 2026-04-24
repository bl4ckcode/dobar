import 'dart:ui';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/services/biometry_service.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/authentication/presentation/widgets/login_buttons_widget.dart';
import 'package:barz/features/authentication/presentation/widgets/login_fields_widget.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';
import 'package:barz/shared/presentation/loading_util.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/features/authentication/presentation/bloc/login_bloc.dart';
import 'package:barz/features/authentication/presentation/bloc/login_event.dart';
import 'package:barz/features/authentication/presentation/bloc/login_state.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'login_sms_validation_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late LoginBloc _loginBloc;
  String? _phoneNumber;
  final BiometryService _biometryService = getItInjector<BiometryService>();

  late final AnimationController _glowController;
  late final AnimationController _shimmerController;
  late final Animation<double> _glowAnim;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _loginBloc = LoginBloc(
      loginUseCase: getItInjector<LoginUsecase>(),
      firebaseAuth: getItInjector<FirebaseAuth>(),
      userRepository: getItInjector<UserRepository>(),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.3, end: 0.65).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _loginBloc.close();
    _glowController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_phoneNumber != null) {
      _loginBloc.add(LoginEvent.loginButtonPressed(phoneNumber: _phoneNumber!));
    }
  }

  Future<void> _promptBiometryThenNavigate(BuildContext context) async {
    final available = await _biometryService.isAvailable;
    if (available &&
        !_biometryService.isEnabled &&
        !_biometryService.isDeclined) {
      if (!context.mounted) return;
      final wantBiometry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable Biometric Login'),
          content: const Text(
            'Would you like to use Face ID or fingerprint for faster login next time?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Enable'),
            ),
          ],
        ),
      );

      if (wantBiometry == true) {
        final authenticated = await _biometryService.authenticate(
          'Confirm your identity to enable biometric login',
        );
        if (authenticated) {
          await _biometryService.enable();
        }
      } else {
        await _biometryService.decline();
      }
    }

    if (context.mounted) {
      AppRoute.home.go(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: Colors.white,
      body: PopScope(
        onPopInvokedWithResult: (left, right) {},
        child: BlocListener<LoginBloc, LoginState>(
          bloc: _loginBloc,
          listener: (context, state) {
            if (state is Loading) {
              LoadingUtil.showLoadingDialog(context);
            } else if (state is Success) {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }

              if (state.needsOnboarding) {
                AppRoute.goOnboarding(context, phone: state.phoneNumber);
                return;
              }

              if (state.isProfileComplete) {
                _promptBiometryThenNavigate(context);
              } else {
                AppRoute.goCompleteRegistration(
                  context,
                  email: state.email,
                  name: state.displayName,
                );
              }
            } else if (state is CodeSent) {
              Navigator.of(context).pop();

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LoginValidatePhoneNumberPage(
                    verificationId: state.verificationId,
                    phoneNumber: state.phoneNumber,
                    loginBloc: _loginBloc,
                  ),
                ),
              );
            } else if (state is Failure) {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.error)));
            }
          },
          child: ResponsiveCenterContainer(
            backgroundColor: Colors.white,
            child: Stack(
              children: [
                const _AtmosphericBackground(),
                _GhostCocktail(isDark: isDark),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 20,
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 10),
                                  _LogoArea(
                                    glowAnim: _glowAnim,
                                    shimmerAnim: _shimmerAnim,
                                    isDark: isDark,
                                  ).animate().fadeIn(duration: 600.ms).scale(
                                        begin: const Offset(0.9, 0.9),
                                        curve: Curves.easeOutBack,
                                      ),
                                  const SizedBox(height: 20),
                                  Text(
                                        'Your night. Your bar.',
                                        style: GoogleFonts.oswald(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                          letterSpacing: 4.0,
                                          color: Colors.black.withOpacity(0.8),
                                        ),
                                      )
                                      .animate()
                                      .fadeIn(delay: 200.ms, duration: 600.ms)
                                      .slideY(begin: 0.3, end: 0),
                                  const SizedBox(height: 32),
                                  _PhoneCard(
                                    colors: colors,
                                    isDark: isDark,
                                    onLoginPressed: (phone) =>
                                        setState(() => _phoneNumber = phone),
                                  )
                                      .animate()
                                      .fadeIn(delay: 400.ms, duration: 600.ms)
                                      .slideY(begin: 0.2, end: 0),
                                  const SizedBox(height: 16),
                                  _GoldCTAButton(
                                    enabled: _phoneNumber != null,
                                    onPressed: _handleLogin,
                                  )
                                      .animate()
                                      .fadeIn(delay: 500.ms, duration: 600.ms)
                                      .slideY(begin: 0.2, end: 0),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: () =>
                                        AppRoute.recoveryInitiate.push(context),
                                    child: Text(
                                      'Trouble logging in?',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.black26,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _OrDivider(colors: colors),
                                  const SizedBox(height: 20),
                                  LoginButtonsWidget(loginBloc: _loginBloc)
                                      .animate()
                                      .fadeIn(delay: 700.ms, duration: 600.ms)
                                      .slideY(begin: 0.2, end: 0),
                                  const SizedBox(height: 16),
                                  _LegalText(colors: colors),
                                  const Spacer(),
                                  const SizedBox(height: 140),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AtmosphericBackground extends StatelessWidget {
  const _AtmosphericBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 0.8,
            colors: [
              barzGold.withOpacity(0.12),
              Colors.white.withOpacity(0),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

class _GhostCocktail extends StatelessWidget {
  final bool isDark;
  const _GhostCocktail({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Opacity(
          opacity: 0.12,
          child: Image.asset(
            'assets/icons/cocktail-ghost.png',
            width: 320,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _LogoArea extends StatelessWidget {
  final Animation<double> glowAnim;
  final Animation<double> shimmerAnim;
  final bool isDark;

  const _LogoArea({
    required this.glowAnim,
    required this.shimmerAnim,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      width: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: glowAnim,
            builder: (_, child) => Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    barzGold.withOpacity(glowAnim.value * 0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.8],
                ),
              ),
            ),
          ),
          Hero(
            tag: 'logo',
            child: Image.asset(
              'assets/icons/dobar-logo-animated-transparent.gif',
              height: 110,
              width: 110,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneCard extends StatelessWidget {
  final DobarColors colors;
  final bool isDark;
  final void Function(String?) onLoginPressed;

  const _PhoneCard({
    required this.colors,
    required this.isDark,
    required this.onLoginPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PHONE NUMBER',
                style: GoogleFonts.oswald(
                  fontSize: 11,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              LoginFieldsWidget(onLoginPressed: onLoginPressed),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoldCTAButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _GoldCTAButton({required this.enabled, required this.onPressed});

  @override
  State<_GoldCTAButton> createState() => _GoldCTAButtonState();
}

class _GoldCTAButtonState extends State<_GoldCTAButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered && widget.enabled ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onPressed : null,
          child: AnimatedOpacity(
            opacity: widget.enabled ? 1.0 : 0.5,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [barzGoldGradientStart, barzGoldGradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: barzGold.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'CONTINUE',
                    style: GoogleFonts.oswald(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.0,
                      color: barzDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(LucideIcons.arrowRight, color: barzDark, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  final DobarColors colors;
  const _OrDivider({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: Colors.black.withOpacity(0.08)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR CONTINUE WITH',
            style: GoogleFonts.oswald(
              fontSize: 10,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w400,
              color: Colors.black38,
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: Colors.black.withOpacity(0.08)),
        ),
      ],
    );
  }
}

class _LegalText extends StatelessWidget {
  final DobarColors colors;
  const _LegalText({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          text: 'By continuing, you agree to our ',
          style: TextStyle(
            color: Colors.black45,
            fontSize: 11,
            height: 1.5,
          ),
          children: <TextSpan>[
            TextSpan(
              text: 'Terms of Service',
              style: TextStyle(
                color: barzGoldDark,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()..onTap = () {},
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                color: barzGoldDark,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()..onTap = () {},
            ),
          ],
        ),
      ),
    );
  }
}
