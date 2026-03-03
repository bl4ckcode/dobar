import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import '../bloc/advertising_bloc.dart';
import '../bloc/advertising_event.dart';
import '../bloc/advertising_state.dart';
import '../../domain/models/ad_campaign.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campanhas'),
        backgroundColor: barzDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nova Campanha',
            onPressed: () => _showCreateCampaignDialog(context),
          ),
        ],
      ),
      body: Container(
        color: barzGoldSoft,
        child: BlocBuilder<AdvertisingBloc, AdvertisingState>(
          builder: (context, state) {
            if (state.isLoadingCampaigns) {
              return const Center(
                child: CircularProgressIndicator(color: barzGold),
              );
            }
            if (state.error != null) {
              return _buildErrorState(state.error!);
            }
            if (state.campaigns.isEmpty) {
              return _buildEmptyState();
            }
            return RefreshIndicator(
              onRefresh: () async => _loadCampaigns(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.campaigns.length,
                itemBuilder: (context, index) {
                  return _CampaignCard(
                    campaign: state.campaigns[index],
                    onTap: () =>
                        _showCampaignDetails(context, state.campaigns[index]),
                    onPause: () =>
                        _toggleCampaignStatus(state.campaigns[index]),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateCampaignDialog(context),
        backgroundColor: barzGold,
        foregroundColor: barzDark,
        icon: const Icon(Icons.add),
        label: const Text('Nova Campanha'),
      ),
    );
  }

  Widget _buildErrorState(String error) {
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
              style: TextStyle(color: textSecondary),
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
            const Text(
              'Nenhuma campanha ativa',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crie sua primeira campanha para\nimpulsionar seu bar!',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary),
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
      builder: (ctx) => _CreateCampaignSheet(
        barId: sessionState.session.activeBar!.barId,
        bloc: context.read<AdvertisingBloc>(),
      ),
    );
  }

  void _showCampaignDetails(BuildContext context, AdCampaign campaign) {
    context.push('/business/campaign/${campaign.id}/analytics');
  }

  void _toggleCampaignStatus(AdCampaign campaign) {
    final bloc = context.read<AdvertisingBloc>();
    if (campaign.status == CampaignStatus.active) {
      bloc.add(PauseCampaign(campaignId: campaign.id));
    } else if (campaign.status == CampaignStatus.paused) {
      bloc.add(ResumeCampaign(campaignId: campaign.id));
    }
  }
}

class _CampaignCard extends StatelessWidget {
  final AdCampaign campaign;
  final VoidCallback? onTap;
  final VoidCallback? onPause;

  const _CampaignCard({required this.campaign, this.onTap, this.onPause});

  @override
  Widget build(BuildContext context) {
    final isActive = campaign.status == CampaignStatus.active;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildTypeBadge(),
                      ],
                    ),
                  ),
                  _buildStatusChip(isActive),
                ],
              ),
              const SizedBox(height: 16),
              // Metrics row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetric('Impressões', campaign.impressions.toString()),
                  _buildMetric('Cliques', campaign.clicks.toString()),
                  _buildMetric(
                    'CTR',
                    '${((campaign.clicks / (campaign.impressions == 0 ? 1 : campaign.impressions)) * 100).toStringAsFixed(1)}%',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Budget progress
              _buildBudgetProgress(),
              const SizedBox(height: 12),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onPause,
                    icon: Icon(isActive ? Icons.pause : Icons.play_arrow),
                    label: Text(isActive ? 'Pausar' : 'Retomar'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.analytics),
                    label: const Text('Analytics'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge() {
    final typeLabels = {
      CampaignType.featured: ('Destaque', Icons.star),
      CampaignType.search: ('Busca', Icons.search),
      CampaignType.map: ('Mapa', Icons.map),
      CampaignType.promoBoost: ('Promoção', Icons.local_offer),
      CampaignType.banner: ('Banner', Icons.view_carousel),
    };
    final (label, icon) =
        typeLabels[campaign.campaignType] ?? ('Outro', Icons.campaign);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: barzGoldLight,
        borderRadius: BorderRadius.circular(BarzRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: barzDark),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: barzDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? successGreen.withValues(alpha: 0.15) : surfaceMuted,
        borderRadius: BorderRadius.circular(BarzRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? successGreen : textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Ativa' : campaign.status.name.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? successGreen : textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: textSecondary)),
      ],
    );
  }

  Widget _buildBudgetProgress() {
    final progress = campaign.budgetAmount > 0
        ? (campaign.budgetSpent / campaign.budgetAmount).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Orçamento',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
            Text(
              'R\$ ${campaign.budgetSpent.toStringAsFixed(0)} / R\$ ${campaign.budgetAmount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: surfaceMuted,
            valueColor: AlwaysStoppedAnimation(
              progress > 0.9 ? warningOrange : barzGold,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
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
