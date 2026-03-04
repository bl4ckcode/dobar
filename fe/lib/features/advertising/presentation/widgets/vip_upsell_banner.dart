import 'package:flutter/material.dart';
import 'package:barz/core/design/design_system.dart';

class VipUpsellBanner extends StatefulWidget {
  final VoidCallback onUpgrade;

  const VipUpsellBanner({super.key, required this.onUpgrade});

  @override
  State<VipUpsellBanner> createState() => _VipUpsellBannerState();
}

class _VipUpsellBannerState extends State<VipUpsellBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Equivalent colors from DobarColors
    final dobar = context.dobarColors;
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        color: dobar.surface,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        border: Border.all(color: barzGold.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: barzGold.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            dobar.surface,
            isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
            dobar.surface,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Subtle Grid Pattern Simulation
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: CustomPaint(painter: _GridPainter(color: barzGold)),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: barzGold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(BarzRadii.sm),
                          border: Border.all(
                            color: barzGold.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          color: barzGold,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Text Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upgrade to VIP',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: dobar.labelPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Reach more customers, unlock advanced targeting, and dominate your local nightlife scene with premium campaign tools.',
                            style: TextStyle(
                              fontSize: 14,
                              color: dobar.labelSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Badges
                          Row(
                            children: [
                              _BenefitBadge(
                                icon: Icons.bolt,
                                label: 'Priority delivery',
                              ),
                              const SizedBox(width: 12),
                              _BenefitBadge(
                                icon: Icons.track_changes,
                                label: 'Advanced targeting',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // CTA Button aligned right
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: widget.onUpgrade,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: barzGold,
                      foregroundColor: barzDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(BarzRadii.sm),
                      ),
                      elevation: 4,
                      shadowColor: barzGold.withValues(alpha: 0.4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Upgrade Now',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BenefitBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: barzGold.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: barzGold.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;

  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const double step = 40.0;

    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
