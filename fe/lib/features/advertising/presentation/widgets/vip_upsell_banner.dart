import 'package:flutter/material.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:lucide_icons/lucide_icons.dart';

class VipUpsellBanner extends StatefulWidget {
  final VoidCallback onUpgrade;

  const VipUpsellBanner({super.key, required this.onUpgrade});

  @override
  State<VipUpsellBanner> createState() => _VipUpsellBannerState();
}

class _VipUpsellBannerState extends State<VipUpsellBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;
  bool _isCtaHovered = false;
  bool _isCtaPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            isDark ? barzDarkCardLight : surfaceLight,
            dobar.surface,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: CustomPaint(painter: _GridPainter(color: barzGold)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 24.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _controller,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: barzGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(BarzRadii.md),
                      border: Border.all(
                        color: barzGold.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.crown,
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
                    mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _BenefitBadge(
                            icon: LucideIcons.zap,
                            label: 'Priority delivery',
                          ),
                          const SizedBox(width: 12),
                          _BenefitBadge(
                            icon: LucideIcons.target,
                            label: 'Advanced targeting',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // CTA Button
                MouseRegion(
                  onEnter: (_) => setState(() => _isCtaHovered = true),
                  onExit: (_) => setState(() => _isCtaHovered = false),
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTapDown: (_) => setState(() => _isCtaPressed = true),
                    onTapUp: (_) {
                      setState(() => _isCtaPressed = false);
                      widget.onUpgrade();
                    },
                    onTapCancel: () => setState(() => _isCtaPressed = false),
                    child: AnimatedScale(
                      scale: _isCtaPressed
                          ? 0.97
                          : (_isCtaHovered ? 1.03 : 1.0),
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: barzGold,
                          borderRadius: BorderRadius.circular(BarzRadii.md),
                          boxShadow: [
                            BoxShadow(
                              color: barzGold.withValues(
                                alpha: _isCtaHovered ? 0.6 : 0.4,
                              ),
                              blurRadius: _isCtaHovered ? 16 : 8,
                              spreadRadius: _isCtaHovered ? 2 : 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: AnimatedBuilder(
                          animation: _shimmerAnimation,
                          builder: (context, child) {
                            return ShaderMask(
                              shaderCallback: (bounds) {
                                return LinearGradient(
                                  begin: const Alignment(-1.0, -0.5),
                                  end: const Alignment(1.0, 0.5),
                                  stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
                                  colors: [
                                    barzDark,
                                    barzDark,
                                    barzDark.withValues(alpha: 0.6),
                                    barzDark,
                                    barzDark,
                                  ],
                                  transform: GradientRotation(
                                    _shimmerAnimation.value,
                                  ),
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.srcIn,
                              child: child,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Upgrade Now',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      inherit: true,
                                    ),
                              ),
                              SizedBox(width: 8),
                              Icon(LucideIcons.arrowRight, size: 18),
                            ],
                          ),
                        ),
                      ),
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
