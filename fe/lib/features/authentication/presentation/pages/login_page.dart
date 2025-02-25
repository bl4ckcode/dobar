import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/authentication/presentation/widgets/login_buttons_widget.dart';
import 'package:barz/features/authentication/presentation/widgets/login_fields_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
      backgroundColor: mainColor,
      body: PopScope(
        onPopInvokedWithResult: (left, right) {},
        child: BlocListener<LoginBloc, LoginState>(
          bloc: _loginBloc,
          listener: (context, state) {
            if (state is Loading) {
              // Show a loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );
            } else if (state is CodeSent) {
              // Dismiss the loading dialog
              Navigator.of(context).pop();

              // Navigate to the phone number validation page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LoginValidatePhoneNumberPage(
                    verificationId: state.verificationId,
                    loginBloc: _loginBloc,
                  ),
                ),
              );
            } else if (state is Failure) {
              // Dismiss the loading dialog
              Navigator.of(context).pop();

              // Show an error message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error)),
              );
            }
          },
          child: Scaffold(
            backgroundColor: mainColor,
            body: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            child: Center(
                              child: Transform.scale(
                                scale: 1.2,
                                child: Image.asset(
                                  'assets/login/barz_text_icon.png',
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 24.0),
                          child:
                              LoginFieldsWidget(onLoginPressed: _handleLogin),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(
                            left: 24,
                            right: 24,
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  "or continue with",
                                  style: TextStyle(
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 24,
                            right: 24,
                            bottom: 24,
                          ),
                          child: LoginButtonsWidget(loginBloc: _loginBloc),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 24,
                            right: 24,
                          ),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              text: 'By clicking continue, you agree to our ',
                              style: const TextStyle(color: Colors.white),
                              children: <TextSpan>[
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      // Handle Terms of Service tap
                                    },
                                ),
                                const TextSpan(
                                  text: ' and ',
                                  style: TextStyle(color: Colors.white),
                                ),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      // Handle Privacy Policy tap
                                    },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(child: SizedBox(height: 132)),
                      Transform.scale(
                        scale: 1.8,
                        child: Image.asset(
                          width: MediaQuery.of(context).size.width,
                          'assets/login/barz_cup_icon.png',
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
  }
}
