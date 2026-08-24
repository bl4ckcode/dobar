import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/services/biometry_service.dart';
import 'package:barz/core/services/token_storage_service.dart';
import 'package:barz/core/router/app_routes.dart';

class BiometricLockPage extends StatefulWidget {
  const BiometricLockPage({super.key});

  @override
  State<BiometricLockPage> createState() => _BiometricLockPageState();
}

class _BiometricLockPageState extends State<BiometricLockPage> {
  final BiometryService _biometryService = getItInjector<BiometryService>();
  final TokenStorageService _tokenStorage =
      getItInjector<TokenStorageService>();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    // Auto-trigger biometry after a short delay to allow animations to start
    Future.delayed(const Duration(milliseconds: 800), _handleUnlock);
  }

  Future<void> _handleUnlock() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);

    try {
      final success = await _biometryService.unlock();
      if (success && mounted) {
        AppRoute.home.go(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.dobarColors.surface,
        title: Text(
          'Logout',
          style: TextStyle(color: context.dobarColors.labelPrimary),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: context.dobarColors.labelSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.dobarColors.labelSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _tokenStorage.clearAll();
      await _biometryService.clear();
      if (mounted) {
        AppRoute.login.go(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Background Gradient/Blur
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [barzGold.withValues(alpha: 0.05), colors.background],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Animated Logo/Icon
                  Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: barzGold.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: barzGold.withValues(alpha: 0.1),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            LucideIcons.lock,
                            size: 40,
                            color: barzGold,
                          ),
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .shimmer(
                        duration: 3.seconds,
                        color: barzGold.withValues(alpha: 0.2),
                      )
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.05, 1.05),
                        duration: 2.seconds,
                      ),

                  const SizedBox(height: 48),

                  Text(
                        'App Locked',
                        style: GoogleFonts.oswald(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: colors.labelPrimary,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 12),

                  Text(
                    'Authenticate to continue to Barz',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: colors.labelSecondary,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

                  const Spacer(),

                  // Unlock Button
                  GestureDetector(
                        onTap: _handleUnlock,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                barzGoldGradientStart,
                                barzGoldGradientEnd,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: barzGold.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isAuthenticating
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: barzDark,
                                    ),
                                  )
                                : Text(
                                    'UNLOCK',
                                    style: GoogleFonts.oswald(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                      color: barzDark,
                                    ),
                                  ),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 500.ms)
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1, 1),
                      ),

                  const SizedBox(height: 20),

                  // Secondary Action (Logout)
                  TextButton(
                    onPressed: _handleLogout,
                    child: Text(
                      'LOGOUT',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: colors.labelSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ).animate().fadeIn(delay: 700.ms),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
