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
                    ..add(LoadAnalytics(campaignId: campaign.id)),
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

    if (isActive) {
      statusColor = successGreen;
      statusBg = successGreen.withValues(alpha: 0.15);
    } else if (isPaused) {
      statusColor = warningOrange;
      statusBg = warningOrange.withValues(alpha: 0.15);
    } else {
      statusBg = dobar.navBackground;
    }

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
      decoration: BoxDecoration(
        color: dobar.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: dobar.surfaceElevated, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
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
                color: dobar.surfaceElevated,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                // Header
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
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: dobar.labelPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
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
                                    color: statusColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isActive) ...[
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
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: dobar.navBackground,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: dobar.surfaceElevated,
                                  ),
                                ),
                                child: Text(
                                  widget.campaign.campaignType.name,
                                  style: TextStyle(
                                    fontSize: 12,
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
                        backgroundColor: dobar.navBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

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
                        Text(
                          'PERFORMANCE METRICS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: dobar.labelSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.2,
                          children: [
                            _MetricCard(
                              icon: LucideIcons.eye,
                              label: 'IMPRESSIONS',
                              value: _formatNumber(imp),
                              dobar: dobar,
                            ),
                            _MetricCard(
                              icon: LucideIcons.mousePointerClick,
                              label: 'CLICKS',
                              value: _formatNumber(clk),
                              dobar: dobar,
                            ),
                            _MetricCard(
                              icon: LucideIcons.tag,
                              label: 'CONVERSIONS',
                              value: _formatNumber(convs),
                              dobar: dobar,
                            ),
                            _MetricCard(
                              icon: LucideIcons.trendingUp,
                              label: 'CTR',
                              value: '${ctr.toStringAsFixed(1)}%',
                              dobar: dobar,
                            ),
                            _MetricCard(
                              icon: LucideIcons.dollarSign,
                              label: 'COST PER CLICK',
                              value: currencyFormat.format(cpc),
                              dobar: dobar,
                            ),
                            _MetricCard(
                              icon: LucideIcons.pieChart,
                              label: 'CONVERSION RATE',
                              value: '${convRate.toStringAsFixed(1)}%',
                              dobar: dobar,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'BUDGET PROGRESS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: dobar.labelSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: dobar.background,
                            borderRadius: BorderRadius.circular(BarzRadii.md),
                            border: Border.all(color: dobar.surfaceElevated),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'SF Pro Display',
                                          color: dobar.labelPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
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
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: budgetPercent,
                                  minHeight: 8,
                                  backgroundColor: dobar.navBackground,
                                  valueColor: const AlwaysStoppedAnimation(
                                    barzGold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$budgetPercentText% spent',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: dobar.labelSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.account_balance_wallet,
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
                                        const Icon(
                                          Icons.calendar_month,
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
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final DobarColors dobar;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.dobar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dobar.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dobar.surfaceElevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: barzGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: dobar.labelSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'SF Pro Display',
              color: dobar.labelPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
