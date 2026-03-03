import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../primitives/barz_app_bar.dart';
import '../primitives/barz_card.dart';
import '../../core/utils/constant/styles.dart';
import '../../core/utils/constant/colors.dart';

class FindWireframe extends StatelessWidget {
  const FindWireframe({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarzAppBar(title: 'Find'),
      body: Container(
        decoration: const BoxDecoration(gradient: yellowBackgroundGradient),
        child: ListView(
          padding: const EdgeInsets.all(BarzSpacing.lg),
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: textTertiary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search bars, restaurants...',
                        hintStyle: TextStyle(color: textTertiary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  Icon(Icons.tune, color: textSecondary),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.1, end: 0),
            const SizedBox(height: 24),
            _buildSectionTitle('Nearby'),
            const SizedBox(height: 12),
            BarzCard(
              child: _buildCardContent(
                icon: Icons.location_on,
                title: 'Nearby Bars/Restaurants',
                subtitle: 'Find venues close to you',
              ),
            ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1, end: 0),
            BarzCard(
              child: _buildCardContent(
                icon: Icons.map_outlined,
                title: 'Map View',
                subtitle: 'Explore on the map',
              ),
            ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),
          ],
        ),
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
