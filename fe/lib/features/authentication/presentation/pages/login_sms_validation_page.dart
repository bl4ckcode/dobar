import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/shared/presentation/widget/barz_black_elevated_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/authentication/presentation/bloc/login_bloc.dart';
import 'package:barz/features/authentication/presentation/bloc/login_event.dart';
import 'package:barz/features/authentication/presentation/bloc/login_state.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:sms_autofill/sms_autofill.dart';

class LoginValidatePhoneNumberPage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final LoginBloc loginBloc;

  const LoginValidatePhoneNumberPage({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    required this.loginBloc,
  });

  @override
  State<LoginValidatePhoneNumberPage> createState() =>
      _LoginValidatePhoneNumberPageState();
}

class _LoginValidatePhoneNumberPageState
    extends State<LoginValidatePhoneNumberPage> with CodeAutoFill {
  final TextEditingController _smsCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Start listening for SMS autofill codes
    listenForCode();

    _smsCodeController.addListener(() {
      setState(() {});
    });
  }

  @override
  void codeUpdated() {
    setState(() {
      _smsCodeController.text = code ?? "";
    });
  }

  @override
  void dispose() {
    cancel(); // Stop SMS autofill listening
    _smsCodeController.dispose();
    super.dispose();
  }

  void _handleCodeVerification() {
    final smsCode = _smsCodeController.text.trim();
    if (smsCode.isNotEmpty) {
      widget.loginBloc.add(VerifyCodeButtonPressed(
        verificationId: widget.verificationId,
        smsCode: smsCode,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the verification code.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define the pin themes using your color palette.
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 20,
        color: backgroundColorLight,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: shadowColorLight),
        borderRadius: BorderRadius.circular(20),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: mainColor),
      borderRadius: BorderRadius.circular(8),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: mainColor,
      ),
    );

    return Scaffold(
      backgroundColor: backgroundColor2, // dark background for consistency
      appBar: AppBar(
        backgroundColor: mainColor,
        iconTheme: const IconThemeData(
          color: Colors.blueGrey,  // Set the color of the back button
        ),
      ),
      body: BlocListener<LoginBloc, LoginState>(
        bloc: widget.loginBloc,
        listener: (context, state) {
          if (state is Success) {
            Navigator.pushNamedAndRemoveUntil(
                context, '/home', (Route<dynamic> route) => false);
          } else if (state is Failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error)),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OtpHeader(phoneNumber: widget.phoneNumber),
              Pinput(
                controller: _smsCodeController,
                length: 6,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                submittedPinTheme: submittedPinTheme,
                pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                showCursor: true,
                onCompleted: (pin) {
                  // Automatically trigger code verification once complete
                  _handleCodeVerification();
                },
              ),
              const SizedBox(height: 16),
              // Using a custom elevated button styled for your app
              BarzBlackElevatedButton(
                onPressed: _handleCodeVerification,
                text: "Verify Code",
                isEnabled: _smsCodeController.text.trim().length == 6,
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Didn’t receive code?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: backgroundColorLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        // Handle resend code functionality here.
                      },
                      child: Text(
                        'Resend',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          decoration: TextDecoration.underline,
                          color: Colors.green,
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
    );
  }
}

class OtpHeader extends StatelessWidget {
  const OtpHeader({
    super.key,
    required this.phoneNumber,
  });

  final String phoneNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Confirm your phone number',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: backgroundColorLight,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Enter the code sent to the number',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color.fromRGBO(133, 153, 170, 1),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          phoneNumber,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: backgroundColorLight,
          ),
        ),
        const SizedBox(height: 64),
      ],
    );
  }
}
