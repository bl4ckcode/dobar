import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/ui/business/widgets/business_toolbars.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import '../bloc/advertising_bloc.dart';
import '../bloc/advertising_event.dart';
import '../bloc/advertising_state.dart';
import '../../domain/models/ad_campaign.dart';

import '../widgets/vip_upsell_banner.dart';
import '../widgets/campaign_card.dart';
import '../widgets/campaign_analytics_sheet.dart';
import '../widgets/create_campaign_sheet.dart';
import '../widgets/subscription_plans_sheet.dart';

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

            return ResponsiveCenterContainer(
              maxWidthPercentage: 0.9,
              maxWidth: 1400,
              padding: EdgeInsets.zero,
              child: RefreshIndicator(
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
                            BusinessStatusToolbar(
                              title: 'Campaigns',
                              subtitle: 'Manage and monitor your marketing campaigns',
                              showStatusToggle: false,
                              showAvatar: false,
                            ),

                            const SizedBox(height: 32),

                            // VIP Banner
                            VipUpsellBanner(
                              onUpgrade: () {
                                final sessionState = context.read<SessionBloc>().state;
                                if (sessionState is SessionReady &&
                                    sessionState.session.activeBar != null) {
                                  SubscriptionPlansSheet.show(
                                    context,
                                    sessionState.session.activeBar!.barId,
                                  );
                                }
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

                    // Campaign Grid
                    if (state.campaigns.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 600,
                                mainAxisExtent: 215,
                                crossAxisSpacing: 24,
                                mainAxisSpacing: 24,
                              ),
                          delegate: SliverChildBuilderDelegate((context, index) {
                            return CampaignCard(
                              campaign: state.campaigns[index],
                              onAnalytics: () => _showCampaignDetails(
                                context,
                                state.campaigns[index],
                              ),
                            );
                          }, childCount: state.campaigns.length),
                        ),
                      ),

                    // Bottom padding safe area for FAB
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: _CreateCampaignFab(
        onPressed: () => _showCreateCampaignDialog(context),
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
            const Icon(LucideIcons.alertTriangle, size: 64, color: errorRed),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: dobar.labelSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCampaigns,
              icon: const Icon(LucideIcons.refreshCw),
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
              LucideIcons.megaphone,
              size: 80,
              color: barzGold.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhuma campanha ativa',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: dobar.labelPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crie sua primeira campanha para\nimpulsionar seu bar!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: dobar.labelSecondary,
              ),
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
              icon: const Icon(LucideIcons.plus),
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

    CreateCampaignSheet.show(context);
  }

  void _showCampaignDetails(BuildContext context, AdCampaign campaign) {
    // Inject the AdvertisingBloc for the sheet since it's a new route tree
    CampaignAnalyticsSheet.show(context, campaign);
  }
}

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
                    color: const Color(
                      0xFFFFD700,
                    ).withValues(alpha: _isHovered ? 0.6 : 0.3),
                    blurRadius: _isHovered ? 24 : 16,
                    spreadRadius: _isHovered ? 4 : 0,
                  ),
                ],
              ),
              child: const Icon(LucideIcons.plus, color: Colors.black, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
