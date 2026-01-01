import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../primitives/barz_app_bar.dart';
import '../primitives/barz_card.dart';
import '../../core/utils/constant/styles.dart';
import '../../core/utils/constant/colors.dart';

class ProfileWireframe extends StatelessWidget {
  const ProfileWireframe({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarzAppBar(title: 'Profile'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: yellowBackgroundGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.all(BarzSpacing.lg),
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
            const SizedBox(height: 24),
            // Logout button
            BarzCard(
              child: _buildMenuItem(
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                isDestructive: true,
              ),
            ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0),
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
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '+55 11 99999-9999',
                  style: TextStyle(
                    color: textTertiary,
                    fontSize: 13,
                  ),
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
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 14,
                  ),
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