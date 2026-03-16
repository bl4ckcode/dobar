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

import 'login_sms_validation_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
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
      backgroundColor: colors.background,
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
            backgroundColor: colors.background,
            child: Stack(
              children: [
                _NoiseOverlay(isDark: isDark),
                _GhostCocktail(isDark: isDark),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 0,
                              ),
                              child: Column(
                                children: [
                                  _LogoArea(
                                    glowAnim: _glowAnim,
                                    shimmerAnim: _shimmerAnim,
                                    isDark: isDark,
                                  ),
                                  Text(
                                    'Your night. Your bar.',
                                    style: GoogleFonts.oswald(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 3.0,
                                      color: colors.labelPrimary
                                          .withValues(alpha: 0.8),
                                    ),
                                  )
                                      .animate()
                                      .fadeIn(
                                        delay: 600.ms,
                                        duration: 700.ms,
                                        curve: Curves.easeOut,
                                      )
                                      .slideY(
                                        begin: 0.4,
                                        end: 0,
                                        delay: 600.ms,
                                        duration: 700.ms,
                                        curve: Curves.easeOut,
                                      ),
                                  const SizedBox(height: 28),
                                  _PhoneCard(
                                    colors: colors,
                                    isDark: isDark,
                                    onLoginPressed: (phone) =>
                                        setState(() => _phoneNumber = phone),
                                  ),
                                  const SizedBox(height: 16),
                                  _GoldCTAButton(
                                    enabled: _phoneNumber != null,
                                    onPressed: _handleLogin,
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: () =>
                                        AppRoute.recoveryInitiate.push(context),
                                    child: Text(
                                      'Trouble logging in?',
                                      style: TextStyle(
                                        color: colors.labelSecondary,
                                        fontSize: 13,
                                        decoration: TextDecoration.underline,
                                        decorationColor:
                                            colors.labelSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _OrDivider(colors: colors),
                                  const SizedBox(height: 12),
                                  LoginButtonsWidget(loginBloc: _loginBloc),
                                  const SizedBox(height: 8),
                                  _LegalText(colors: colors),
                                  const Spacer(),
                                  const SizedBox(height: 16),
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

class _NoiseOverlay extends StatelessWidget {
  final bool isDark;
  const _NoiseOverlay({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Opacity(
        opacity: isDark ? 0.06 : 0.03,
        child: Image.asset(
          'assets/icons/noise-texture.png',
          repeat: ImageRepeat.repeat,
          errorBuilder: (_, e, s) => const SizedBox.shrink(),
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
        child: FractionalTranslation(
          translation: const Offset(0, 0.15),
          child: Opacity(
            opacity: isDark ? 0.10 : 0.15,
            child: Image.asset(
              'assets/icons/cocktail-ghost.png',
              width: 320,
              fit: BoxFit.contain,
            ),
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
      height: MediaQuery.of(context).size.height * 0.32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: glowAnim,
            builder: (_, child) => Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    barzGold.withValues(
                      alpha: glowAnim.value * (isDark ? 0.35 : 0.2),
                    ),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: shimmerAnim,
            builder: (_, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(
                        -1.0 + shimmerAnim.value * 2,
                        -0.5,
                      ),
                      end: Alignment(
                        shimmerAnim.value * 2,
                        0.5,
                      ),
                      colors: [
                        Colors.transparent,
                        barzGold.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.3, 0.5, 0.7],
                    ),
                  ),
                ),
              );
            },
          ),
          Image.asset(
            'assets/icons/dobar-logo.png',
            width: 176,
            height: 176,
            fit: BoxFit.contain,
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
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: isDark ? 0.6 : 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.surfaceElevated.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PHONE NUMBER',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                  color: colors.labelSecondary,
                ),
              ),
              const SizedBox(height: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [barzGoldGradientStart, barzGoldGradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: barzGold.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Continue',
                    style: GoogleFonts.oswald(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                      color: barzDark,
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: barzDark, size: 20),
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
          child: Divider(
            color: colors.labelSecondary.withValues(alpha: 0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR CONTINUE WITH',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w500,
              color: colors.labelSecondary,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: colors.labelSecondary.withValues(alpha: 0.3),
          ),
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
            color: colors.labelSecondary,
            fontSize: 11,
            height: 1.5,
          ),
          children: <TextSpan>[
            TextSpan(
              text: 'Terms of Service',
              style: TextStyle(
                color: colors.labelSelected,
                decoration: TextDecoration.underline,
                decorationColor: colors.labelSelected.withValues(alpha: 0.5),
              ),
              recognizer: TapGestureRecognizer()..onTap = () {},
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                color: colors.labelSelected,
                decoration: TextDecoration.underline,
                decorationColor: colors.labelSelected.withValues(alpha: 0.5),
              ),
              recognizer: TapGestureRecognizer()..onTap = () {},
            ),
          ],
        ),
      ),
    );
  }
}
