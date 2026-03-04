import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import '../bloc/advertising_bloc.dart';
import '../bloc/advertising_event.dart';
import '../bloc/advertising_state.dart';
import '../../domain/models/ad_campaign.dart';

import '../widgets/vip_upsell_banner.dart';
import '../widgets/campaign_card.dart';
import '../widgets/campaign_analytics_sheet.dart';

/// Campaign management page for bar owners.
///
/// Shows list of campaigns with performance metrics and quick actions.
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
  @override
  void initState() {
    super.initState();
    _loadCampaigns();
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

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;

    return Scaffold(
      backgroundColor: dobar.background,
      body: SafeArea(
        child: BlocBuilder<AdvertisingBloc, AdvertisingState>(
          builder: (context, state) {
            if (state.isLoadingCampaigns && state.campaigns.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: barzGold),
              );
            }
            if (state.error != null && state.campaigns.isEmpty) {
              return _buildErrorState(state.error!);
            }

            return RefreshIndicator(
              onRefresh: () async => _loadCampaigns(),
              color: barzGold,
              backgroundColor: dobar.surface,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Title
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: barzGold.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    BarzRadii.md,
                                  ),
                                  border: Border.all(
                                    color: barzGold.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.campaign,
                                  color: barzGold,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Campaigns',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: dobar.labelPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Manage and monitor your marketing campaigns',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: dobar.labelSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // VIP Banner
                          VipUpsellBanner(
                            onUpgrade: () {
                              // TODO: Handle VIP Upgrade logic
                            },
                          ),

                          const SizedBox(height: 32),

                          // Active Campaigns Header
                          Row(
                            children: [
                              Text(
                                'Active Campaigns',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: dobar.labelPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${state.campaigns.length})',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: dobar.labelSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Campaign List
                  if (state.campaigns.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: CampaignCard(
                              campaign: state.campaigns[index],
                              onAnalytics: () => _showCampaignDetails(
                                context,
                                state.campaigns[index],
                              ),
                            ),
                          );
                        }, childCount: state.campaigns.length),
                      ),
                    ),

                  // Bottom padding safe area for FAB
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateCampaignDialog(context),
        backgroundColor: barzGold,
        foregroundColor: barzDark,
        elevation: 8,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final dobar = context.dobarColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: errorRed),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: dobar.labelSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCampaigns,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final dobar = context.dobarColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 80,
              color: barzGold.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhuma campanha ativa',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: dobar.labelPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crie sua primeira campanha para\nimpulsionar seu bar!',
              textAlign: TextAlign.center,
              style: TextStyle(color: dobar.labelSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showCreateCampaignDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: barzDark,
                foregroundColor: barzGold,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Criar Campanha'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCampaignDialog(BuildContext context) {
    final sessionState = context.read<SessionBloc>().state;
    if (sessionState is! SessionReady ||
        sessionState.session.activeBar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um bar primeiro')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dobarColors.background,
      builder: (ctx) => _CreateCampaignSheet(
        barId: sessionState.session.activeBar!.barId,
        bloc: context.read<AdvertisingBloc>(),
      ),
    );
  }

  void _showCampaignDetails(BuildContext context, AdCampaign campaign) {
    // Inject the AdvertisingBloc for the sheet since it's a new route tree
    CampaignAnalyticsSheet.show(context, campaign);
  }
}

class _CreateCampaignSheet extends StatefulWidget {
  final int barId;
  final AdvertisingBloc bloc;

  const _CreateCampaignSheet({required this.barId, required this.bloc});

  @override
  State<_CreateCampaignSheet> createState() => _CreateCampaignSheetState();
}

class _CreateCampaignSheetState extends State<_CreateCampaignSheet> {
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  CampaignType _selectedType = CampaignType.featured;
  double _budget = 500;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nova Campanha',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome da campanha',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _taglineController,
            decoration: const InputDecoration(
              labelText: 'Tagline (opcional)',
              hintText: 'Ex: Os melhores drinks da cidade!',
              border: OutlineInputBorder(),
            ),
            maxLength: 60,
          ),
          const SizedBox(height: 16),
          const Text(
            'Tipo de campanha',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildTypeChip(CampaignType.featured, 'Destaque', Icons.star),
              _buildTypeChip(CampaignType.search, 'Busca', Icons.search),
              _buildTypeChip(CampaignType.map, 'Mapa', Icons.map),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Orçamento: R\$ ${_budget.toInt()}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _budget,
            min: 100,
            max: 5000,
            divisions: 49,
            activeColor: barzGold,
            onChanged: (v) => setState(() => _budget = v),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isCreating ? null : _createCampaign,
              style: FilledButton.styleFrom(
                backgroundColor: barzDark,
                foregroundColor: barzGold,
                padding: const EdgeInsets.all(16),
              ),
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: barzGold,
                      ),
                    )
                  : const Text('Criar Campanha'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(CampaignType value, String label, IconData icon) {
    final isSelected = _selectedType == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(label)],
      ),
      selected: isSelected,
      selectedColor: barzGold,
      onSelected: (_) => setState(() => _selectedType = value),
    );
  }

  void _createCampaign() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o nome da campanha')),
      );
      return;
    }

    setState(() => _isCreating = true);

    final request = CreateCampaignRequest(
      barId: widget.barId,
      name: _nameController.text.trim(),
      campaignType: _selectedType,
      budgetType: BudgetType.cash,
      budgetAmount: _budget,
      startDate: DateTime.now(),
      creative: _taglineController.text.isNotEmpty
          ? CampaignCreative(tagline: _taglineController.text.trim())
          : null,
    );

    widget.bloc.add(AdvertisingEvent.createCampaign(request: request));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Campanha "${_nameController.text}" criada!')),
    );
  }
}
