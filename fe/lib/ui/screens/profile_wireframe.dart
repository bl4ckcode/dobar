import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:barz/features/payments/presentation/bloc/payment_bloc.dart';
import 'package:barz/features/payments/presentation/bloc/payment_event.dart';
import 'package:barz/features/payments/presentation/pages/checkout_page.dart';
import 'package:barz/features/payments/presentation/widgets/pro_subscription_modal.dart';
import 'package:barz/ui/business/widgets/pro_plan_sheet.dart';
import 'package:barz/core/design/tokens/dobar_colors.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../primitives/barz_app_bar.dart';
import '../primitives/barz_card.dart';
import '../../core/utils/constant/styles.dart';
import '../../core/utils/constant/colors.dart';
import '../../core/design/tokens/colors.dart' as design;

class ProfileWireframe extends StatefulWidget {
  const ProfileWireframe({super.key});

  @override
  State<ProfileWireframe> createState() => _ProfileWireframeState();
}

class _ProfileWireframeState extends State<ProfileWireframe> {
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: errorColor),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Clear token from storage and network client
      await getItInjector<LoginUsecase>().logout();
      await DioNetwork.clearTokens();

      if (mounted) {
        // Navigate to login page (router will handle auth guard)
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;

    return Scaffold(
      appBar: BarzAppBar(
        title: 'Profile',
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(LucideIcons.flaskConical),
              tooltip: 'Sprint 6 Showcases',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: dobar.background,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(LucideIcons.qrCode, color: barzYellow),
                            title: const Text('Bar Entry VIP (Check-in)'),
                            subtitle: const Text('Redesigned Industrial Modern flow'),
                            onTap: () {
                              Navigator.pop(context);
                              AppRoute.checkin.push(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(LucideIcons.crown, color: barzYellow),
                            title: const Text('Dobar Pro Modal (Consumer)'),
                            subtitle: const Text('Glassmorphic subscription sheet'),
                            onTap: () {
                              Navigator.pop(context);
                              ProSubscriptionModal.show(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(LucideIcons.building, color: barzYellow),
                            title: const Text('Dobar Pro Plan (Business)'),
                            subtitle: const Text('Business tier upgrade sheet'),
                            onTap: () {
                              Navigator.pop(context);
                              ProPlanSheet.show(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(LucideIcons.creditCard, color: barzYellow),
                            title: const Text('Industrial Checkout'),
                            subtitle: const Text('Premium success dialog & UI'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MultiBlocProvider(
                                    providers: [
                                      BlocProvider.value(value: getItInjector<CartBloc>()),
                                      BlocProvider(
                                        create: (_) => getItInjector<PaymentBloc>()
                                          ..add(const LoadSavedCards()),
                                      ),
                                    ],
                                    child: CheckoutPage(
                                      arguments: CheckoutArguments(
                                        items: [],
                                        subtotal: 99.9,
                                        total: 99.9,
                                        bundleSavings: 0,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      backgroundColor: design.surfacePrimary,
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BarzSpacing.lg,
            BarzSpacing.lg,
            BarzSpacing.lg,
            120, // Extra padding for floating nav bar
          ),
          children: [
            // Profile Header
            _buildProfileHeader().animate().fadeIn().scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1, 1),
            ),
            const SizedBox(height: 24),

          _buildSectionTitle('Activity'),
          const SizedBox(height: 12),
          BarzCard(
            child: _buildMenuItem(
              icon: Icons.history,
              title: 'Past Activities',
              subtitle: 'View your order history',
            ),
          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1, end: 0),
          BarzCard(
            child: _buildMenuItem(
              icon: Icons.card_giftcard,
              title: 'Cashback/Rewards',
              subtitle: 'Track your earnings',
              trailing: _buildBadge('3'),
            ),
          ).animate().fadeIn(delay: 150.ms).slideX(begin: -0.1, end: 0),
          const SizedBox(height: 24),
          _buildSectionTitle('Settings'),
          const SizedBox(height: 12),
          BarzCard(
            child: _buildMenuItem(
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'Preferences & notifications',
            ),
          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),
          BarzCard(
            child: _buildMenuItem(
              icon: Icons.help_outline,
              title: 'Help/Support',
              subtitle: 'Get assistance',
            ),
          ).animate().fadeIn(delay: 250.ms).slideX(begin: -0.1, end: 0),
          GestureDetector(
            onTap: () => context.push('/legal/terms'),
            child: BarzCard(
              child: _buildMenuItem(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'View our terms',
              ),
            ),
          ).animate().fadeIn(delay: 275.ms).slideX(begin: -0.1, end: 0),
          GestureDetector(
            onTap: () => context.push('/legal/privacy'),
            child: BarzCard(
              child: _buildMenuItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'How we protect your data',
              ),
            ),
          ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0),
          const SizedBox(height: 24),

          // Logout button
          GestureDetector(
            onTap: _handleLogout,
            child: BarzCard(
              child: _buildMenuItem(
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                isDestructive: true,
              ),
            ),
          ).animate().fadeIn(delay: 325.ms).slideX(begin: -0.1, end: 0),
        ],
      ),
    ),
  );
}

  Widget _buildProfileHeader() {
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
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: barzYellowSoft,
              shape: BoxShape.circle,
              border: Border.all(color: barzYellow, width: 3),
            ),
            child: Icon(Icons.person, color: barzYellowDark, size: 36),
          ),
          const SizedBox(width: 16),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Name',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'user@email.com',
                  style: TextStyle(color: textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '+55 11 99999-9999',
                  style: TextStyle(color: textTertiary, fontSize: 13),
                ),
              ],
            ),
          ),
          // Edit button
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.edit_outlined, color: barzYellowDark),
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
        style: TextStyle(
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
  }) {
    final color = isDestructive ? errorColor : barzYellowDark;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDestructive
                  ? errorColor.withValues(alpha: 0.1)
                  : barzYellowSoft,
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
                    color: isDestructive ? errorColor : textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
          if (trailing == null) Icon(Icons.chevron_right, color: textTertiary),
        ],
      ),
    );
  }

  Widget _buildBadge(String count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: barzYellow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count,
        style: TextStyle(
          color: barzBlack,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
