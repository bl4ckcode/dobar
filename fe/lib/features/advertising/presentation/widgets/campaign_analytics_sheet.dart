import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:barz/core/design/design_system.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/features/advertising/domain/models/models.dart';
import 'package:barz/features/advertising/presentation/bloc/advertising_bloc.dart';
import 'package:barz/features/advertising/presentation/bloc/advertising_event.dart';
import 'package:barz/features/advertising/presentation/bloc/advertising_state.dart';
import 'package:intl/intl.dart';

class CampaignAnalyticsSheet extends StatefulWidget {
  final AdCampaign campaign;

  const CampaignAnalyticsSheet({super.key, required this.campaign});

  static void show(BuildContext context, AdCampaign campaign) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: MultiBlocProvider(
              providers: [
                BlocProvider.value(
                  value: context.read<AdvertisingBloc>()
                    ..add(
                      LoadAnalytics(
                        campaignId: campaign.id,
                        barId: campaign.barId,
                      ),
                    ),
                ),
              ],
              child: CampaignAnalyticsSheet(campaign: campaign),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: math.max(0.001, anim1.value * 8.0),
            sigmaY: math.max(0.001, anim1.value * 8.0),
          ),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: const Offset(0, 0))
                .animate(
                  CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
                ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<CampaignAnalyticsSheet> createState() => _CampaignAnalyticsSheetState();
}

class _CampaignAnalyticsSheetState extends State<CampaignAnalyticsSheet> {
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
    final isDark = context.isDark;
    final currencyFormat = NumberFormat.currency(
      symbol: r'$',
      decimalDigits: 2,
    );
    final currencyNoDecimals = NumberFormat.currency(
      symbol: r'$',
      decimalDigits: 0,
    );

    final budgetTotal = widget.campaign.budgetAmount;
    final budgetSpent = widget.campaign.budgetSpent;
    final budgetPercent = budgetTotal > 0
        ? (budgetSpent / budgetTotal).clamp(0.0, 1.0)
        : 0.0;
    final remaining = (budgetTotal - budgetSpent).clamp(0.0, double.infinity);
    final budgetPercentText = (budgetPercent * 100).toStringAsFixed(0);

    final status = widget.campaign.status.name;
    final isActive = status == 'active';
    final isPaused = status == 'paused';

    Color statusColor = dobar.labelSecondary;
    Color statusBg = Colors.transparent;
    Color statusBorderColor = Colors.transparent;
    bool showPulse = false;

    if (isActive) {
      statusColor = successGreen;
      statusBg = successGreen.withValues(alpha: 0.15);
      statusBorderColor = successGreen.withValues(alpha: 0.3);
      showPulse = true;
    } else if (isPaused) {
      statusColor = warningOrange;
      statusBg = warningOrange.withValues(alpha: 0.15);
      statusBorderColor = warningOrange.withValues(alpha: 0.3);
    } else {
      statusBg = dobar.navBackground;
      statusBorderColor = dobar.surfaceElevated;
    }

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: dobar.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: isDark ? dobar.surfaceElevated : surfaceDim,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
            blurRadius: 32,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? dobar.surfaceElevated : surfaceDim,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                // Header - matching Lovable's style
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.campaign.name,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Space Grotesk',
                              color: dobar.labelPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Status badge with pulse dot
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(
                                    BarzRadii.full,
                                  ),
                                  border: Border.all(
                                    color: statusBorderColor,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (showPulse) ...[
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      status.substring(0, 1).toUpperCase() +
                                          status.substring(1),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Type badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? dobar.navBackground
                                      : surfaceMuted,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isDark
                                        ? dobar.surfaceElevated
                                        : surfaceDim,
                                  ),
                                ),
                                child: Text(
                                  widget.campaign.campaignType.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: dobar.labelSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: dobar.labelSecondary),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? dobar.navBackground
                            : surfaceMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Analytics BlocBuilder
                BlocBuilder<AdvertisingBloc, AdvertisingState>(
                  builder: (context, state) {
                    if (state.isLoadingAnalytics) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(color: barzGold),
                        ),
                      );
                    }

                    final int imp =
                        state.analytics?.impressions ??
                        widget.campaign.impressions;
                    final int clk =
                        state.analytics?.clicks ?? widget.campaign.clicks;
                    final int convs = state.analytics?.conversions ?? 0;

                    final ctr = imp > 0 ? (clk / imp) * 100 : 0.0;
                    final cpc = clk > 0 ? budgetSpent / clk : 0.0;
                    final convRate = clk > 0 ? (convs / clk) * 100 : 0.0;

                    final diffDays =
                        widget.campaign.endDate
                            ?.difference(widget.campaign.startDate)
                            .inDays ??
                        1;
                    final int durationDays = diffDays > 0 ? diffDays : 1;
                    final dailyAvg = budgetSpent / durationDays;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Performance Metrics section
                        Text(
                          'PERFORMANCE METRICS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: dobar.labelSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 3-column staggered metric grid - matching Lovable's layout
                        _buildMetricGridRow([
                          _MetricCardData(
                            icon: LucideIcons.eye,
                            label: 'IMPRESSIONS',
                            value: _formatNumber(imp),
                          ),
                          _MetricCardData(
                            icon: LucideIcons.mousePointerClick,
                            label: 'CLICKS',
                            value: _formatNumber(clk),
                          ),
                          _MetricCardData(
                            icon: LucideIcons.refreshCcw,
                            label: 'CONVERSIONS',
                            value: _formatNumber(convs),
                          ),
                        ], dobar, isDark),
                        const SizedBox(height: 10),
                        _buildMetricGridRow([
                          _MetricCardData(
                            icon: LucideIcons.trendingUp,
                            label: 'CTR',
                            value: '${ctr.toStringAsFixed(1)}%',
                          ),
                          _MetricCardData(
                            icon: LucideIcons.dollarSign,
                            label: 'COST PER CLICK',
                            value: currencyFormat.format(cpc),
                          ),
                          _MetricCardData(
                            icon: LucideIcons.pieChart,
                            label: 'CONVERSION RATE',
                            value: '${convRate.toStringAsFixed(1)}%',
                          ),
                        ], dobar, isDark),

                        const SizedBox(height: 28),

                        // Budget Progress section
                        Text(
                          'BUDGET PROGRESS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: dobar.labelSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: dobar.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? dobar.surfaceElevated
                                  : surfaceDim,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Spend header row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Spend',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: dobar.labelSecondary,
                                        ),
                                      ),
                                      Text(
                                        currencyNoDecimals.format(budgetSpent),
                                        style: TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Space Grotesk',
                                          color: dobar.labelPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      'of ${currencyNoDecimals.format(budgetTotal)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: dobar.labelSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Linear progress (matching Lovable's gradient gold)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: isDark
                                        ? dobar.navBackground
                                        : surfaceDim,
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: budgetPercent.clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        gradient: const LinearGradient(
                                          colors: [
                                            barzGoldGradientStart,
                                            barzGoldGradientEnd,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$budgetPercentText% spent',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: dobar.labelSecondary,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Divider(height: 1),
                              const SizedBox(height: 14),

                              // Sub-stats row - matching Lovable's Wallet/CalendarClock
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          LucideIcons.wallet,
                                          size: 16,
                                          color: barzGold,
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'REMAINING',
                                              style: TextStyle(
                                                fontSize: 10,
                                                letterSpacing: 1,
                                                color: dobar.labelSecondary,
                                              ),
                                            ),
                                            Text(
                                              currencyNoDecimals.format(
                                                remaining,
                                              ),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Space Grotesk',
                                                color: dobar.labelPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          LucideIcons.calendarClock,
                                          size: 16,
                                          color: barzGold,
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'DAILY AVG',
                                              style: TextStyle(
                                                fontSize: 10,
                                                letterSpacing: 1,
                                                color: dobar.labelSecondary,
                                              ),
                                            ),
                                            Text(
                                              currencyFormat.format(dailyAvg),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Space Grotesk',
                                                color: dobar.labelPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGridRow(
    List<_MetricCardData> cards,
    DobarColors dobar,
    bool isDark,
  ) {
    return Row(
      children: cards.map((data) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dobar.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? dobar.surfaceElevated : surfaceDim,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(data.icon, size: 14, color: barzGold),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data.label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: dobar.labelSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Space Grotesk',
                    color: dobar.labelPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MetricCardData {
  final IconData icon;
  final String label;
  final String value;

  const _MetricCardData({
    required this.icon,
    required this.label,
    required this.value,
  });
}