import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/core/design/design_system.dart';

class ProPlanSheet extends StatelessWidget {
  const ProPlanSheet({super.key});

  /// Displays the Dobar Pro Upgrade bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ProPlanSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dobar = context.dobarColors;
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF141414) : surfaceWhite;
    final textColor = dobar.labelPrimary;
    final mutedTextColor = dobar.labelSecondary;

    return Container(
      padding: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Stack(
                children: [
                  const Align(alignment: Alignment.center, child: _ProBadge()),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: Icon(
                        LucideIcons.x,
                        color: mutedTextColor,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Unlock Dobar Pro',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontFamily: 'Space Grotesk',
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Take your business to the next level with advanced analytics, targeted push campaigns, and priority placement.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: mutedTextColor,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Benefits List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _BenefitItem(
                    icon: LucideIcons.trendingUp,
                    title: 'Advanced Analytics',
                    description:
                        'Get deep insights into your audience demographics, popular times, and menu performance.',
                  ),
                  const SizedBox(height: 16),
                  _BenefitItem(
                    icon: LucideIcons.megaphone,
                    title: 'Targeted Campaigns',
                    description:
                        'Send custom push notifications directly to patrons who are near or have favorited your bar.',
                  ),
                  const SizedBox(height: 16),
                  _BenefitItem(
                    icon: LucideIcons.star,
                    title: 'Priority Placement',
                    description:
                        'Stand out in user searches and interactive maps as a promoted venue.',
                  ),
                  const SizedBox(height: 16),
                  _BenefitItem(
                    icon: LucideIcons.scanLine,
                    title: 'Unlimited Table QR',
                    description:
                        'Generate unlimited active tables and dynamic QR codes for direct ordering.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Upgrade CTA Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : surfaceDim,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0xFF262626)
                        : theme.colorScheme.outline,
                  ),
                ),
              ),
              child: Column(
                children: [
                  RichText(
                    text: TextSpan(
                      text: '\$49',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        fontFamily: 'Space Grotesk',
                      ),
                      children: [
                        TextSpan(
                          text: ' / month',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            color: mutedTextColor,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try it free for 14 days. Cancel anytime.',
                    style: TextStyle(fontSize: 13, color: mutedTextColor),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: barzGold,
                        foregroundColor: barzDark,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        // For now we just close and notify it's in progress
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Contacting Support... Integration coming soon.',
                            ),
                            backgroundColor: barzGold,
                          ),
                        );
                      },
                      child: const Text(
                        'Start Free Trial',
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
          ],
        ),
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: barzGold.withValues(alpha: 0.15),
        border: Border.all(color: barzGold.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.crown, size: 16, color: barzGold),
          SizedBox(width: 8),
          Text(
            'PRO',
            style: TextStyle(
              color: barzGold,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dobar = context.dobarColors;
    final isDark = theme.brightness == Brightness.dark;

    final iconBg = isDark ? const Color(0xFF1E1E1E) : dobar.surfaceElevated;
    final textColor = dobar.labelPrimary;
    final descColor = dobar.labelSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: barzGold, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 14, height: 1.4, color: descColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
