import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RecoveryVerifyPage extends StatefulWidget {
  final String? prefilledToken;

  const RecoveryVerifyPage({super.key, this.prefilledToken});

  @override
  State<RecoveryVerifyPage> createState() => _RecoveryVerifyPageState();
}

class _RecoveryVerifyPageState extends State<RecoveryVerifyPage> {
  late TextEditingController _tokenController;
  final LoginUsecase _loginUsecase = getItInjector<LoginUsecase>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.prefilledToken ?? '');
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the recovery code')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await _loginUsecase.verifyRecovery(token);
    setState(() => _isLoading = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recovery Failed: ${failure.errorMessage}')),
        );
      },
      (authResponse) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account recovered successfully')),
        );
        // Login success, navigate home
        context.go(AppRoute.home.path);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: barzDark,
      appBar: AppBar(
        title: const Text('Verify Recovery', style: TextStyle(color: barzGold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: barzGold),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Recovery Code',
              style: TextStyle(
                color: textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter the code sent to your email to recover your account.',
              style: TextStyle(color: textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _tokenController,
              style: const TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Recovery Code',
                labelStyle: const TextStyle(color: textTertiary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: textTertiary.withValues(alpha: 0.3),
                  ),
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
                onPressed: _isLoading ? null : _onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: barzGold,
                  foregroundColor: barzDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: barzDark,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Recover Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
