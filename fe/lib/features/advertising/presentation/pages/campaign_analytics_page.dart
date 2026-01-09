import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/l10n/app_localizations.dart';
import '../bloc/advertising_bloc.dart';
import '../bloc/advertising_event.dart';
import '../bloc/advertising_state.dart';
import '../../domain/models/campaign_analytics.dart';

class CampaignAnalyticsPage extends StatelessWidget {
  final int campaignId;

  const CampaignAnalyticsPage({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getItInjector<AdvertisingBloc>()
        ..add(LoadAnalytics(campaignId: campaignId)),
      child: _CampaignAnalyticsContent(campaignId: campaignId),
    );
  }
}

class _CampaignAnalyticsContent extends StatelessWidget {
  final int campaignId;

  const _CampaignAnalyticsContent({required this.campaignId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.analytics),
        backgroundColor: barzDark,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: barzGoldSoft,
        child: BlocBuilder<AdvertisingBloc, AdvertisingState>(
          builder: (context, state) {
            if (state.isLoadingAnalytics) {
              return const Center(
                child: CircularProgressIndicator(color: barzGold),
              );
            }
            if (state.error != null) {
              return _buildErrorState(context, state.error!);
            }
            if (state.analytics == null) {
              return _buildEmptyState(l10n);
            }
            return _buildContent(context, state.analytics!, l10n);
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: errorRed),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.read<AdvertisingBloc>().add(
                LoadAnalytics(campaignId: campaignId),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: barzGold.withValues(alpha: 0.6)),
          const SizedBox(height: 24),
          Text(l10n.no_data_available, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, CampaignAnalytics analytics, AppLocalizations l10n) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<AdvertisingBloc>().add(LoadAnalytics(campaignId: campaignId));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(analytics),
            const SizedBox(height: 24),
            _buildMetricsGrid(analytics.metrics, l10n),
            const SizedBox(height: 24),
            _buildBudgetCard(analytics.budget, l10n),
            const SizedBox(height: 24),
            _buildDailyChart(analytics.dailyBreakdown, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(CampaignAnalytics analytics) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BarzRadii.md)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: barzGold,
                borderRadius: BorderRadius.circular(BarzRadii.sm),
              ),
              child: const Icon(Icons.campaign, color: barzDark),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analytics.campaignName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatusBadge(status: analytics.status),
                      const SizedBox(width: 8),
                      Text(
                        analytics.campaignType.toUpperCase(),
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(CampaignMetrics metrics, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.performance, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _MetricCard(
              icon: Icons.visibility,
              label: l10n.impressions,
              value: _formatNumber(metrics.impressions),
            )),
            const SizedBox(width: 12),
            Expanded(child: _MetricCard(
              icon: Icons.touch_app,
              label: l10n.clicks,
              value: _formatNumber(metrics.clicks),
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _MetricCard(
              icon: Icons.shopping_bag,
              label: l10n.conversions,
              value: _formatNumber(metrics.conversions),
            )),
            const SizedBox(width: 12),
            Expanded(child: _MetricCard(
              icon: Icons.percent,
              label: 'CTR',
              value: '${metrics.ctr.toStringAsFixed(2)}%',
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _MetricCard(
              icon: Icons.attach_money,
              label: l10n.cost_per_click,
              value: 'R\$ ${metrics.costPerClick.toStringAsFixed(2)}',
            )),
            const SizedBox(width: 12),
            Expanded(child: _MetricCard(
              icon: Icons.trending_up,
              label: l10n.conversion_rate,
              value: '${metrics.conversionRate.toStringAsFixed(1)}%',
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildBudgetCard(BudgetBreakdown budget, AppLocalizations l10n) {
    final progress = budget.total > 0 ? (budget.spent / budget.total).clamp(0.0, 1.0) : 0.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BarzRadii.md)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.budget, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('R\$ ${budget.spent.toStringAsFixed(0)} / R\$ ${budget.total.toStringAsFixed(0)}'),
                Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: surfaceMuted,
                valueColor: AlwaysStoppedAnimation(progress > 0.9 ? warningOrange : barzGold),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BudgetStat(label: l10n.remaining, value: 'R\$ ${budget.remaining.toStringAsFixed(0)}'),
                _BudgetStat(label: l10n.daily_average, value: 'R\$ ${budget.dailyAverage.toStringAsFixed(0)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyChart(List<DailyMetrics> daily, AppLocalizations l10n) {
    if (daily.isEmpty) return const SizedBox.shrink();

    final maxImpressions = daily.map((d) => d.impressions).reduce((a, b) => a > b ? a : b);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BarzRadii.md)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.daily_breakdown, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: daily.take(7).map((d) {
                  final height = maxImpressions > 0
                      ? (d.impressions / maxImpressions) * 120
                      : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            d.impressions.toString(),
                            style: const TextStyle(fontSize: 10),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: height.clamp(4.0, 120.0),
                            decoration: BoxDecoration(
                              color: barzGold,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d.date.substring(5),
                            style: const TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? successGreen.withValues(alpha: 0.15) : surfaceMuted,
        borderRadius: BorderRadius.circular(BarzRadii.full),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isActive ? successGreen : textSecondary,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BarzRadii.md)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: barzGold, size: 24),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _BudgetStat extends StatelessWidget {
  final String label;
  final String value;

  const _BudgetStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: textSecondary)),
      ],
    );
  }
}
