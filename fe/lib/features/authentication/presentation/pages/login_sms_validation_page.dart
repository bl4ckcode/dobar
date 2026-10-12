import 'package:barz/core/design/components/glow_button.dart';
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
    extends State<LoginValidatePhoneNumberPage>
    with CodeAutoFill {
  final TextEditingController _smsCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
    cancel();
    _smsCodeController.dispose();
    super.dispose();
  }

  void _handleCodeVerification() {
    final smsCode = _smsCodeController.text.trim();
    if (smsCode.isNotEmpty) {
      widget.loginBloc.add(
        VerifyCodeButtonPressed(
          verificationId: widget.verificationId,
          smsCode: smsCode,
          phoneNumber: widget.phoneNumber,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the verification code.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: barzTextTheme.titleLarge?.copyWith(
        color: colors.labelSelected,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.labelSecondary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(BarzRadii.md),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: colors.labelSelected, width: 2),
      borderRadius: BorderRadius.circular(BarzRadii.md),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: colors.labelSelected.withValues(alpha: 0.15),
        border: Border.all(color: colors.labelSelected, width: 2),
      ),
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.navBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.labelSelected),
      ),
      body: BlocListener<LoginBloc, LoginState>(
        bloc: widget.loginBloc,
        listener: (context, state) {
          if (state is Success) {
            if (state.needsOnboarding) {
              context.go('/onboarding', extra: {'phone': state.phoneNumber});
              return;
            }

            if (state.isProfileComplete) {
              context.go('/');
            } else {
              context.go(
                '/complete-registration',
                extra: {'email': state.email, 'name': state.displayName},
              );
            }
          } else if (state is Failure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error)));
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
                  _handleCodeVerification();
                },
              ),
              const SizedBox(height: BarzSpacing.xl),
              GlowButton(
                label: 'Verify Code',
                enabled: _smsCodeController.text.trim().length == 6,
                trailing: Icon(
                  Icons.check,
                  color: colors.buttonOnPrimary,
                  size: 20,
                ),
                onPressed: _handleCodeVerification,
              ),
              const SizedBox(height: BarzSpacing.xl),
              Center(
                child: Column(
                  children: [
                    Text(
                      "Didn't receive code?",
                      textAlign: TextAlign.center,
                      style: barzTextTheme.bodyMedium?.copyWith(
                        color: colors.labelSecondary,
                      ),
                    ),
                    const SizedBox(height: BarzSpacing.md),
                    GestureDetector(
                      onTap: () {},
                      child: Text(
                        'Resend',
                        textAlign: TextAlign.center,
                        style: barzTextTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.underline,
                          color: colors.labelSelected,
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
  const OtpHeader({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Confirm your phone number',
          style: barzTextTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.labelPrimary,
          ),
        ),
        const SizedBox(height: BarzSpacing.xl),
        Text(
          'Enter the code sent to the number',
          style: barzTextTheme.bodyLarge?.copyWith(
            color: colors.labelSecondary,
          ),
        ),
        const SizedBox(height: BarzSpacing.md),
        Text(
          phoneNumber,
          style: barzTextTheme.bodyLarge?.copyWith(
            color: colors.labelSelected,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: BarzSpacing.xxl),
      ],
    );
  }
}
