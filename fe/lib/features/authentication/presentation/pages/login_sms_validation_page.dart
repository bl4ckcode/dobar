import 'package:barz/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/features/authentication/presentation/bloc/login_bloc.dart';
import 'package:barz/features/authentication/presentation/bloc/login_event.dart';
import 'package:barz/features/authentication/presentation/bloc/login_state.dart';
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
    // Define the pin themes using design system colors
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: barzTextTheme.titleLarge?.copyWith(
        color: barzDark,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: surfaceWhite,
        border: Border.all(color: barzDark.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(BarzRadii.md),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: barzGold, width: 2),
      borderRadius: BorderRadius.circular(BarzRadii.md),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: barzGold.withValues(alpha: 0.2),
        border: Border.all(color: barzGold, width: 2),
      ),
    );

    return Scaffold(
      backgroundColor: barzGoldSoft,
      appBar: AppBar(
        backgroundColor: barzGoldSoft,
        elevation: 0,
        iconTheme: const IconThemeData(color: barzDark),
      ),
      body: BlocListener<LoginBloc, LoginState>(
        bloc: widget.loginBloc,
        listener: (context, state) {
          if (state is Success) {
            // Check if profile is complete
            if (state.isProfileComplete) {
              context.go('/');
            } else {
              context.go('/complete-registration', extra: {
                'email': state.email,
                'name': state.displayName,
              });
            }
          } else if (state is Failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error)),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(BarzSpacing.xl),
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
              const SizedBox(height: BarzSpacing.lg),
              // Using the design system button
              BarzButton.primary(
                onPressed: _smsCodeController.text.trim().length == 6 
                    ? _handleCodeVerification 
                    : null,
                label: "Verify Code",
              ),
              const SizedBox(height: BarzSpacing.lg),
              Center(
                child: Column(
                  children: [
                    Text(
                      "Didn't receive code?",
                      textAlign: TextAlign.center,
                      style: barzTextTheme.bodyMedium?.copyWith(
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: BarzSpacing.md),
                    GestureDetector(
                      onTap: () {
                        // Handle resend code functionality here.
                      },
                      child: Text(
                        'Resend',
                        textAlign: TextAlign.center,
                        style: barzTextTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.underline,
                          color: successGreen,
                          fontWeight: FontWeight.w600,
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
          style: barzTextTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: barzDark,
          ),
        ),
        const SizedBox(height: BarzSpacing.xl),
        Text(
          'Enter the code sent to the number',
          style: barzTextTheme.bodyLarge?.copyWith(
            color: textSecondary,
          ),
        ),
        const SizedBox(height: BarzSpacing.md),
        Text(
          phoneNumber,
          style: barzTextTheme.bodyLarge?.copyWith(
            color: barzDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: BarzSpacing.xxl),
      ],
    );
  }
}
