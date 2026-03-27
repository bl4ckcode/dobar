import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/l10n/app_localizations.dart';
import '../bloc/advertising_bloc.dart';
import '../bloc/advertising_event.dart';
import '../bloc/advertising_state.dart';
import '../../domain/models/campaign_analytics.dart';
import 'package:collection/collection.dart';
import '../../domain/models/ad_campaign.dart';

class CampaignAnalyticsPage extends StatelessWidget {
  final int campaignId;
  final int barId;

  const CampaignAnalyticsPage({
    super.key,
    required this.campaignId,
    required this.barId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getItInjector<AdvertisingBloc>()
            ..add(LoadAnalytics(campaignId: campaignId, barId: barId)),
      child: _CampaignAnalyticsContent(campaignId: campaignId, barId: barId),
    );
  }
}

class _CampaignAnalyticsContent extends StatelessWidget {
  final int campaignId;
  final int barId;

  const _CampaignAnalyticsContent({
    required this.campaignId,
    required this.barId,
  });

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
            return _buildContent(context, state, l10n);
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
                LoadAnalytics(campaignId: campaignId, barId: barId),
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
          Icon(
            Icons.analytics_outlined,
            size: 80,
            color: barzGold.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 24),
          Text(l10n.no_data_available, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AdvertisingState state,
    AppLocalizations l10n,
  ) {
    final analytics = state.analytics!;
    final campaign = state.campaigns.firstWhereOrNull(
      (c) => c.id == campaignId,
    );

    return RefreshIndicator(
      onRefresh: () async {
        context.read<AdvertisingBloc>().add(
          LoadAnalytics(campaignId: campaignId, barId: barId),
        );
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(analytics, campaign),
            const SizedBox(height: 24),
            _buildMetricsGrid(analytics, l10n),
            const SizedBox(height: 24),
            _buildBudgetCard(analytics, campaign, l10n),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(CampaignAnalytics analytics, AdCampaign? campaign) {
    final status = campaign?.status.name ?? 'active';
    final typeName = campaign != null
        ? campaign.campaignType.name.toUpperCase()
        : 'UNKNOWN';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
      ),
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatusBadge(status: status),
                      const SizedBox(width: 8),
                      Text(
                        typeName,
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

  Widget _buildMetricsGrid(CampaignAnalytics analytics, AppLocalizations l10n) {
    final conversionRate = analytics.clicks > 0
        ? (analytics.conversions / analytics.clicks) * 100
        : 0.0;
    final costPerClick = analytics.clicks > 0
        ? analytics.spend / analytics.clicks
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.performance,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    icon: Icons.visibility,
                    label: l10n.impressions,
                    value: _formatNumber(analytics.impressions),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    icon: Icons.touch_app,
                    label: l10n.clicks,
                    value: _formatNumber(analytics.clicks),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    icon: Icons.shopping_bag,
                    label: l10n.conversions,
                    value: _formatNumber(analytics.conversions),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    icon: Icons.percent,
                    label: 'CTR',
                    value: '${analytics.ctr.toStringAsFixed(2)}%',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    icon: Icons.attach_money,
                    label: l10n.cost_per_click,
                    value: 'R\$ ${costPerClick.toStringAsFixed(2)}',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    icon: Icons.trending_up,
                    label: l10n.conversion_rate,
                    value: '${conversionRate.toStringAsFixed(1)}%',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBudgetCard(
    CampaignAnalytics analytics,
    AdCampaign? campaign,
    AppLocalizations l10n,
  ) {
    final total = campaign?.budgetAmount ?? analytics.spend;
    final progress = total > 0
        ? (analytics.spend / total).clamp(0.0, 1.0)
        : 0.0;
    final remaining = (total - analytics.spend).clamp(0.0, double.infinity);
    final days = analytics.periodEnd.difference(analytics.periodStart).inDays;
    final dailyAverage = days > 0 ? analytics.spend / days : analytics.spend;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.budget,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'R\$ ${analytics.spend.toStringAsFixed(0)} / R\$ ${total.toStringAsFixed(0)}',
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: surfaceMuted,
                valueColor: AlwaysStoppedAnimation(
                  progress > 0.9 ? warningOrange : barzGold,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BudgetStat(
                  label: l10n.remaining,
                  value: 'R\$ ${remaining.toStringAsFixed(0)}',
                ),
                _BudgetStat(
                  label: l10n.daily_average,
                  value: 'R\$ ${dailyAverage.toStringAsFixed(0)}',
                ),
              ],
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

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: barzGold, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
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
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: textSecondary)),
      ],
    );
  }
}
