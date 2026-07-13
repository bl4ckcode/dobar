import 'package:flutter/material.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/advertising/domain/models/models.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/l10n/app_localizations.dart';

/// Placement icon mapping matching the React Native CampaignsPage.
IconData _placementIcon(CampaignType type) {
  return switch (type) {
    CampaignType.featured => LucideIcons.star,
    CampaignType.search => LucideIcons.search,
    CampaignType.map => LucideIcons.mapPin,
    CampaignType.promoBoost => LucideIcons.flame,
    CampaignType.banner => LucideIcons.image,
  };
}

/// Status visual metadata matching the React Native design.
Color _statusColor(CampaignStatus status) {
  return switch (status) {
    CampaignStatus.active => pixGreen,
    CampaignStatus.paused => const Color(0xFFFFD93D),
    CampaignStatus.completed => const Color(0xFF9E9E9E),
    CampaignStatus.pending => const Color(0xFF9E9E9E),
    CampaignStatus.cancelled => const Color(0xFF9E9E9E),
  };
}

String _statusLabel(CampaignStatus status, AppLocalizations l10n) {
  return switch (status) {
    CampaignStatus.active => l10n.campaign_status_active,
    CampaignStatus.paused => l10n.campaign_status_paused,
    CampaignStatus.pending => l10n.campaign_status_pending,
    CampaignStatus.completed => l10n.campaign_status_completed,
    CampaignStatus.cancelled => 'Cancelada',
  };
}

String _formatCompact(int number) {
  if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(1)}M';
  } else if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(number >= 10000 ? 0 : 1)}k';
  }
  return number.toString();
}

String _formatBrl(double amount) {
  return NumberFormat.currency(
    symbol: 'R\$',
    decimalDigits: 2,
    locale: 'pt_BR',
  ).format(amount);
}

class CampaignCard extends StatefulWidget {
  final AdCampaign campaign;
  final VoidCallback onAnalytics;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;

  const CampaignCard({
    super.key,
    required this.campaign,
    required this.onAnalytics,
    this.onToggle,
    this.onDelete,
    this.onDuplicate,
  });

  @override
  State<CampaignCard> createState() => _CampaignCardState();
}

class _CampaignCardState extends State<CampaignCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;
    final l10n = AppLocalizations.of(context)!;
    final c = widget.campaign;

    final budgetTotal = c.budgetAmount;
    final budgetSpent = c.budgetSpent;
    final budgetPercent = budgetTotal > 0
        ? (budgetSpent / budgetTotal).clamp(0.0, 1.0)
        : 0.0;
    final pct = (budgetPercent * 100).round();
    final isHot = pct >= 90;
    final ctr =
        c.impressions > 0 ? (c.clicks / c.impressions) * 100 : 0.0;

    final placements = <CampaignType>[c.campaignType];
    final statusColor = _statusColor(c.status);
    final isActive = c.status == CampaignStatus.active;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: const Cubic(0.22, 1.0, 0.36, 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
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
            decoration: BoxDecoration(
              color: barzDarkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered
                    ? barzGold.withValues(alpha: 0.5)
                    : const Color(0xFF2C2C2C),
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: barzGold.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 20),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: placement icons + status badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Placement type icons row
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: placements.map((p) {
                              return Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Icon(
                                  _placementIcon(p),
                                  size: 14,
                                  color: dobar.labelSecondary,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          // Campaign name
                          Text(
                            c.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _statusLabel(c.status, l10n),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Budget progress bar
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _formatBrl(budgetSpent),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              TextSpan(
                                text: ' de ${_formatBrl(budgetTotal)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isHot ? errorRed : barzGold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: budgetPercent),
                        duration: const Duration(milliseconds: 1200),
                        curve: const Cubic(0.22, 1.0, 0.36, 1.0),
                        builder: (context, value, _) {
                          return LinearProgressIndicator(
                            value: value,
                            minHeight: 6,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.06),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isHot
                                  ? const Color(0xFFFF6B6B)
                                  : const Color(0xFFFFDE59),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Metrics row
                Row(
                  children: [
                    _buildMetricChip(
                      '${_formatCompact(c.impressions)} impressões',
                      dobar,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child:
                          Text('·', style: TextStyle(color: Colors.white24)),
                    ),
                    _buildMetricChip(
                      '${_formatCompact(c.clicks)} cliques',
                      dobar,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child:
                          Text('·', style: TextStyle(color: Colors.white24)),
                    ),
                    _buildMetricChip(
                      '${ctr.toStringAsFixed(1)}% CTR',
                      dobar,
                      bold: true,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Divider + Action buttons
                Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06)),
                const SizedBox(height: 16),

                Row(
                  children: [
                    // Analytics button
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onAnalytics,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.barChart3,
                                size: 16,
                                color: dobar.labelSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Analytics',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: dobar.labelSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // More options menu
                    PopupMenuButton<String>(
                      offset: const Offset(0, 40),
                      color: barzDarkCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFF2C2C2C)),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'toggle':
                            widget.onToggle?.call();
                          case 'duplicate':
                            widget.onDuplicate?.call();
                          case 'delete':
                            widget.onDelete?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        if (isActive)
                          PopupMenuItem(
                            value: 'toggle',
                            child: _menuItem(LucideIcons.pauseCircle, 'Pausar',
                                dobar),
                          )
                        else
                          PopupMenuItem(
                            value: 'toggle',
                            child: _menuItem(LucideIcons.playCircle, 'Retomar',
                                dobar),
                          ),
                        PopupMenuItem(
                          value: 'duplicate',
                          child: _menuItem(
                              LucideIcons.copy, 'Duplicar', dobar),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: _menuItem(LucideIcons.trash2, 'Excluir',
                              dobar,
                              color: errorRed),
                        ),
                      ],
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          LucideIcons.moreHorizontal,
                          size: 16,
                          color: dobar.labelSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip(
    String text,
    DobarColors dobar, {
    bool bold = false,
  }) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color:
            bold ? Colors.white.withValues(alpha: 0.8) : dobar.labelSecondary,
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _menuItem(
    IconData icon,
    String label,
    DobarColors dobar, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color ?? dobar.labelSecondary,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: color ?? Colors.white,
          ),
        ),
      ],
    );
  }
}