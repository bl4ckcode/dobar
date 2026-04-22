import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/design/components/category_pill.dart';
import 'package:barz/core/design/components/home_connected_header.dart';
import 'package:barz/features/home/presentation/bloc/home_bloc.dart';
import 'package:barz/features/home/presentation/bloc/home_event.dart';
import 'package:barz/features/home/presentation/bloc/home_state.dart';
import 'package:barz/features/location/presentation/bloc/location_cubit.dart';
import 'package:barz/features/location/presentation/bloc/location_state.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:barz/core/design/components/location_permission_alert.dart';
import 'package:barz/features/promotions/domain/models/promotion_model.dart';

class HomeConnected extends StatelessWidget {
  const HomeConnected({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getItInjector<HomeBloc>(),
      child: const HomeConnectedView(),
    );
  }
}

class HomeConnectedView extends StatefulWidget {
  const HomeConnectedView({super.key});

  @override
  State<HomeConnectedView> createState() => _HomeConnectedViewState();
}

class _HomeConnectedViewState extends State<HomeConnectedView>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Trigger initial load if location is already available
    final locationState = context.read<LocationCubit>().state;
    if (locationState.currentLocation != null) {
      debugPrint(
        '[HomeView] Location already available: ${locationState.currentLocation!.latitude}, ${locationState.currentLocation!.longitude}',
      );
      context.read<HomeBloc>().add(
        LoadHomeData(
          latitude: locationState.currentLocation!.latitude,
          longitude: locationState.currentLocation!.longitude,
        ),
      );
    } else {
      debugPrint('[HomeView] Location not available in initState');
    }
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[HomeView] App resumed, checking location state...');
      final locationState = context.read<LocationCubit>().state;
      if (locationState.currentLocation == null) {
        debugPrint(
          '[HomeView] Location still null on resume, re-triggering getCurrentLocation',
        );
        context.read<LocationCubit>().getCurrentLocation();
      }
    }
  }

  void _refreshData(BuildContext context) {
    final locationState = context.read<LocationCubit>().state;
    if (locationState.currentLocation != null) {
      debugPrint(
        '[HomeView] Refreshing data with location: ${locationState.currentLocation!.latitude}',
      );
      context.read<HomeBloc>().add(
        LoadHomeData(
          latitude: locationState.currentLocation!.latitude,
          longitude: locationState.currentLocation!.longitude,
        ),
      );
    } else {
      debugPrint('[HomeView] Refreshing location first...');
      context.read<LocationCubit>().getCurrentLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.dobarColors;
    final homeState = context.watch<HomeBloc>().state;
    final locationState = context.watch<LocationCubit>().state;
    String? nearbyBarName;
    dynamic closestBar; // Will hold the BarModel

    if (homeState is HomeLoaded) {
      for (final bar in homeState.data.nearbyBars) {
        if (bar.distanceMeters <= 500) {
          nearbyBarName = bar.name;
          closestBar = bar;
          break;
        }
      }
    }

    return BlocListener<LocationCubit, LocationState>(
      listener: (context, state) {
        if (!state.isLoading && state.currentLocation != null) {
          // Trigger load if not already loaded OR if it's the first time we get location
          // We removed the restrictive 'homeState is HomeInitial' check to allow updates when location improves
          debugPrint(
            '[HomeView] Location obtained or improved, triggering LoadHomeData',
          );
          context.read<HomeBloc>().add(
            LoadHomeData(
              latitude: state.currentLocation!.latitude,
              longitude: state.currentLocation!.longitude,
            ),
          );
        } else if (state.error != null) {
          debugPrint('[HomeView] Location state has error: ${state.error}');
        }
      },
      child: Scaffold(
        backgroundColor: theme.brightness == Brightness.light
            ? Colors.white
            : colors.background,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.6,
                  child: Center(
                    child: Image.asset(
                      'assets/icons/dobar-logo-animated-transparent.gif',
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              RefreshIndicator(
                onRefresh: () async => _refreshData(context),
                color: colors.buttonPrimary,
                backgroundColor: colors.surface,
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(
                    top: 16,
                    bottom: BarzSpacing.lg,
                  ),
                  children: [
                    SizedBox(height: nearbyBarName != null ? 100 : 64),
                    _buildCategoriesSection(context),
                    const SizedBox(height: BarzSpacing.md),

                    // Nearby Bars Section
                    _buildSectionTitleWithSubtitle(
                      AppLocalizations.of(context)!.meet_our_partners,
                      AppLocalizations.of(
                        context,
                      )!.here_are_the_closest_partners,
                      colors,
                    ),
                    const SizedBox(height: BarzSpacing.md),
                    BlocBuilder<HomeBloc, HomeState>(
                      builder: (context, state) {
                        if (state is HomeLoading) return _buildLoadingCard();
                        if (state is HomeError) {
                          return _buildErrorCard(
                            state.message,
                            () => _refreshData(context),
                          );
                        }
                        if (state is HomeLoaded) {
                          if (state.data.nearbyBars.isEmpty) {
                            return _buildEmptyCard(
                              AppLocalizations.of(
                                context,
                              )!.empty_no_bars_nearby,
                              Icons.store,
                            );
                          }
                          return _buildBarsCarousel(
                            context,
                            state.data.nearbyBars,
                            promotions: state.data.activePromotions,
                          );
                        }
                        // Initial state or other
                        return _buildEmptyCard(
                          AppLocalizations.of(context)!.empty_pull_to_refresh,
                          Icons.refresh,
                        );
                      },
                    ),
                    const SizedBox(height: BarzSpacing.xl),

                    // Most Wanted Drinks
                    _buildSectionTitleWithSubtitle(
                      AppLocalizations.of(context)!.most_wanted,
                      AppLocalizations.of(context)!.want_a_specific_drink,
                      colors,
                    ),
                    const SizedBox(height: BarzSpacing.md),
                    BlocBuilder<HomeBloc, HomeState>(
                      builder: (context, state) {
                        if (state is HomeLoading) return _buildLoadingCard();
                        if (state is HomeLoaded) {
                          if (state.data.trendingDrinks.mostWanted.isEmpty) {
                            return _buildEmptyCard(
                              AppLocalizations.of(context)!.empty_no_drinks,
                              Icons.local_bar,
                            );
                          }
                          return _buildDrinksList(
                            context,
                            state.data.trendingDrinks.mostWanted,
                            false,
                          );
                        }
                        return _buildEmptyCard(
                          AppLocalizations.of(context)!.empty_no_drinks,
                          Icons.local_bar,
                        );
                      },
                    ),
                    const SizedBox(height: BarzSpacing.xl),

                    // Hottest Drinks
                    _buildSectionTitleWithSubtitle(
                      AppLocalizations.of(context)!.home_hottest_drinks_title,
                      AppLocalizations.of(
                        context,
                      )!.home_hottest_drinks_subtitle,
                      colors,
                    ),
                    const SizedBox(height: BarzSpacing.md),
                    BlocBuilder<HomeBloc, HomeState>(
                      builder: (context, state) {
                        if (state is HomeLoading) return _buildLoadingCard();
                        if (state is HomeLoaded) {
                          if (state.data.trendingDrinks.hottest.isEmpty) {
                            return _buildEmptyCard(
                              AppLocalizations.of(context)!.empty_no_hot_deals,
                              Icons.whatshot,
                            );
                          }
                          return _buildDrinksList(
                            context,
                            state.data.trendingDrinks.hottest,
                            true,
                          );
                        }
                        return _buildEmptyCard(
                          AppLocalizations.of(context)!.empty_no_hot_deals,
                          Icons.whatshot,
                        );
                      },
                    ),
                    const SizedBox(height: BarzSpacing.xl),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    HomeConnectedHeader(
                      nearbyBarName: nearbyBarName,
                      unreadNotifications: homeState is HomeLoaded
                          ? homeState.data.userStatus?.unreadNotifications ?? 0
                          : 0,
                      onBarTap: () {
                        // Navigate to check-in page and pass the bar object via extra
                        if (closestBar != null) {
                          try {
                            final barModel = closestBar.toBarModel();
                            debugPrint(
                              '[Home] Navigating to check-in with bar: ${barModel.id}',
                            );
                            AppRoute.checkin.push(context, extra: barModel);
                          } catch (e) {
                            debugPrint(
                              '[Home] Error converting bar to BarModel: $e',
                            );
                            // Fallback: just go to check-in page without specific bar
                            AppRoute.checkin.push(context);
                          }
                        } else {
                          AppRoute.checkin.push(context);
                        }
                      },
                      onNotificationTap: () =>
                          AppRoute.notifications.push(context),
                    ),
                    if (locationState.currentLocation == null)
                      LocationPermissionAlert(
                        error: locationState.error,
                        isLoading: locationState.isLoading,
                        onGrant: () =>
                            context.read<LocationCubit>().getCurrentLocation(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitleWithSubtitle(
    String title,
    String subtitle,
    DobarColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colors.labelPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: colors.labelSecondary),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Helper Widgets
  // ===========================================================================

  Widget _buildLoadingCard() {
    return const SizedBox(
      height: 60,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message, VoidCallback onRetry) {
    return Container(
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: BarzSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(BarzRadii.lg),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 32),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[700]),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message, IconData icon) {
    return SizedBox(
      height: 100,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.grey[400], size: 28),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = [
      (icon: Icons.local_bar, label: l10n.category_bars, id: 'bar'),
      (
        icon: Icons.restaurant,
        label: l10n.category_restaurants,
        id: 'restaurant',
      ),
      (icon: Icons.nightlife, label: l10n.category_clubs, id: 'club'),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.lg),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          return CategoryPill(
            icon: category.icon,
            label: category.label,
            isSelected: false,
            onTap: () => AppRoute.pushFind(context, category: category.id),
          ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1, end: 0);
        },
      ),
    );
  }

  Widget _buildBarsCarousel(
    BuildContext context,
    List<dynamic> bars, {
    List<dynamic> promotions = const [],
  }) {
    final displayBars = bars.length > 10 ? bars.sublist(0, 10) : bars;
    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.lg),
        scrollDirection: Axis.horizontal,
        itemCount: displayBars.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final bar = displayBars[index];
          final barBadges = _computeBadges(bar.id, promotions);
          return SizedBox(
            width: 160,
            child:
                Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(BarzRadii.lg),
                        border: Theme.of(context).brightness == Brightness.light
                            ? Border.all(color: barzDarkMuted, width: 1)
                            : null,
                      ),
                      child: BarCard(
                        name: bar.name,
                        type: AppLocalizations.of(context)!.category_bars,
                        distance: _formatDistance(bar.distanceMeters),
                        rating: bar.rating,
                        imageUrl: bar.imageUrl,
                        badges: barBadges,
                        onTap: () => AppRoute.pushBar(context, bar.id),
                      ),
                    )
                    .animate()
                    .fadeIn(delay: (50 * index).ms, duration: 400.ms)
                    .slideX(
                      begin: 0.1,
                      end: 0,
                      duration: 400.ms,
                      delay: (50 * index).ms,
                      curve: Curves.easeOut,
                    ),
          );
        },
      ),
    );
  }

  List<BarBadge> _computeBadges(int barId, List<dynamic> promotions) {
    if (promotions.isEmpty) return [];
    
    final badges = <BarBadge>{};
    // Cast to List<PromotionModel> for safe property access
    final typedPromos = promotions.whereType<PromotionModel>().toList();
    
    for (final promo in typedPromos) {
      // Safely compare IDs as strings just in case
      if (promo.barId?.toString() != barId.toString()) continue;
      
      final title = promo.title.toLowerCase();
      final description = (promo.description ?? '').toLowerCase();
      final isBogo = promo.discountType == PromoDiscountType.bogo;
      
      if (title.contains('happy hour') || title.contains('happy h') || 
          description.contains('happy hour') || description.contains('happy h') ||
          title.contains('dobro') || description.contains('dobro') ||
          title.contains('2 por 1') || description.contains('2 por 1') ||
          isBogo) {
        badges.add(BarBadge.happyHour);
      } else if (title.contains('cashback') || description.contains('cashback')) {
        badges.add(BarBadge.cashback);
      } else {
        badges.add(BarBadge.promo);
      }
    }
    return badges.toList();
  }

  String _formatDistance(double? distanceMeters) {
    if (distanceMeters == null) return '';
    if (distanceMeters < 1000) return '${distanceMeters.toInt()}m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
  }

  Widget _buildDrinksList(
    BuildContext context,
    List<dynamic> drinks,
    bool showHotBadge,
  ) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.lg),
        scrollDirection: Axis.horizontal,
        itemCount: drinks.length > 10 ? 10 : drinks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final drink = drinks[index];
          // Use drink.isPromoted if available, otherwise fallback to showHotBadge param
          // Note: home_model.dart TrendingDrink likely has isPromoted
          final isPromoted = showHotBadge;
          return _buildDrinkCard(context, drink, index, isPromoted);
        },
      ),
    );
  }

  Widget _buildDrinkCard(
    BuildContext context,
    dynamic drink,
    int index,
    bool showHotBadge,
  ) {
    // Reusing existing card design logic
    return GestureDetector(
      onTap: () {}, // Action?
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BarzRadii.lg),
          border: Border.all(color: barzDarkMuted, width: 1),
          boxShadow: Theme.of(context).brightness == Brightness.light
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(BarzRadii.lg),
          child: Stack(
            children: [
              if (drink.imageUrl != null)
                Positioned.fill(
                  child: Image.network(
                    drink.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _drinkPlaceholder(),
                  ),
                )
              else
                Positioned.fill(child: _drinkPlaceholder()),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: showHotBadge
                          ? [
                              Colors.transparent,
                              Colors.orange.withValues(alpha: 0.3),
                              Colors.deepOrange.withValues(alpha: 0.85),
                            ]
                          : [
                              Colors.transparent,
                              barzDark.withValues(alpha: 0.4),
                              barzDark.withValues(alpha: 0.9),
                            ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              if (showHotBadge)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.whatshot,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)!.badge_hot,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bar name if available
                      // if (drink.barName != null) ...
                      Text(
                        drink.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textOnDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Price?
                      // Text(...)
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: (40 * index).ms).slideX(begin: 0.1, end: 0),
    );
  }

  Widget _drinkPlaceholder() {
    return const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(color: barzGold, strokeWidth: 2),
      ),
    );
  }
}
