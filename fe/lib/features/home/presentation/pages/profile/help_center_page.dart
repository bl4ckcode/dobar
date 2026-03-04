import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Help Center'),
        backgroundColor: colors.surface,
        foregroundColor: colors.labelPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(BarzSpacing.lg),
        children: [
          _buildSectionTitle('Frequently Asked Questions', colors),
          const SizedBox(height: 12),
          _buildFaqItem(
            'How do I place an order?',
            'Open a bar\'s page, browse the menu, add items to your cart, and proceed to checkout.',
            colors,
          ),
          _buildFaqItem(
            'How do I track my order?',
            'After placing an order, you\'ll receive real-time status updates. You can also check your order history in the Profile tab.',
            colors,
          ),
          _buildFaqItem(
            'How does cashback work?',
            'You earn cashback on eligible orders. The amount is added to your wallet balance and can be used on future orders.',
            colors,
          ),
          _buildFaqItem(
            'How do I enable biometric login?',
            'Go to Settings > App Settings and toggle on Biometric Login. You\'ll need Face ID or fingerprint set up on your device.',
            colors,
          ),
          _buildFaqItem(
            'How do I delete my account?',
            'Go to Profile > Delete Account. This action is permanent and cannot be undone.',
            colors,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Contact Us', colors),
          const SizedBox(height: 12),
          _buildContactTile(
            icon: Icons.email_outlined,
            title: 'Email Support',
            subtitle: 'support@dobar.app',
            onTap: () => _launchEmail(),
            colors: colors,
          ),
          _buildContactTile(
            icon: Icons.bug_report_outlined,
            title: 'Report a Bug',
            subtitle: 'Help us improve the app',
            onTap: () => _launchBugReport(),
            colors: colors,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Legal', colors),
          const SizedBox(height: 12),
          _buildContactTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'Read our terms',
            onTap: () => AppRoute.termsOfService.push(context),
            colors: colors,
          ),
          _buildContactTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Read our privacy policy',
            onTap: () => AppRoute.privacyPolicy.push(context),
            colors: colors,
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@dobar.app',
      queryParameters: {'subject': 'Dobar Support Request'},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchBugReport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@dobar.app',
      queryParameters: {'subject': 'Bug Report - Dobar App'},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildSectionTitle(String title, DobarColors colors) {
    return Text(
      title,
      style: TextStyle(
        color: colors.labelPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer, DobarColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          question,
          style: TextStyle(
            color: colors.labelPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconColor: barzGold,
        collapsedIconColor: colors.labelSecondary,
        children: [
          Text(
            answer,
            style: TextStyle(color: colors.labelSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required DobarColors colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: barzGoldSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: barzGold, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.labelPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.labelSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.labelSecondary),
          ],
        ),
      ),
    );
  }
}
