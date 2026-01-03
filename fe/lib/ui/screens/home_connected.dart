import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/ui/primitives/barz_app_bar.dart';
import 'package:barz/ui/primitives/barz_card.dart';
import 'package:barz/features/bars/presentation/bloc/bar_bloc.dart';
import 'package:barz/features/bars/presentation/bloc/bar_event.dart';
import 'package:barz/features/bars/presentation/bloc/bar_state.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_bloc.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_event.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_state.dart';

class HomeConnected extends StatelessWidget {
  const HomeConnected({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getItInjector<BarBloc>()..add(const LoadNearbyBars(lat: -23.5505, lng: -46.6333)),
        ),
        BlocProvider(
          create: (_) => getItInjector<PromotionsBloc>()..add(LoadPromotions()),
        ),
      ],
      child: const _HomeConnectedView(),
    );
  }
}

class _HomeConnectedView extends StatelessWidget {
  const _HomeConnectedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarzAppBar(title: 'Home'),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home_create_bar_fab',
        onPressed: () => context.push('/create-bar'),
        backgroundColor: barzBlack,
        icon: const Icon(Icons.add, color: barzYellow),
        label: const Text('Create Bar', style: TextStyle(color: barzYellow)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: yellowBackgroundGradient),
        child: RefreshIndicator(
          onRefresh: () async {
            context.read<BarBloc>().add(const LoadNearbyBars(lat: -23.5505, lng: -46.6333));
            context.read<PromotionsBloc>().add(LoadPromotions());
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 24),
              _buildSectionTitle('Promotions'),
              const SizedBox(height: 12),
              _buildPromotionsSection(context),
              const SizedBox(height: 24),
              _buildSectionTitle('Nearby Bars & Restaurants'),
              const SizedBox(height: 12),
              _buildBarsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: barzBlack,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: barzYellow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.waving_hand, color: barzBlack),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back!',
                  style: TextStyle(color: textOnDark, fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ready to order?',
                  style: TextStyle(color: textOnDark.withValues(alpha: 0.7), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPromotionsSection(BuildContext context) {
    return BlocBuilder<PromotionsBloc, PromotionsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return _buildLoadingCard();
        }
        if (state.error != null) {
          return _buildErrorCard(state.error!, () {
            context.read<PromotionsBloc>().add(LoadPromotions());
          });
        }
        if (state.promotions.isEmpty) {
          return _buildEmptyCard('No promotions available', Icons.local_offer);
        }
        // Horizontal carousel for promotions
        return SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.promotions.length > 10 ? 10 : state.promotions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final promo = state.promotions[index];
              return _buildPromotionCard(context, promo, index);
            },
          ),
        );
      },
    );
  }

  Widget _buildPromotionCard(BuildContext context, dynamic promo, int index) {
    // Build discount label
    String discountLabel;
    switch (promo.discountType?.toString().split('.').last ?? 'other') {
      case 'percentage':
        discountLabel = '${promo.discountValue?.toInt() ?? 0}% OFF';
        break;
      case 'fixed':
        discountLabel = 'R\$ ${promo.discountValue?.toStringAsFixed(0) ?? '0'} OFF';
        break;
      case 'bogo':
        discountLabel = 'BOGO';
        break;
      default:
        discountLabel = 'DEAL';
    }
    
    return GestureDetector(
      onTap: () => context.push('/promotion/${promo.id}'),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: barzBlack,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Discount badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: barzYellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                discountLabel,
                style: const TextStyle(
                  color: barzBlack,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Title
            Expanded(
              child: Text(
                promo.title ?? 'Promotion',
                style: const TextStyle(
                  color: barzYellow,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Time indicator
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white54, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${promo.startTime ?? '00:00'} - ${promo.endTime ?? '23:59'}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(delay: (50 * (index % 5)).ms).slideX(begin: 0.1, end: 0),
    );
  }

  Widget _buildBarsSection(BuildContext context) {
    return BlocBuilder<BarBloc, BarState>(
      builder: (context, state) {
        if (state is BarLoading) {
          return _buildLoadingCard();
        }
        if (state is BarError) {
          return _buildErrorCard(state.message, () {
            context.read<BarBloc>().add(const LoadNearbyBars(lat: -23.5505, lng: -46.6333));
          });
        }
        if (state is BarsLoaded) {
          if (state.bars.isEmpty) {
            return _buildEmptyCard('No bars nearby', Icons.store);
          }
          return Column(
            children: state.bars.take(5).map((bar) {
              return BarzCard(
                child: _buildCardContent(
                  icon: Icons.store,
                  title: bar.name,
                  subtitle: bar.address,
                  onTap: () => context.push('/bar/${bar.id}'),
                ),
              ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1, end: 0);
            }).toList(),
          );
        }
        return _buildEmptyCard('Pull to refresh', Icons.refresh);
      },
    );
  }

  Widget _buildLoadingCard() {
    return BarzCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: barzYellow, strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text('Loading...', style: TextStyle(color: textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message, VoidCallback onRetry) {
    return BarzCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text('Retry', style: TextStyle(color: barzYellowDark)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message, IconData icon) {
    return BarzCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, color: textTertiary, size: 48),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: barzYellowSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: barzYellowDark, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: textSecondary, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: textTertiary),
          ],
        ),
      ),
    );
  }
}
