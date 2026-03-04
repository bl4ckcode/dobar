import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/authentication/presentation/pages/mfa_setup_page.dart';
import 'package:barz/features/home/presentation/pages/profile/app_settings_page.dart';
import 'package:barz/features/home/presentation/pages/profile/help_center_page.dart';
import 'package:barz/features/home/presentation/pages/profile/notification_settings_page.dart';
import 'package:barz/features/home/presentation/pages/profile/privacy_settings_page.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:intl/intl.dart';

class ProfileHomePage extends StatefulWidget {
  const ProfileHomePage({super.key});

  @override
  State<ProfileHomePage> createState() => _ProfileHomePageState();
}

class _ProfileHomePageState extends State<ProfileHomePage> {
  Future<void> _handleLogout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: errorRed),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await getItInjector<LoginUsecase>().logout();
      await DioNetwork.clearTokens();

      if (mounted) {
        AppRoute.login.go(context);
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: errorRed)),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone and you will lose all your data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: errorRed,
              backgroundColor: errorRed.withValues(alpha: 0.1),
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;

      // Show loading overlay
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final result = await getItInjector<UserRepository>().deleteAccount();

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete account: ${failure.errorMessage}',
              ),
            ),
          );
        },
        (_) async {
          await DioNetwork.clearTokens();
          if (mounted) {
            AppRoute.login.go(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Your account has been deleted.')),
            );
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<SessionBloc, SessionState>(
          builder: (context, state) {
            final session = state.currentSession;
            if (session == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final user = session.user;
            final currencyFormat = NumberFormat.currency(
              locale: 'pt_BR',
              symbol: 'R\$',
            );

            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [barzGoldSoft, Colors.white],
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(BarzSpacing.lg),
                children: [
                  _buildProfileHeader(
                    user,
                  ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
                  const SizedBox(height: 24),
                  _buildWalletCard(
                    user,
                    currencyFormat,
                  ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Activity'),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.history,
                    title: 'Order History',
                    subtitle: 'View your past orders',
                    onTap: () => AppRoute.orders.push(context),
                  ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1, end: 0),
                  _buildMenuItem(
                    icon: Icons.card_giftcard,
                    title: 'Cashback & Rewards',
                    subtitle: 'Track your earnings',
                    trailing: _buildBadge(
                      currencyFormat.format(user.totalCashback),
                    ),
                    onTap: () {},
                  ).animate().fadeIn(delay: 150.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Settings'),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.security,
                    title: 'Two-Factor Authentication',
                    subtitle: 'Secure your account with 2FA',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MfaSetupPage(),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.settings_outlined,
                    title: 'App Settings',
                    subtitle: 'Theme, language & biometrics',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppSettingsPage(),
                      ),
                    ),
                  ).animate().fadeIn(delay: 250.ms).slideX(begin: -0.1, end: 0),
                  _buildMenuItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Push, email & SMS preferences',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsPage(),
                      ),
                    ),
                  ).animate().fadeIn(delay: 270.ms).slideX(begin: -0.1, end: 0),
                  _buildMenuItem(
                    icon: Icons.lock_outline,
                    title: 'Privacy',
                    subtitle: 'Location & data settings',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacySettingsPage(),
                      ),
                    ),
                  ).animate().fadeIn(delay: 290.ms).slideX(begin: -0.1, end: 0),
                  _buildMenuItem(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    subtitle: 'FAQ, contact & bug reports',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpCenterPage()),
                    ),
                  ).animate().fadeIn(delay: 310.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 24),
                  _buildMenuItem(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Sign out of your account',
                    isDestructive:
                        false, // Changed to false as it's not destructive data-wise
                    onTap: _handleLogout,
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Danger Zone'),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.delete_forever,
                    title: 'Delete Account',
                    subtitle: 'Permanently remove your data',
                    isDestructive: true,
                    onTap: _handleDeleteAccount,
                  ).animate().fadeIn(delay: 350.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(dynamic user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: barzGoldSoft,
              shape: BoxShape.circle,
              border: Border.all(color: barzGold, width: 3),
            ),
            child: user.profilePictureUrl != null
                ? ClipOval(
                    child: Image.network(
                      user.profilePictureUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.person, color: barzGold, size: 36),
                    ),
                  )
                : const Icon(Icons.person, color: barzGold, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName ?? 'User',
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (user.email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.email!,
                    style: const TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ],
                if (user.phoneNumber != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.phoneNumber!,
                    style: const TextStyle(color: textTertiary, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.edit_outlined, color: barzGold),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard(dynamic user, NumberFormat currencyFormat) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [barzGold, Color(0xFFE8C547)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: barzGold.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Wallet',
                style: TextStyle(
                  color: barzDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(Icons.account_balance_wallet, color: barzDark),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currencyFormat.format(user.walletBalance),
            style: const TextStyle(
              color: barzDark,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Available balance',
            style: TextStyle(
              color: barzDark.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final color = isDestructive ? errorRed : barzGold;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDestructive
                    ? errorRed.withValues(alpha: 0.1)
                    : barzGoldSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive ? errorRed : textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (trailing == null)
              const Icon(Icons.chevron_right, color: textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: barzGold,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: barzDark,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
