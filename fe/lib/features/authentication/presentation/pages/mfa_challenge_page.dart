import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/authentication/presentation/bloc/login_bloc.dart';
import 'package:barz/features/authentication/presentation/bloc/login_event.dart';
import 'package:barz/features/authentication/presentation/bloc/login_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/authentication/presentation/navigation/post_login_destination.dart';

class MfaChallengePage extends StatelessWidget {
  final String mfaToken;
  final String? pendingInvitationCode;

  const MfaChallengePage({
    super.key,
    required this.mfaToken,
    this.pendingInvitationCode,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getItInjector<LoginBloc>(),
      child: _MfaChallengeView(
        mfaToken: mfaToken,
        pendingInvitationCode: pendingInvitationCode,
      ),
    );
  }
}

class _MfaChallengeView extends StatefulWidget {
  final String mfaToken;
  final String? pendingInvitationCode;

  const _MfaChallengeView({required this.mfaToken, this.pendingInvitationCode});

  @override
  State<_MfaChallengeView> createState() => _MfaChallengeViewState();
}

class _MfaChallengeViewState extends State<_MfaChallengeView> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _onVerifyPressed() {
    final code = _codeController.text.trim();
    if (code.length == 6) {
      context.read<LoginBloc>().add(
        LoginEvent.mfaChallengeSubmitted(widget.mfaToken, code),
      );
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
        title: const Text(
          'Two-Factor Authentication',
          style: TextStyle(color: barzGold),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: barzGold),
      ),
      body: BlocConsumer<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state is Success) {
            navigateAfterLogin(
              context,
              state: state,
              pendingInvitationCode: widget.pendingInvitationCode,
            );
          } else if (state is Failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Verification Failed: ${state.error}')),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state.maybeWhen(
            loading: () => true,
            orElse: () => false,
          );

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 80, color: barzGold),
                const SizedBox(height: 32),
                const Text(
                  'Authentication Required',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please enter the 6-digit code from your authenticator app.',
                  style: TextStyle(color: textSecondary, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  enabled: !isLoading,
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
                    onPressed: isLoading ? null : _onVerifyPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: barzGold,
                      foregroundColor: barzDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: barzDark,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Verify',
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
      ),
    );
  }
}
