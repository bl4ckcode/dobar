import 'package:barz/features/session/presentation/entry_coordinator.dart';
import 'package:barz/core/services/biometry_service.dart';
import 'dart:ui';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/authentication/presentation/widgets/login_buttons_widget.dart';
import 'package:barz/features/authentication/presentation/widgets/login_fields_widget.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/features/authentication/presentation/bloc/login_bloc.dart';
import 'package:barz/features/authentication/presentation/bloc/login_event.dart';
import 'package:barz/features/authentication/presentation/bloc/login_state.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:barz/core/theme/theme_cubit.dart';
import 'package:barz/core/router/route_arguments.dart';
import 'package:barz/features/authentication/presentation/navigation/post_login_destination.dart';
import 'package:barz/l10n/app_localizations.dart';

import 'login_sms_validation_page.dart';

class LoginPage extends StatefulWidget {
  final String? pendingInvitationCode;
  final String? preferredProvider;
  const LoginPage({
    super.key,
    this.pendingInvitationCode,
    this.preferredProvider,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late LoginBloc _loginBloc;
  String? _phoneNumber;
  bool _isLoading = false;
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

  Future<void> _promptBiometryThenNavigate(
    BuildContext context,
    Success state,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final available = await _biometryService.isAvailable;
    if (available &&
        !_biometryService.isEnabled &&
        !_biometryService.isDeclined) {
      if (!context.mounted) return;
      final wantBiometry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.login_biometry_title),
          content: Text(l10n.login_biometry_body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.login_biometry_later),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.login_biometry_enable),
            ),
          ],
        ),
      );

      if (wantBiometry == true) {
        final authenticated = await _biometryService.authenticate(
          l10n.login_biometry_reason,
        );
        if (authenticated) {
          await _biometryService.enable();
        }
      } else {
        await _biometryService.decline();
      }
    }

    if (context.mounted) {
      await navigateAfterLogin(context, state: state);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    final isDark = context.isDark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colors.background,
      body: PopScope(
        onPopInvokedWithResult: (left, right) {},
        child: BlocListener<LoginBloc, LoginState>(
          bloc: _loginBloc,
          listener: (context, state) {
            if (mounted) {
              setState(() => _isLoading = state is Loading);
            }
            if (state is Success) {
              if (widget.pendingInvitationCode != null) {
                navigateAfterLogin(
                  context,
                  state: state,
                  pendingInvitationCode: widget.pendingInvitationCode,
                );
              } else {
                _promptBiometryThenNavigate(context, state);
              }
            } else if (state is CodeSent) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LoginValidatePhoneNumberPage(
                    verificationId: state.verificationId,
                    phoneNumber: state.phoneNumber,
                    loginBloc: _loginBloc,
                    pendingInvitationCode: widget.pendingInvitationCode,
                  ),
                ),
              );
            } else if (state is MfaRequired) {
              context.push(
                AppRoute.mfaChallenge.path,
                extra: MfaChallengeArguments(
                  token: state.mfaToken,
                  pendingInvitationCode: widget.pendingInvitationCode,
                ),
              );
            } else if (state is Failure) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.error)));
            }
          },
          child: ResponsiveCenterContainer(
            backgroundColor: colors.background,
            child: Stack(
              children: [
                const _AtmosphericBackground(),
                _GhostCocktail(isDark: isDark),
                SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: isDark
                                  ? l10n.login_theme_to_light
                                  : l10n.login_theme_to_dark,
                              onPressed: () =>
                                  context.read<ThemeCubit>().toggleTheme(),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                backgroundColor: colors.surface.withValues(
                                  alpha: 0.9,
                                ),
                                side: BorderSide(color: colors.surfaceElevated),
                                shape: const CircleBorder(),
                              ),
                              icon: Icon(
                                isDark ? LucideIcons.sun : LucideIcons.moon,
                                color: colors.labelSecondary,
                                size: 19,
                              ),
                            ),
                          ),
                          _LogoArea(
                                glowAnim: _glowAnim,
                                shimmerAnim: _shimmerAnim,
                                isDark: isDark,
                              )
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .scale(
                                begin: const Offset(0.9, 0.9),
                                curve: Curves.easeOutBack,
                              ),
                          const SizedBox(height: 20),
                          Text(
                                l10n.login_tagline.toUpperCase(),
                                style: GoogleFonts.oswald(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 4.0,
                                  color: colors.labelPrimary.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              )
                              .animate()
                              .fadeIn(delay: 200.ms, duration: 600.ms)
                              .slideY(begin: 0.3, end: 0),
                          const SizedBox(height: 32),
                          ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 384,
                                ),
                                child: _PhoneCard(
                                  colors: colors,
                                  isDark: isDark,
                                  label: l10n.login_phone_label,
                                  hint: l10n.login_phone_hint,
                                  onLoginPressed: (phone) =>
                                      setState(() => _phoneNumber = phone),
                                ),
                              )
                              .animate()
                              .fadeIn(delay: 400.ms, duration: 600.ms)
                              .slideY(begin: 0.2, end: 0),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 384,
                                ),
                                child: _GoldCTAButton(
                                  label: l10n.login_continue,
                                  enabled: _phoneNumber != null && !_isLoading,
                                  loading: _isLoading,
                                  onPressed: _handleLogin,
                                ),
                              )
                              .animate()
                              .fadeIn(delay: 500.ms, duration: 600.ms)
                              .slideY(begin: 0.2, end: 0),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () =>
                                AppRoute.recoveryInitiate.push(context),
                            child: Text(
                              l10n.login_trouble,
                              style: TextStyle(
                                color: colors.labelSecondary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 384),
                            child: _OrDivider(
                              colors: colors,
                              label: l10n.login_or_continue_with,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 384,
                                ),
                                child: LoginButtonsWidget(
                                  loginBloc: _loginBloc,
                                  preferredProvider: widget.preferredProvider,
                                  onProviderCancelled:
                                      widget.pendingInvitationCode == null
                                      ? null
                                      : () {
                                          context.go(
                                            EntryCoordinator.invitationLocation(
                                              widget.pendingInvitationCode!,
                                            ),
                                          );
                                        },
                                ),
                              )
                              .animate()
                              .fadeIn(delay: 700.ms, duration: 600.ms)
                              .slideY(begin: 0.2, end: 0),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 384),
                            child: _LegalText(colors: colors),
                          ),
                          TextButton(
                            onPressed: () =>
                                AppRoute.staffInvitationAccept.go(context),
                            child: Text(l10n.entry_manual_invitation),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
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
    final colors = context.dobarColors;
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: colors.background,
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 0.8,
            colors: [
              barzGold.withValues(alpha: 0.12),
              colors.background.withValues(alpha: 0),
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
      bottom: -40,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Opacity(
          opacity: isDark ? 0.10 : 0.15,
          child: Image.asset(
            'assets/icons/cocktail-ghost.png',
            width: 360,
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
      height: 176,
      width: 176,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: glowAnim,
            builder: (_, child) => Container(
              width: 176,
              height: 176,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    barzGold.withValues(alpha: glowAnim.value * 0.4),
                    context.dobarColors.background.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.8],
                ),
              ),
            ),
          ),
          Hero(
            tag: 'logo',
            child: Image.asset(
              'assets/icons/dobar-logo.png',
              height: 176,
              width: 176,
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
  final String label;
  final String hint;
  final void Function(String?) onLoginPressed;

  const _PhoneCard({
    required this.colors,
    required this.isDark,
    required this.label,
    required this.hint,
    required this.onLoginPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.surfaceElevated.withValues(alpha: 0.8),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.labelPrimary.withValues(alpha: 0.06),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.oswald(
                  fontSize: 11,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w500,
                  color: colors.labelSecondary,
                ),
              ),
              const SizedBox(height: 12),
              LoginFieldsWidget(hintText: hint, onLoginPressed: onLoginPressed),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoldCTAButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  const _GoldCTAButton({
    required this.label,
    required this.enabled,
    this.loading = false,
    required this.onPressed,
  });

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
                    color: barzGold.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: barzDark,
                      ),
                    )
                  else ...[
                    Text(
                      widget.label.toUpperCase(),
                      style: GoogleFonts.oswald(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3.0,
                        color: barzDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      LucideIcons.arrow_right,
                      color: barzDark,
                      size: 20,
                    ),
                  ],
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
  final String label;
  const _OrDivider({required this.colors, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: colors.surfaceElevated)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.oswald(
              fontSize: 10,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w400,
              color: colors.labelSecondary,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: colors.surfaceElevated)),
      ],
    );
  }
}

class _LegalText extends StatelessWidget {
  final DobarColors colors;
  const _LegalText({required this.colors});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          text: l10n.login_legal_prefix,
          style: TextStyle(
            color: colors.labelSecondary,
            fontSize: 11,
            height: 1.5,
          ),
          children: <TextSpan>[
            TextSpan(
              text: l10n.login_terms,
              style: TextStyle(
                color: barzGoldDark,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => AppRoute.termsOfService.push(context),
            ),
            TextSpan(text: l10n.login_legal_and),
            TextSpan(
              text: l10n.login_privacy,
              style: TextStyle(
                color: barzGoldDark,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => AppRoute.privacyPolicy.push(context),
            ),
          ],
        ),
      ),
    );
  }
}
