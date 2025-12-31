import 'package:flutter/material.dart';
import '../primitives/barz_button.dart';
import '../../core/utils/constant/styles.dart';
import '../../core/utils/constant/colors.dart';

class LoginWireframe extends StatelessWidget {
  const LoginWireframe({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: barzBlack,
      body: Padding(
        padding: const EdgeInsets.all(BarzSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('dobar', style: BarzTextStyles.headline.copyWith(color: barzYellow), textAlign: TextAlign.center),
            const SizedBox(height: BarzSpacing.xl),
            BarzButton(text: 'Login with Apple', onPressed: () {}),
            const SizedBox(height: BarzSpacing.md),
            BarzButton(text: 'Login with Google', onPressed: () {}),
            const SizedBox(height: BarzSpacing.md),
            BarzButton(text: 'Login with Phone', onPressed: () {}),
            const SizedBox(height: BarzSpacing.lg),
            Text('Register with CPF, RG, or ID', style: BarzTextStyles.body.copyWith(color: barzYellow), textAlign: TextAlign.center),
            const SizedBox(height: BarzSpacing.lg),
            Text('Terms of Use | Privacy', style: BarzTextStyles.body.copyWith(color: barzYellow), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}