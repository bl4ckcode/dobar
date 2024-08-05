import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/features/authentication/presentation/widgets/login_buttons_widget.dart';
import 'package:barz/features/authentication/presentation/widgets/login_fields_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brownBarzBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Stack(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: 200,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24),
                    child: Image.asset(
                      'assets/images/login/color2-white_textlogo_dark_background',
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
              const LoginFieldsWidget(),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "OR",
                      style: TextStyle(
                        color: Colors.black26,
                      ),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const LoginButtonsWidget(),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: 'By clicking continue, you agree to our ',
                  style: const TextStyle(color: Colors.white),
                  children: <TextSpan>[
                    TextSpan(
                      text: 'Terms of Service',
                      style: const TextStyle(color: Colors.black),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          // Handle Terms of Service tap

                          // You can navigate to another page or show a dialog here
                        },
                    ),
                    const TextSpan(
                      text: ' and ',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(color: Colors.black),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          // Handle Privacy Policy tap

                          // You can navigate to another page or show a dialog here
                        },
                    ),
                  ],
                ),
              ),

              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: 200,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Image.asset(
                      'assets/images/login/color2-white_icon_dark_background',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
