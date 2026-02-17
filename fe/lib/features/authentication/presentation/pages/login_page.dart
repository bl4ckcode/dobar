import 'package:barz/core/design/components/glow_button.dart';
import 'package:barz/core/design/design_system.dart';
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

class _LoginPageState extends State<LoginPage> {
  late LoginBloc _loginBloc;
  String? _phoneNumber;

  @override
  void initState() {
    super.initState();
    _loginBloc = LoginBloc(
      loginUseCase: getItInjector<LoginUsecase>(),
      firebaseAuth: getItInjector<FirebaseAuth>(),
      userRepository: getItInjector<UserRepository>(),
    );
  }

  @override
  void dispose() {
    _loginBloc.close();
    super.dispose();
  }

  void _handleLogin() {
    if (_phoneNumber != null) {
      _loginBloc.add(LoginEvent.loginButtonPressed(phoneNumber: _phoneNumber!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
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
                AppRoute.home.go(context);
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
          child: SafeArea(
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
                          vertical: 24,
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 180,
                              child: Image.asset(
                                'assets/icons/dobar_logo_animated_fade.gif',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 32),

                            LoginFieldsWidget(
                              onLoginPressed: (phone) {
                                setState(() => _phoneNumber = phone);
                              },
                            ),

                            const SizedBox(height: 20),

                            GlowButton(
                              label: 'Continue',
                              enabled: _phoneNumber != null,
                              trailing: Icon(
                                Icons.arrow_forward,
                                color: colors.buttonOnPrimary,
                                size: 20,
                              ),
                              onPressed: _handleLogin,
                            ),

                            const SizedBox(height: 16),
                            Center(
                              child: TextButton(
                                onPressed: () =>
                                    AppRoute.recoveryInitiate.push(context),
                                child: Text(
                                  'Trouble logging in?',
                                  style: TextStyle(
                                    color: colors.labelSecondary,
                                    fontSize: 14,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: colors.labelSecondary.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    "or continue with",
                                    style: TextStyle(
                                      color: colors.labelSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: colors.labelSecondary.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            LoginButtonsWidget(loginBloc: _loginBloc),

                            const SizedBox(height: 12),

                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                text: 'By continuing, you agree to our ',
                                style: TextStyle(
                                  color: colors.labelSecondary,
                                  fontSize: 13,
                                ),
                                children: <TextSpan>[
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: TextStyle(
                                      color: colors.labelSelected,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {},
                                  ),
                                  TextSpan(
                                    text: ' and ',
                                    style: TextStyle(
                                      color: colors.labelSecondary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: colors.labelSelected,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {},
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),

                            SizedBox(
                              height: 100,
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.bottomCenter,
                                children: [
                                  Positioned(
                                    bottom: -80,
                                    child: Opacity(
                                      opacity: 0.2,
                                      child:
                                          Image.asset(
                                            'assets/login/barz_cup_icon.png',
                                            width:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width *
                                                0.8,
                                            fit: BoxFit.contain,
                                          ).animate().slideY(
                                            begin: 1.0,
                                            end: 0.0,
                                            duration: 800.ms,
                                            curve: Curves.easeOutBack,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
