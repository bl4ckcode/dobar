import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/ui/shell/responsive_shell.dart';

/// Enhanced Login Screen
/// 
/// This is the entry point of the app - users must authenticate before
/// accessing the main app. Follows UI/UX best practices:
/// - Clear visual hierarchy
/// - Accessible contrast ratios
/// - Smooth animations
/// - Responsive layout for web
class LoginWireframe extends StatelessWidget {
  const LoginWireframe({super.key});

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ResponsiveShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 768;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: darkBackgroundGradient,
        ),
        child: SafeArea(
          child: isWide ? _buildWideLayout(context) : _buildMobileLayout(context),
        ),
      ),
    );
  }

  /// Mobile layout - single column
  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 80),
            _buildLogo(),
            const SizedBox(height: 48),
            _buildWelcomeText(),
            const SizedBox(height: 48),
            _buildLoginButtons(context),
            const SizedBox(height: 32),
            _buildRegisterLink(),
            const SizedBox(height: 48),
            _buildTermsAndPrivacy(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Wide layout for web/tablet - centered card
  Widget _buildWideLayout(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLogo(),
              const SizedBox(height: 32),
              _buildWelcomeText(),
              const SizedBox(height: 40),
              _buildLoginButtons(context),
              const SizedBox(height: 24),
              _buildRegisterLink(),
              const SizedBox(height: 32),
              _buildTermsAndPrivacy(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // Logo icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: barzYellow,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: barzYellow.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.local_bar,
            color: barzBlack,
            size: 40,
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              duration: 600.ms,
              curve: Curves.easeOutBack,
            ),
        const SizedBox(height: 24),
        // Brand name
        Text(
          'dobar',
          style: TextStyle(
            color: barzYellow,
            fontSize: 42,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        )
            .animate(delay: 200.ms)
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.2, end: 0),
      ],
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Your drink, your way',
          style: TextStyle(
            color: textOnDark.withValues(alpha: 0.9),
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Fast ordering. Real rewards.',
          style: TextStyle(
            color: textOnDark.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ).animate(delay: 400.ms).fadeIn(duration: 500.ms);
  }

  Widget _buildLoginButtons(BuildContext context) {
    return Column(
      children: [
        // Apple Sign In
        _LoginButton(
          icon: Icons.apple,
          text: 'Continue with Apple',
          backgroundColor: Colors.white,
          textColor: Colors.black,
          onPressed: () => _navigateToHome(context),
        ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.2, end: 0),
        
        const SizedBox(height: 12),
        
        // Google Sign In
        _LoginButton(
          icon: Icons.g_mobiledata,
          text: 'Continue with Google',
          backgroundColor: Colors.white,
          textColor: Colors.black,
          onPressed: () => _navigateToHome(context),
        ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.2, end: 0),
        
        const SizedBox(height: 12),
        
        // Phone Sign In
        _LoginButton(
          icon: Icons.phone_android,
          text: 'Continue with Phone',
          backgroundColor: barzYellow,
          textColor: barzBlack,
          onPressed: () => _navigateToHome(context),
        ).animate(delay: 700.ms).fadeIn().slideY(begin: 0.2, end: 0),
      ],
    );
  }

  Widget _buildRegisterLink() {
    return TextButton(
      onPressed: () {
        // Navigate to registration with CPF/RG/ID
      },
      child: Text(
        'Register with CPF, RG, or ID',
        style: TextStyle(
          color: barzYellow.withValues(alpha: 0.9),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    ).animate(delay: 800.ms).fadeIn();
  }

  Widget _buildTermsAndPrivacy() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () {},
          child: Text(
            'Terms of Use',
            style: TextStyle(
              color: textOnDark.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ),
        Text(
          '|',
          style: TextStyle(
            color: textOnDark.withValues(alpha: 0.3),
          ),
        ),
        TextButton(
          onPressed: () {},
          child: Text(
            'Privacy Policy',
            style: TextStyle(
              color: textOnDark.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ),
      ],
    ).animate(delay: 900.ms).fadeIn();
  }
}

class _LoginButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onPressed;

  const _LoginButton({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
