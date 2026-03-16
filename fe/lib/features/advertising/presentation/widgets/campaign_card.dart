import 'package:flutter/material.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/advertising/domain/models/models.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CampaignCard extends StatefulWidget {
  final AdCampaign campaign;
  final VoidCallback onAnalytics;

  const CampaignCard({
    super.key,
    required this.campaign,
    required this.onAnalytics,
  });

  @override
  State<CampaignCard> createState() => _CampaignCardState();
}

class _CampaignCardState extends State<CampaignCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isAnalyticsHovered = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;

    final budgetTotal = widget.campaign.budgetAmount;
    final budgetSpent = widget.campaign.budgetSpent;
    // Protect against division by zero
    final budgetPercent = budgetTotal > 0
        ? (budgetSpent / budgetTotal).clamp(0.0, 1.0)
        : 0.0;
    final budgetPercentText = (budgetPercent * 100).toStringAsFixed(0);

    final status = widget.campaign.status.name;
    final isActive = status == 'active';
    final isPaused = status == 'paused';

    Color statusColor = dobar.labelSecondary;
    Color statusBg = Colors.transparent;

    if (isActive) {
      statusColor = successGreen;
      statusBg = successGreen.withValues(alpha: 0.15);
    } else if (isPaused) {
      statusColor = warningOrange;
      statusBg = warningOrange.withValues(alpha: 0.15);
    } else {
      statusBg = dobar.navBackground;
    }

    final currencyFormat = NumberFormat.currency(
      symbol: r'$',
      decimalDigits: 0,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: MouseRegion(
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onAnalytics,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.translationValues(
                    0,
                    _isHovered ? -2 : 0,
                    0,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: dobar.surface,
                    borderRadius: BorderRadius.circular(BarzRadii.md),
                    border: Border.all(
                      color: _isHovered
                          ? barzGold.withValues(alpha: 0.3)
                          : dobar.surfaceElevated,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: _isHovered ? 0.15 : 0.05,
                        ),
                        blurRadius: _isHovered ? 12 : 8,
                        offset: Offset(0, _isHovered ? 6 : 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.campaign.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: dobar.labelPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(
                                      BarzRadii.full,
                                    ),
                                    border: Border.all(
                                      color: statusColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isActive) ...[
                                        FadeTransition(
                                          opacity: _pulseController,
                                          child: Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: statusColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        status.substring(0, 1).toUpperCase() +
                                            status.substring(1),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _isHovered ? 1.0 : 0.0,
                            child: MouseRegion(
                              onEnter: (_) =>
                                  setState(() => _isAnalyticsHovered = true),
                              onExit: (_) =>
                                  setState(() => _isAnalyticsHovered = false),
                              child: GestureDetector(
                                onTap: widget.onAnalytics,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _isAnalyticsHovered
                                        ? barzGold.withValues(alpha: 0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(
                                      BarzRadii.sm,
                                    ),
                                  ),
                                  child: Icon(
                                    LucideIcons.barChart3,
                                    size: 16,
                                    color: _isAnalyticsHovered
                                        ? barzGold
                                        : dobar.labelSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Metrics Grid
                      Wrap(
                        spacing: 24,
                        runSpacing: 16,
                        children: [
                          _buildMetricColumn(
                            icon: LucideIcons.eye,
                            label: 'IMPRESSIONS',
                            value: _formatNumber(widget.campaign.impressions),
                            dobar: dobar,
                          ),
                          _buildMetricColumn(
                            icon: LucideIcons.mousePointerClick,
                            label: 'CLICKS',
                            value: _formatNumber(widget.campaign.clicks),
                            dobar: dobar,
                          ),
                          _buildMetricColumn(
                            icon: LucideIcons.dollarSign,
                            label: 'BUDGET',
                            value: currencyFormat.format(budgetTotal),
                            dobar: dobar,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Progress Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$budgetPercentText% spent',
                            style: TextStyle(
                              fontSize: 10,
                              color: dobar.labelSecondary,
                            ),
                          ),
                          Text(
                            '${currencyFormat.format(budgetTotal)} total',
                            style: TextStyle(
                              fontSize: 10,
                              color: dobar.labelSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: budgetPercent,
                          minHeight: 4,
                          backgroundColor: dobar.navBackground,
                          valueColor: const AlwaysStoppedAnimation(barzGold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricColumn({
    required IconData icon,
    required String label,
    required String value,
    required DobarColors dobar,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: dobar.labelSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: dobar.labelSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'SF Pro Display',
            color: dobar.labelPrimary,
          ),
        ),
      ],
    );
  }
}
