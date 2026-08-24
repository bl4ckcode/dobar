import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:barz/core/design/tokens/dobar_colors.dart';
import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/l10n/app_localizations.dart';

class ProSubscriptionModal extends StatefulWidget {
  const ProSubscriptionModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ProSubscriptionModal(),
    );
  }

  @override
  State<ProSubscriptionModal> createState() => _ProSubscriptionModalState();
}

class _ProSubscriptionModalState extends State<ProSubscriptionModal> {
  bool _isAnnual = true;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colors = context.dobarColors;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? barzDark.withValues(alpha: 0.95) : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: barzGold.withValues(alpha: isDark ? 0.1 : 0.2)),
      ),
      child: Stack(
        children: [
          // Particle Background
          const _ParticlesBackground(),

          Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),

              // Close Button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : colors.surfaceElevated,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.x,
                        color: colors.labelSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Hero Section
                      const SizedBox(height: 8),
                      const _FloatingCrown(),
                      const SizedBox(height: 16),
                      Text(
                        l10n.pro_modal_title,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          foreground: Paint()
                            ..shader = LinearGradient(
                              colors: [
                                const Color(0xFFFFD700),
                                const Color(0xFFFFA500),
                              ],
                            ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                        ),
                      ),
                      Text(
                        l10n.pro_modal_subtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Billing Toggle
                      _buildBillingToggle(l10n, colors, isDark),

                      const SizedBox(height: 32),

                      // Benefits List
                      _buildBenefitsList(l10n, colors, isDark),

                      const SizedBox(height: 40),

                      // Pricing
                      _buildPricing(l10n),

                      const SizedBox(height: 24),

                      // CTA Button
                      _buildCTA(l10n, colors, isDark),

                      const SizedBox(height: 16),
                      Text(
                        l10n.pro_modal_footer_note,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Footer Links
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _FooterLink(
                            text: l10n.pro_modal_restore,
                            onTap: () {},
                            colors: colors,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 24),
                          _FooterLink(
                            text: l10n.pro_modal_terms,
                            onTap: () {},
                            colors: colors,
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillingToggle(AppLocalizations l10n, DobarColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            label: l10n.pro_modal_monthly,
            isSelected: !_isAnnual,
            onTap: () => setState(() => _isAnnual = false),
            colors: colors,
            isDark: isDark,
          ),
          _ToggleButton(
            label: l10n.pro_modal_annual,
            isSelected: _isAnnual,
            onTap: () => setState(() => _isAnnual = true),
            badge: l10n.pro_modal_save_percent,
            colors: colors,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsList(AppLocalizations l10n, DobarColors colors, bool isDark) {
    final benefits = [
      _BenefitItem(
        icon: LucideIcons.zap,
        title: l10n.pro_benefit_priority_title,
        desc: l10n.pro_benefit_priority_desc,
        colors: colors,
        isDark: isDark,
      ),
      _BenefitItem(
        icon: LucideIcons.trendingUp,
        title: l10n.pro_benefit_cashback_title,
        desc: l10n.pro_benefit_cashback_desc,
        colors: colors,
        isDark: isDark,
      ),
      _BenefitItem(
        icon: LucideIcons.tag,
        title: l10n.pro_benefit_deals_title,
        desc: l10n.pro_benefit_deals_desc,
        colors: colors,
        isDark: isDark,
      ),
      _BenefitItem(
        icon: LucideIcons.badgeCheck,
        title: l10n.pro_benefit_vip_title,
        desc: l10n.pro_benefit_vip_desc,
        colors: colors,
        isDark: isDark,
      ),
      _BenefitItem(
        icon: LucideIcons.calendarCheck,
        title: l10n.pro_benefit_early_access_title,
        desc: l10n.pro_benefit_early_access_desc,
        colors: colors,
        isDark: isDark,
      ),
    ];

    return Column(
      children: benefits
          .asMap()
          .entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: e.value
                  .animate()
                  .fadeIn(delay: (200 + e.key * 100).ms, duration: 400.ms)
                  .slideX(begin: 0.1, end: 0),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPricing(AppLocalizations l10n) {
    final colors = context.dobarColors;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _isAnnual
                  ? l10n.pro_modal_price_annual
                  : l10n.pro_modal_price_monthly,
              style: GoogleFonts.spaceGrotesk(
                color: colors.labelPrimary,
                fontSize: 40,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              l10n.pro_modal_per_month,
              style: TextStyle(color: colors.labelSecondary, fontSize: 16),
            ),
          ],
        ),
        if (_isAnnual)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.pro_modal_billed_annually,
              style: TextStyle(color: colors.labelSecondary, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildCTA(AppLocalizations l10n, DobarColors colors, bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() => _isLoading = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _isLoading = false);
        });
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          ),
          boxShadow: [
            BoxShadow(
              color: barzGold.withValues(alpha: isDark ? 0.3 : 0.4),
              blurRadius: isDark ? 20 : 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Shimmer
              Positioned.fill(child: _ShimmerEffect()),

              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(barzDark),
                  ),
                )
              else
                Text(
                  l10n.pro_modal_cta,
                  style: GoogleFonts.spaceGrotesk(
                    color: barzDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingCrown extends StatelessWidget {
  const _FloatingCrown();

  @override
  Widget build(BuildContext context) {
    return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.2),
            ),
          ),
          child: const Center(
            child: Icon(LucideIcons.crown, color: Color(0xFFFFD700), size: 40),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .moveY(begin: 0, end: -8, duration: 2.seconds, curve: Curves.easeInOut)
        .then()
        .moveY(begin: -8, end: 0, duration: 2.seconds, curve: Curves.easeInOut);
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final DobarColors colors;
  final bool isDark;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.desc,
    required this.colors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : colors.surfaceElevated.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: barzGold.withValues(alpha: isDark ? 0.1 : 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: barzGold, size: 18),
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
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(color: colors.labelSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;
  final DobarColors colors;
  final bool isDark;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
    required this.colors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? barzGold : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? barzDark : colors.labelSecondary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? barzDark.withValues(alpha: 0.1)
                      : colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: isSelected ? barzDark : barzGold,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final DobarColors colors;
  final bool isDark;

  const _FooterLink({
    required this.text,
    required this.onTap,
    required this.colors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: colors.labelSecondary,
          fontSize: 12,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

class _ParticlesBackground extends StatefulWidget {
  const _ParticlesBackground();

  @override
  State<_ParticlesBackground> createState() => _ParticlesBackgroundState();
}

class _ParticlesBackgroundState extends State<_ParticlesBackground>
    with SingleTickerProviderStateMixin {
  late final List<_Particle> particles;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    particles = List.generate(20, (index) => _Particle());
    _controller = AnimationController(vsync: this, duration: 10.seconds)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ParticlePainter(particles, _controller.value),
        );
      },
    );
  }
}

class _Particle {
  late double x;
  late double y;
  late double size;
  late double speed;
  late double opacity;

  _Particle() {
    x = math.Random().nextDouble();
    y = math.Random().nextDouble();
    size = math.Random().nextDouble() * 2 + 1;
    speed = math.Random().nextDouble() * 0.05 + 0.01;
    opacity = math.Random().nextDouble() * 0.3 + 0.1;
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFD700);
    for (var p in particles) {
      final currentY = (p.y - progress * p.speed) % 1.0;
      canvas.drawCircle(
        Offset(p.x * size.width, currentY * size.height),
        p.size,
        paint..color = paint.color.withValues(alpha: p.opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

class _ShimmerEffect extends StatefulWidget {
  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: 1500.ms)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FractionalTranslation(
          translation: Offset(_controller.value * 2 - 1, 0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.3),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
