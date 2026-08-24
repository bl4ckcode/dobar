import 'package:flutter/material.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
      duration: const Duration(seconds: 3),
    )..repeat(reverse: false);

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
            color: barzGold.withValues(alpha: isDark ? 0.2 : 0.35),
            blurRadius: 30,
            spreadRadius: -8,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  dobar.surface,
                  barzDarkCardLight,
                  dobar.surface,
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  surfaceWhite,
                  const Color(0xFFFFFAF0),
                  surfaceWhite,
                ],
              ),
      ),
      child: Stack(
        children: [
          // Gold accent line at top - matching Lovable's style
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(BarzRadii.md)),
                gradient: const LinearGradient(
                  colors: [Colors.transparent, barzGold, Colors.transparent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          // Subtle grid pattern
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.03 : 0.02,
              child: CustomPaint(painter: _GridPainter(color: barzGold)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Pulsing Crown Icon
                FadeTransition(
                  opacity: _controller.drive(
                    TweenSequence([
                      TweenSequenceItem(
                        tween: Tween(begin: 0.6, end: 1.0),
                        weight: 1,
                      ),
                      TweenSequenceItem(
                        tween: Tween(begin: 1.0, end: 0.6),
                        weight: 1,
                      ),
                    ]),
                  ),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: barzGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(BarzRadii.md),
                      border: Border.all(
                        color: barzGold.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: barzGold.withValues(alpha: 0.15),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.crown,
                      color: barzGold,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Upgrade to VIP',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: dobar.labelPrimary,
                          fontFamily: 'Space Grotesk',
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Reach more customers, unlock advanced targeting, and dominate your local nightlife scene with premium campaign tools.',
                        style: TextStyle(
                          fontSize: 13,
                          color: dobar.labelSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _BenefitBadge(
                            icon: LucideIcons.zap,
                            label: 'Priority delivery',
                          ),
                          const SizedBox(width: 16),
                          _BenefitBadge(
                            icon: LucideIcons.target,
                            label: 'Advanced targeting',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // CTA Button - Lovable style with shimmer gradient
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(BarzRadii.md),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFE070),
                              Color(0xFFFFC000),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: barzGold.withValues(
                                alpha: _isCtaHovered ? 0.5 : 0.3,
                              ),
                              blurRadius: _isCtaHovered ? 20 : 12,
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
                                  stops: const [0.0, 0.4, 0.48, 0.52, 0.6, 1.0],
                                  colors: [
                                    barzDark.withValues(alpha: 0.8),
                                    barzDark.withValues(alpha: 0.8),
                                    Colors.white,
                                    Colors.white,
                                    barzDark.withValues(alpha: 0.8),
                                    barzDark.withValues(alpha: 0.8),
                                  ],
                                  transform: GradientRotation(
                                    _shimmerAnimation.value * 0.5,
                                  ),
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.srcIn,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Upgrade Now',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      fontFamily: 'Space Grotesk',
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    LucideIcons.arrowRight,
                                    size: 16,
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                            );
                          },
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
        Icon(icon, size: 13, color: barzGold.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
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