import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import '../bloc/advertising_bloc.dart';
import '../bloc/advertising_event.dart';
import '../bloc/advertising_state.dart';
import '../../domain/models/ad_campaign.dart';

import 'package:barz/l10n/app_localizations.dart';

import '../widgets/campaign_card.dart';
import '../widgets/campaign_analytics_sheet.dart';
import '../widgets/multi_step_campaign_sheet.dart';
import '../widgets/subscription_plans_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const List<_FilterOption> _filterOptions = [
  _FilterOption('all', 'Todas'),
  _FilterOption('active', 'Ativas'),
  _FilterOption('paused', 'Pausadas'),
  _FilterOption('completed', 'Concluídas'),
  _FilterOption('draft', 'Rascunhos'),
];

const List<_SortOption> _sortOptions = [
  _SortOption('recent', 'Mais recentes'),
  _SortOption('budget-desc', 'Orçamento (maior)'),
  _SortOption('budget-asc', 'Orçamento (menor)'),
  _SortOption('performance', 'Performance'),
];

const String _defaultSort = 'recent';

// ─────────────────────────────────────────────────────────────────────────────
// Data helpers
// ─────────────────────────────────────────────────────────────────────────────

String _formatBrl(double amount) {
  return 'R\$ ${amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)}'
      .replaceAll('.', ',');
}

String _formatCompact(int number) {
  if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(1)}M';
  } else if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(number >= 10000 ? 0 : 1)}k';
  }
  return number.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter & Sort models
// ─────────────────────────────────────────────────────────────────────────────

class _FilterOption {
  final String id;
  final String label;
  const _FilterOption(this.id, this.label);
}

class _SortOption {
  final String id;
  final String label;
  const _SortOption(this.id, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
// Filtering & Sorting logic
// ─────────────────────────────────────────────────────────────────────────────

List<AdCampaign> _filterCampaigns(
  List<AdCampaign> campaigns,
  String? filterStatus,
  String searchQuery,
  String? sortBy,
) {
  var list = campaigns;

  // Filter by status
  if (filterStatus != null && filterStatus != 'all') {
    list = list.where((c) => _statusForFilter(c) == filterStatus).toList();
  }

  // Filter by search query
  if (searchQuery.isNotEmpty) {
    final q = searchQuery.toLowerCase();
    list = list.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  // Sort
  final sorted = List<AdCampaign>.from(list);
  switch (sortBy ?? _defaultSort) {
    case 'budget-desc':
      sorted.sort((a, b) => b.budgetAmount.compareTo(a.budgetAmount));
    case 'budget-asc':
      sorted.sort((a, b) => a.budgetAmount.compareTo(b.budgetAmount));
    case 'performance':
      sorted.sort((a, b) {
        final ctrA =
            a.impressions > 0 ? a.clicks / a.impressions : 0.0;
        final ctrB =
            b.impressions > 0 ? b.clicks / b.impressions : 0.0;
        return ctrB.compareTo(ctrA);
      });
    default:
      // 'recent' - keep natural order (most recent first)
      break;
  }

  return sorted;
}

String _statusForFilter(AdCampaign c) {
  return switch (c.status) {
    CampaignStatus.active => 'active',
    CampaignStatus.paused => 'paused',
    CampaignStatus.completed => 'completed',
    CampaignStatus.pending => 'draft',
    CampaignStatus.cancelled => 'completed',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Aggregated totals
// ─────────────────────────────────────────────────────────────────────────────

class _CampaignTotals {
  final int impressions;
  final int clicks;
  final double spent;
  final double ctr;

  const _CampaignTotals({
    required this.impressions,
    required this.clicks,
    required this.spent,
    required this.ctr,
  });

  factory _CampaignTotals.from(List<AdCampaign> campaigns) {
    final impressions = campaigns.fold<int>(0, (s, c) => s + c.impressions);
    final clicks = campaigns.fold<int>(0, (s, c) => s + c.clicks);
    final spent = campaigns.fold<double>(0, (s, c) => s + c.budgetSpent);
    final ctr = impressions > 0 ? (clicks / impressions) * 100 : 0.0;
    return _CampaignTotals(
      impressions: impressions,
      clicks: clicks,
      spent: spent,
      ctr: ctr,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMPAIGNS PAGE
// ─────────────────────────────────────────────────────────────────────────────

/// Campaign management page for bar owners.
///
/// Shows list of campaigns with performance metrics and quick actions.
/// Refactored to match the React Native design spec (DOB-77).
class CampaignsPage extends StatelessWidget {
  const CampaignsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getItInjector<AdvertisingBloc>(),
      child: const _CampaignsPageContent(),
    );
  }
}

class _CampaignsPageContent extends StatefulWidget {
  const _CampaignsPageContent();

  @override
  State<_CampaignsPageContent> createState() => _CampaignsPageContentState();
}

class _CampaignsPageContentState extends State<_CampaignsPageContent> {
  final _searchController = TextEditingController();
  bool _showVipBanner = true;

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCampaigns() {
    final sessionState = context.read<SessionBloc>().state;
    if (sessionState is SessionReady &&
        sessionState.session.activeBar != null) {
      context.read<AdvertisingBloc>().add(
        LoadCampaigns(barId: sessionState.session.activeBar!.barId),
      );
    }
  }

  void _onSearchChanged(String value) {
    context.read<AdvertisingBloc>().add(SetSearch(query: value));
  }

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;

    return Scaffold(
      backgroundColor: dobar.background,
      body: SafeArea(
        child: BlocBuilder<AdvertisingBloc, AdvertisingState>(
          builder: (context, state) {
            final isLoading = state.isLoadingCampaigns && state.campaigns.isEmpty;
            final hasError = state.error != null && state.campaigns.isEmpty;

            // Apply local filtering/sorting
            final filteredCampaigns = _filterCampaigns(
              state.campaigns,
              state.filterStatus,
              state.searchQuery,
              state.sortBy,
            );
            final totals = _CampaignTotals.from(state.campaigns);

            return Stack(
              children: [
                // Ambient glow (top gradient)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 420,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.8, -0.5),
                          radius: 0.8,
                          colors: [
                            barzGold.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Floating action button (New Campaign)
                Positioned(
                  right: 24,
                  bottom: 32,
                  child: _CreateCampaignFab(
                    onPressed: () => _showCreateCampaignDialog(context),
                  ),
                ),

                // Main scrollable content
                if (isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: barzGold),
                  )
                else if (hasError)
                  _buildErrorState(state.error!)
                else
                  RefreshIndicator(
                    onRefresh: () async => _loadCampaigns(),
                    color: barzGold,
                    backgroundColor: dobar.surface,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // Main content padding
                        const SliverPadding(
                          padding: EdgeInsets.only(top: 32),
                        ),

                        // Header section
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeader(context, dobar, state),
                              ],
                            ),
                          ),
                        ),

                        // VIP Upsell Banner
                        if (_showVipBanner)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 24,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: _buildVipBanner(context, dobar),
                            ),
                          )
                        else
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 24),
                          ),

                        // Filters & Actions bar
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _buildFiltersAndActions(context, state, dobar),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 24)),

                        // Campaign List
                        if (filteredCampaigns.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyState(
                              context,
                              dobar,
                              state.campaigns.isNotEmpty,
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final campaign = filteredCampaigns[index];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: index < filteredCampaigns.length - 1
                                          ? 16
                                          : 0,
                                    ),
                                    child: CampaignCard(
                                      campaign: campaign,
                                      onAnalytics: () =>
                                          _showCampaignDetails(
                                        context,
                                        campaign,
                                      ),
                                      onToggle: () =>
                                          _toggleCampaign(campaign),
                                      onDelete: () =>
                                          _deleteCampaign(campaign),
                                      onDuplicate: () =>
                                          _duplicateCampaign(campaign),
                                    ),
                                  );
                                },
                                childCount: filteredCampaigns.length,
                              ),
                            ),
                          ),

                        // Analytics Overview Section
                        if (state.campaigns.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 32,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: _buildAnalyticsOverview(
                                context,
                                dobar,
                                totals,
                              ),
                            ),
                          ),

                        // Bottom padding
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 120),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    DobarColors dobar,
    AdvertisingState state,
  ) {
    return Row(
      children: [
        // Megaphone icon + title — matching Lovable design
        Expanded(
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFFDF), Color(0xFFFFDE59)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: barzGold.withValues(alpha: 0.55),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.megaphone,
                  size: 24,
                  color: Color(0xFF0A0A0A),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Campanhas',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Space Grotesk',
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gerencie suas campanhas de marketing',
                      style: TextStyle(
                        fontSize: 14,
                        color: dobar.labelSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Balance chip
        _BalanceChip(),
      ],
    );
  }

  // ─── VIP Banner ──────────────────────────────────────────────────────────

  Widget _buildVipBanner(BuildContext context, DobarColors dobar) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: barzGold.withValues(alpha: 0.25),
        ),
        gradient: LinearGradient(
          colors: [
            barzGold.withValues(alpha: 0.06),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: barzGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: barzGold.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              LucideIcons.crown,
              size: 20,
              color: barzGold,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Desbloqueie o Barz VIP',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Créditos mensais, prioridade nos destaques e relatórios avançados.',
                  style: TextStyle(
                    fontSize: 12,
                    color: dobar.labelSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              final sessionState = context.read<SessionBloc>().state;
              if (sessionState is SessionReady &&
                  sessionState.session.activeBar != null) {
                SubscriptionPlansSheet.show(
                  context,
                  sessionState.session.activeBar!.barId,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: barzGold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'VIP',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0A0A0A),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _showVipBanner = false),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                LucideIcons.x,
                size: 16,
                color: dobar.labelSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Filters & Actions ────────────────────────────────────────────────────

  Widget _buildFiltersAndActions(
    BuildContext context,
    AdvertisingState state,
    DobarColors dobar,
  ) {
    final bloc = context.read<AdvertisingBloc>();
    final currentFilter = state.filterStatus ?? 'all';
    final currentSort = state.sortBy ?? _defaultSort;

    return Column(
      children: [
        // Search + Create button row
        Row(
          children: [
            // Search input
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: barzDarkLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2C2C2C)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar campanhas...',
                    hintStyle: TextStyle(
                      color: dobar.labelSecondary,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      LucideIcons.search,
                      size: 16,
                      color: dobar.labelSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Sort dropdown
            _SortDropdown(
              currentSort: currentSort,
              onChanged: (value) => bloc.add(SetSort(sortBy: value)),
            ),
            const SizedBox(width: 12),
            // Create campaign button
            GestureDetector(
              onTap: () => _showCreateCampaignDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFFDF), Color(0xFFFFDE59), Color(0xFFFFC000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: barzGold.withValues(alpha: 0.55),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.plus,
                      size: 16,
                      color: Color(0xFF0A0A0A),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Nova Campanha',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0A0A0A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Filter chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filterOptions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final option = _filterOptions[index];
              final isActive = currentFilter == option.id;
              return GestureDetector(
                onTap: () {
                  bloc.add(
                    SetFilter(
                      status: option.id == 'all' ? null : option.id,
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? barzGold.withValues(alpha: 0.1)
                        : barzDarkLight,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: isActive
                          ? barzGold.withValues(alpha: 0.4)
                          : const Color(0xFF2C2C2C),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? Colors.white
                              : dobar.labelSecondary,
                        ),
                      ),
                      if (isActive)
                        Positioned(
                          bottom: -4,
                          left: 16,
                          right: 16,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: barzGold,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: barzGold.withValues(alpha: 0.7),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Error State ──────────────────────────────────────────────────────────

  Widget _buildErrorState(String error) {
    final dobar = context.dobarColors;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.alertTriangle, size: 64, color: errorRed),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: dobar.labelSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCampaigns,
              icon: const Icon(LucideIcons.refreshCw),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(
    BuildContext context,
    DobarColors dobar,
    bool hasCampaigns,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated floating icon
            _AnimatedMegaphone(),
            const SizedBox(height: 24),
            Text(
              hasCampaigns
                  ? 'Nenhuma campanha encontrada'
                  : 'Nenhuma campanha ainda',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Space Grotesk',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasCampaigns
                  ? 'Tente ajustar os filtros ou o termo de busca.'
                  : 'Crie sua primeira campanha para aparecer em destaque\npara milhares de clientes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: dobar.labelSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => _showCreateCampaignDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFFDF), Color(0xFFFFDE59), Color(0xFFFFC000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: barzGold.withValues(alpha: 0.55),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.plus,
                      size: 16,
                      color: Color(0xFF0A0A0A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasCampaigns
                          ? 'Criar Campanha'
                          : 'Criar Primeira Campanha',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0A0A0A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Analytics Overview ───────────────────────────────────────────────────

  Widget _buildAnalyticsOverview(
    BuildContext context,
    DobarColors dobar,
    _CampaignTotals totals,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: barzDarkLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: barzGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: barzGold.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  LucideIcons.barChart3,
                  size: 16,
                  color: barzGold,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Visão geral de performance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Últimos 30 dias, todas as campanhas',
                    style: TextStyle(
                      fontSize: 12,
                      color: dobar.labelSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Metric cards
          LayoutBuilder(
            builder: (context, constraints) {
              // Responsive: 2 columns on narrow, 4 on wide
              final isWide = constraints.maxWidth > 500;
              final crossAxisCount = isWide ? 4 : 2;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: isWide ? 2.0 : 2.5,
                children: [
                  _StatCard(
                    icon: LucideIcons.eye,
                    label: 'Impressões',
                    value: _formatCompact(totals.impressions),
                    isGold: true,
                  ),
                  _StatCard(
                    icon: LucideIcons.mousePointerClick,
                    label: 'Cliques',
                    value: _formatCompact(totals.clicks),
                  ),
                  _StatCard(
                    icon: LucideIcons.trendingUp,
                    label: 'CTR médio',
                    value: '${totals.ctr.toStringAsFixed(2)}%',
                  ),
                  _StatCard(
                    icon: LucideIcons.dollarSign,
                    label: 'Total investido',
                    value: _formatBrl(totals.spent),
                    isGold: true,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  void _toggleCampaign(AdCampaign campaign) {
    final bloc = context.read<AdvertisingBloc>();
    if (campaign.status == CampaignStatus.active) {
      bloc.add(PauseCampaign(campaignId: campaign.id));
    } else if (campaign.status == CampaignStatus.paused) {
      bloc.add(ResumeCampaign(campaignId: campaign.id));
    }
  }

  void _deleteCampaign(AdCampaign campaign) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: barzDarkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2C2C2C)),
        ),
        title: const Text(
          'Excluir campanha?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Tem certeza que deseja excluir "${campaign.name}"? Esta ação não pode ser desfeita.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // For now just show success - actual delete endpoint TBD
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Campanha excluída')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: errorRed),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _duplicateCampaign(AdCampaign campaign) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Duplicando ${campaign.name}...')),
    );
    // TODO: Implement actual duplication via bloc when endpoint is ready
  }

  void _showCreateCampaignDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sessionState = context.read<SessionBloc>().state;
    if (sessionState is! SessionReady ||
        sessionState.session.activeBar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.campaigns_select_bar_error)),
      );
      return;
    }

    MultiStepCampaignSheet.show(context);
  }

  void _showCampaignDetails(BuildContext context, AdCampaign campaign) {
    CampaignAnalyticsSheet.show(context, campaign);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

/// Animated megaphone icon for empty state.
class _AnimatedMegaphone extends StatefulWidget {
  @override
  State<_AnimatedMegaphone> createState() => _AnimatedMegaphoneState();
}

class _AnimatedMegaphoneState extends State<_AnimatedMegaphone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnimation = Tween(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: RadialGradient(
                center: const Alignment(0.3, 0.3),
                colors: [
                  barzGold.withValues(alpha: 0.35),
                  barzGold.withValues(alpha: 0.05),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: barzGold.withValues(alpha: 0.4),
                  blurRadius: 50,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: const Icon(
              LucideIcons.megaphone,
              size: 48,
              color: barzGold,
            ),
          ),
        );
      },
    );
  }
}

/// Balance chip showing available budget.
class _BalanceChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: barzDarkLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: barzGold.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: barzGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: barzGold.withValues(alpha: 0.4)),
            ),
            child: const Icon(
              LucideIcons.wallet,
              size: 16,
              color: barzGold,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Saldo',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                  color: dobar.labelSecondary,
                ),
              ),
              const Text(
                'R\$ 1.200,00',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: barzGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: barzGold.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.plus,
                  size: 12,
                  color: barzGold,
                ),
                SizedBox(width: 4),
                Text(
                  'Adicionar',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: barzGold,
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

/// Sort dropdown button.
class _SortDropdown extends StatelessWidget {
  final String currentSort;
  final ValueChanged<String> onChanged;

  const _SortDropdown({
    required this.currentSort,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentLabel =
        _sortOptions.firstWhere((o) => o.id == currentSort).label;

    return PopupMenuButton<String>(
      offset: const Offset(0, 44),
      color: barzDarkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF2C2C2C)),
      ),
      onSelected: onChanged,
      itemBuilder: (context) => _sortOptions.map((option) {
        return PopupMenuItem(
          value: option.id,
          child: Text(
            option.label,
            style: TextStyle(
              fontSize: 13,
              color: option.id == currentSort ? barzGold : Colors.white,
            ),
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: barzDarkLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2C2C2C)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.sparkles,
              size: 16,
              color: barzGold,
            ),
            const SizedBox(width: 8),
            Text(
              currentLabel,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: context.dobarColors.labelSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Stat card for analytics overview.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isGold;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.isGold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: barzDarkLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: isGold ? barzGold : context.dobarColors.labelSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: context.dobarColors.labelSecondary,
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
              color: isGold ? barzGold : Colors.white,
              fontFamily: 'Space Grotesk',
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating action button for creating campaigns.
class _CreateCampaignFab extends StatefulWidget {
  final VoidCallback onPressed;

  const _CreateCampaignFab({required this.onPressed});

  @override
  State<_CreateCampaignFab> createState() => _CreateCampaignFabState();
}

class _CreateCampaignFabState extends State<_CreateCampaignFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _isPressed ? 0.95 : (_isHovered ? 1.08 : 1.0),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [barzGoldGradientStart, barzGoldGradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: barzGold.withValues(alpha: _isHovered ? 0.35 : 0.2),
                    blurRadius: _isHovered ? 30 : 16,
                    spreadRadius: _isHovered ? 4 : 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.plus,
                color: Colors.black,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}