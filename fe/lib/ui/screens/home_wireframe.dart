import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:barz/ui/primitives/barz_app_bar.dart';
import 'package:barz/ui/primitives/barz_card.dart';
import 'package:barz/core/utils/constant/colors.dart';

class HomeWireframe extends StatelessWidget {
  const HomeWireframe({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarzAppBar(title: 'Home'),
      // Using gradient background for softer appearance
      body: Container(
        decoration: const BoxDecoration(gradient: yellowBackgroundGradient),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: 24),
            _buildSectionTitle('Featured'),
            const SizedBox(height: 12),
            BarzCard(
              child: _buildCardContent(
                icon: Icons.local_offer,
                title: 'Drinks/Cashback Promotions',
                subtitle: 'Discover exclusive deals',
              ),
            ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1, end: 0),
            BarzCard(
              child: _buildCardContent(
                icon: Icons.store,
                title: 'Bars/Restaurants Exclusive',
                subtitle: 'Partner venues near you',
              ),
            ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),
            BarzCard(
              child: _buildCardContent(
                icon: Icons.local_bar,
                title: 'Drinks Section',
                subtitle: 'Browse our menu',
              ),
            ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: barzBlack,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: barzYellow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.waving_hand, color: barzBlack),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back!',
                      style: TextStyle(
                        color: textOnDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ready to order?',
                      style: TextStyle(
                        color: textOnDark.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().scale(
      begin: const Offset(0.95, 0.95),
      end: const Offset(1, 1),
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

  Widget _buildCardContent({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: barzYellowSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: barzYellowDark, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
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
          Icon(Icons.chevron_right, color: textTertiary),
        ],
      ),
    );
  }
}
