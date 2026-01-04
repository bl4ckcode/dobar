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
import 'package:go_router/go_router.dart';
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

  void _handleLogin(String? phoneNumber) {
    if (phoneNumber != null) {
      _loginBloc.add(LoginEvent.loginButtonPressed(phoneNumber: phoneNumber));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: barzGoldSoft,
      body: PopScope(
        onPopInvokedWithResult: (left, right) {},
        child: BlocListener<LoginBloc, LoginState>(
          bloc: _loginBloc,
          listener: (context, state) {
            if (state is Loading) {
              LoadingUtil.showLoadingDialog(context);
            } else if (state is Success) {
              // Dismiss loading dialog if showing
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              
              // Check if profile is complete
              if (state.isProfileComplete) {
                // Navigate to home
                context.go('/');
              } else {
                // Navigate to complete registration
                context.go('/complete-registration', extra: {
                  'email': state.email,
                  'name': state.displayName,
                });
              }
            } else if (state is CodeSent) {
              // Dismiss the loading dialog
              Navigator.of(context).pop();

              // Navigate to the phone number validation page
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
              // Dismiss the loading dialog
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }

              // Show an error message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error)),
              );
            }
          },
          child: SafeArea(
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Logo
                        SizedBox(
                          height: 120,
                          child: Image.asset(
                            'assets/login/barz_text_icon.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Phone login
                        LoginFieldsWidget(onLoginPressed: _handleLogin),
                        
                        const SizedBox(height: 24),
                        
                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: barzDark.withValues(alpha: 0.3))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                "or continue with",
                                style: TextStyle(
                                  color: barzDark.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: barzDark.withValues(alpha: 0.3))),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Social login buttons
                        LoginButtonsWidget(loginBloc: _loginBloc),
                        
                        const SizedBox(height: 32),
                        
                        // Terms text
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            text: 'By continuing, you agree to our ',
                            style: TextStyle(
                              color: barzDark.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                            children: <TextSpan>[
                              TextSpan(
                                text: 'Terms of Service',
                                style: const TextStyle(
                                  color: barzDark,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    // Handle Terms of Service tap
                                  },
                              ),
                              TextSpan(
                                text: ' and ',
                                style: TextStyle(color: barzDark.withValues(alpha: 0.7)),
                              ),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(
                                  color: barzDark,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    // Handle Privacy Policy tap
                                  },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      const Spacer(),
                      // Bottom illustration
                      Image.asset(
                        'assets/login/barz_cup_icon.png',
                        width: MediaQuery.of(context).size.width * 0.8,
                        fit: BoxFit.contain,
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
  }
}
