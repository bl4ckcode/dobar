import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/core/design/components/bar_icon_card.dart';
import 'package:barz/core/design/components/category_chip.dart';
import 'package:barz/core/design/components/drink_card.dart';
import 'package:barz/core/design/components/dobar_app_bar.dart';
import 'package:barz/ui/primitives/barz_card.dart';
import 'package:barz/features/bars/presentation/bloc/bar_bloc.dart';
import 'package:barz/features/bars/presentation/bloc/bar_event.dart';
import 'package:barz/features/bars/presentation/bloc/bar_state.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_bloc.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_event.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_state.dart';
import 'package:barz/features/trending/presentation/bloc/trending_bloc.dart';
import 'package:barz/features/trending/presentation/bloc/trending_state.dart';
import 'package:barz/features/location/presentation/bloc/location_bloc.dart';
import 'package:barz/features/location/presentation/bloc/location_event.dart';

/// Default fallback coordinates (São Paulo city center)
const double _defaultLat = -23.5505;
const double _defaultLng = -46.6333;

/// Standalone widget that creates its own BlocProviders
/// Use this when navigating directly to home (e.g., from a deep link)
class HomeConnected extends StatelessWidget {
  const HomeConnected({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getItInjector<LocationBloc>()..add(GetCurrentLocation()),
        ),
        BlocProvider(create: (_) => getItInjector<BarBloc>()),
        BlocProvider(create: (_) => getItInjector<PromotionsBloc>()),
      ],
      child: const HomeConnectedView(),
    );
  }
}

/// View widget that expects BlocProviders from parent (shell)
/// Use this in WireframeShell with IndexedStack for shared state
class HomeConnectedView extends StatefulWidget {
  const HomeConnectedView({super.key});

  @override
  State<HomeConnectedView> createState() => _HomeConnectedViewState();
}

class _HomeConnectedViewState extends State<HomeConnectedView> {
  void _refreshData(BuildContext context) {
    final locationState = context.read<LocationBloc>().state;
    final lat = locationState.currentLocation?.latitude ?? _defaultLat;
    final lng = locationState.currentLocation?.longitude ?? _defaultLng;

    context.read<LocationBloc>().add(GetCurrentLocation());
    context.read<BarBloc>().add(LoadNearbyBars(lat: lat, lng: lng));
    context.read<PromotionsBloc>().add(
      LoadPromotions(latitude: lat, longitude: lng),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Data loading is handled by WireframeShell
    // This view just displays the data from shared blocs
    return Scaffold(
      appBar: const DobarAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home_create_bar_fab',
        onPressed: () => context.push('/create-bar'),
        backgroundColor: barzBlack,
        icon: const Icon(Icons.add, color: barzYellow),
        label: const Text('Create Bar', style: TextStyle(color: barzYellow)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshData(context);
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
            _buildSectionTitle('Browse by Category'),
            const SizedBox(height: 12),
            _buildCategoriesSection(context),
            const SizedBox(height: 16),
            _buildBarsCarousel(context),
            const SizedBox(height: 24),
            _buildSectionTitle('Most Wanted Drinks'),
            const SizedBox(height: 12),
            _buildMostWantedDrinksSection(context),
            const SizedBox(height: 24),
            _buildSectionTitle('Hottest Drinks 🔥'),
            const SizedBox(height: 12),
            _buildHottestDrinksSection(context),
          ],
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
                  style: TextStyle(
                    color: textOnDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ready to order?',
                  style: TextStyle(
                    color: textOnDark.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(
      begin: const Offset(0.95, 0.95),
      end: const Offset(1, 1),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
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
            final locationState = context.read<LocationBloc>().state;
            final lat = locationState.currentLocation?.latitude ?? _defaultLat;
            final lng = locationState.currentLocation?.longitude ?? _defaultLng;
            context.read<PromotionsBloc>().add(
              LoadPromotions(latitude: lat, longitude: lng),
            );
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
            itemCount: state.promotions.length > 10
                ? 10
                : state.promotions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
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
        discountLabel =
            'R\$ ${promo.discountValue?.toStringAsFixed(0) ?? '0'} OFF';
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

  Widget _buildCategoriesSection(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: barCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = barCategories[index];
          return CategoryChip(
            icon: category.icon,
            label: category.label,
            isSelected: false,
            onTap: () {
              context.push('/find?category=${category.id}');
            },
          ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1, end: 0);
        },
      ),
    );
  }

  String _formatDistance(double? distanceMeters) {
    if (distanceMeters == null) return '';
    if (distanceMeters < 1000) {
      return '${distanceMeters.toInt()}m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
  }

  Widget _buildBarsCarousel(BuildContext context) {
    return BlocBuilder<BarBloc, BarState>(
      builder: (context, state) {
        if (state is BarLoading) {
          return _buildLoadingCard();
        }
        if (state is BarError) {
          return _buildErrorCard(state.message, () {
            _refreshData(context);
          });
        }
        if (state is BarsLoaded) {
          if (state.bars.isEmpty) {
            return _buildEmptyCard('No bars nearby', Icons.store);
          }
          return SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.bars.length > 10 ? 10 : state.bars.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final bar = state.bars[index];
                return BarIconCard(
                      logoUrl: bar.imageUrl,
                      name: bar.name,
                      distance: _formatDistance(bar.approximateLocation),
                      onTap: () => context.push('/bar/${bar.id}'),
                    )
                    .animate()
                    .fadeIn(delay: (50 * index).ms, duration: 400.ms)
                    .slideX(
                      begin: 0.2,
                      end: 0,
                      duration: 400.ms,
                      delay: (50 * index).ms,
                      curve: Curves.easeOutCubic,
                    )
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      duration: 400.ms,
                      delay: (50 * index).ms,
                      curve: Curves.easeOutBack,
                    );
              },
            ),
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
              child: CircularProgressIndicator(
                color: barzYellow,
                strokeWidth: 2,
              ),
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
            Text(
              message,
              style: TextStyle(color: textSecondary),
              textAlign: TextAlign.center,
            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, color: textTertiary.withValues(alpha: 0.4), size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: textSecondary.withValues(alpha: 0.6),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildMostWantedDrinksSection(BuildContext context) {
    return BlocBuilder<TrendingBloc, TrendingState>(
      builder: (context, state) {
        if (state.isLoadingMostWanted) {
          return _buildLoadingCard();
        }
        if (state.mostWantedDrinks.isEmpty) {
          return _buildEmptyCard('No drinks available', Icons.local_bar);
        }
        return SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.mostWantedDrinks.length > 10
                ? 10
                : state.mostWantedDrinks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final drink = state.mostWantedDrinks[index];
              return DrinkCard(
                    name: drink.name,
                    price: drink.priceAvg ?? drink.price,
                    imageUrl: drink.imageUrl ?? drink.picture,
                    barName: drink.barName,
                    onTap: () {},
                  )
                  .animate()
                  .fadeIn(delay: (40 * index).ms)
                  .slideY(begin: 0.1, end: 0);
            },
          ),
        );
      },
    );
  }

  Widget _buildHottestDrinksSection(BuildContext context) {
    return BlocBuilder<TrendingBloc, TrendingState>(
      builder: (context, state) {
        if (state.isLoadingHottest) {
          return _buildLoadingCard();
        }
        if (state.hottestDrinks.isEmpty) {
          return _buildEmptyCard('No hot deals', Icons.whatshot);
        }
        return SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.hottestDrinks.length > 10
                ? 10
                : state.hottestDrinks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final drink = state.hottestDrinks[index];
              return DrinkCard(
                    name: drink.name,
                    price: drink.priceAvg ?? drink.price,
                    imageUrl: drink.imageUrl ?? drink.picture,
                    barName: drink.barName,
                    showHotBadge: drink.isPromoted,
                    onTap: () {},
                  )
                  .animate()
                  .fadeIn(delay: (40 * index).ms)
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1, 1),
                  );
            },
          ),
        );
      },
    );
  }
}
