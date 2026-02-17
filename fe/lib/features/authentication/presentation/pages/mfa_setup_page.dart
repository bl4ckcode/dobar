import 'dart:convert';

import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:barz/features/authentication/presentation/bloc/mfa_setup_bloc.dart';
import 'package:barz/features/authentication/presentation/bloc/mfa_setup_event.dart';
import 'package:barz/features/authentication/presentation/bloc/mfa_setup_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class MfaSetupPage extends StatelessWidget {
  const MfaSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          MfaSetupBloc(getItInjector<LoginUsecase>())
            ..add(const MfaSetupEvent.initiateSetup()),
      child: const _MfaSetupView(),
    );
  }
}

class _MfaSetupView extends StatefulWidget {
  const _MfaSetupView();

  @override
  State<_MfaSetupView> createState() => _MfaSetupViewState();
}

class _MfaSetupViewState extends State<_MfaSetupView> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _onVerifyPressed() {
    final code = _codeController.text.trim();
    if (code.length == 6) {
      context.read<MfaSetupBloc>().add(MfaSetupEvent.verifyAndActivate(code));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit code')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: barzDark,
      appBar: AppBar(
        title: const Text('Setup 2FA', style: TextStyle(color: barzGold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: barzGold),
      ),
      body: BlocConsumer<MfaSetupBloc, MfaSetupState>(
        listener: (context, state) {
          state.maybeWhen(
            success: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('MFA Enabled Successfully!')),
              );
              context.pop();
            },
            errorDuringVerification: (secret, qrCode, error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Verification Failed: $error')),
              );
            },
            failure: (error) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Setup Failed: $error')));
            },
            orElse: () {},
          );
        },
        builder: (context, state) {
          return state.maybeWhen(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: barzGold)),
            initial: () =>
                const Center(child: CircularProgressIndicator(color: barzGold)),
            failure: (error) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: $error',
                    style: const TextStyle(color: errorRed),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<MfaSetupBloc>().add(
                      const MfaSetupEvent.initiateSetup(),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            orElse: () {
              String secret = '';
              String qrCode = '';
              bool isVerifying = false;

              if (state is MfaSetupLoaded) {
                secret = state.secret;
                qrCode = state.qrCode;
              } else if (state is MfaSetupVerifying) {
                secret = state.secret;
                qrCode = state.qrCode;
                isVerifying = true;
              } else if (state is MfaSetupErrorDuringVerification) {
                secret = state.secret;
                qrCode = state.qrCode;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Secure your account',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Scan this QR code with your authenticator app (Google Authenticator, Authy, etc).',
                      style: TextStyle(color: textSecondary, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (qrCode.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.memory(
                          base64Decode(qrCode.split(',').last),
                          width: 200,
                          height: 200,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.broken_image,
                                size: 100,
                                color: Colors.black,
                              ),
                        ),
                      ),
                    const SizedBox(height: 32),
                    const Text(
                      'Or enter this key manually:',
                      style: TextStyle(color: textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: barzGold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SelectableText(
                            secret,
                            style: const TextStyle(
                              color: barzGold,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.copy,
                              color: textTertiary,
                              size: 20,
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: secret));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Secret copied to clipboard'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'Enter the 6-digit code',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 24,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: TextStyle(
                          color: textTertiary.withValues(alpha: 0.3),
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: barzGold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isVerifying ? null : _onVerifyPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: barzGold,
                          foregroundColor: barzDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isVerifying
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: barzDark,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Verify & Activate',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
