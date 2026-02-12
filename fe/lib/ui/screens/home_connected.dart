import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/design/components/category_pill.dart';
import 'package:barz/core/design/components/home_connected_header.dart';
import 'package:barz/ui/primitives/barz_card.dart' as legacy;
import 'package:barz/features/bars/presentation/bloc/bar_bloc.dart';
import 'package:barz/features/bars/presentation/bloc/bar_event.dart';
import 'package:barz/features/bars/presentation/bloc/bar_state.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_bloc.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_event.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_state.dart';
import 'package:barz/features/trending/presentation/bloc/trending_bloc.dart';
import 'package:barz/features/trending/presentation/bloc/trending_event.dart';
import 'package:barz/features/trending/presentation/bloc/trending_state.dart';
import 'package:barz/features/location/presentation/bloc/location_bloc.dart';
import 'package:barz/features/location/presentation/bloc/location_event.dart';
import 'package:barz/features/location/presentation/bloc/location_state.dart';
import 'package:barz/l10n/app_localizations.dart';

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
        BlocProvider(create: (_) => getItInjector<TrendingBloc>()),
      ],
      child: const HomeConnectedView(),
    );
  }
}

class HomeConnectedView extends StatefulWidget {
  const HomeConnectedView({super.key});

  @override
  State<HomeConnectedView> createState() => _HomeConnectedViewState();
}

class _HomeConnectedViewState extends State<HomeConnectedView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshData(BuildContext context) {
    final locationState = context.read<LocationBloc>().state;
    context.read<LocationBloc>().add(GetCurrentLocation());

    if (locationState.currentLocation != null) {
      context.read<BarBloc>().add(
        LoadNearbyBars(
          lat: locationState.currentLocation!.latitude,
          lng: locationState.currentLocation!.longitude,
        ),
      );
      context.read<PromotionsBloc>().add(
        LoadPromotions(
          latitude: locationState.currentLocation!.latitude,
          longitude: locationState.currentLocation!.longitude,
        ),
      );
      context.read<TrendingBloc>().add(
        TrendingEvent.loadMostWanted(
          latitude: locationState.currentLocation!.latitude,
          longitude: locationState.currentLocation!.longitude,
        ),
      );
      context.read<TrendingBloc>().add(
        TrendingEvent.loadHottest(
          latitude: locationState.currentLocation!.latitude,
          longitude: locationState.currentLocation!.longitude,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    final barState = context.watch<BarBloc>().state;
    String? nearbyBarName;

    if (barState is BarsLoaded) {
      for (final bar in barState.bars) {
        if ((bar.approximateLocation ?? 999999) <= 5.0) {
          nearbyBarName = bar.name;
          break;
        }
      }
    }

    return BlocListener<LocationBloc, LocationState>(
      listener: (context, state) {
        if (state.currentLocation != null) {
          context.read<BarBloc>().add(
            LoadNearbyBars(
              lat: state.currentLocation!.latitude,
              lng: state.currentLocation!.longitude,
            ),
          );
          context.read<PromotionsBloc>().add(
            LoadPromotions(
              latitude: state.currentLocation!.latitude,
              longitude: state.currentLocation!.longitude,
            ),
          );
          context.read<TrendingBloc>().add(
            TrendingEvent.loadMostWanted(
              latitude: state.currentLocation!.latitude,
              longitude: state.currentLocation!.longitude,
            ),
          );
          context.read<TrendingBloc>().add(
            TrendingEvent.loadHottest(
              latitude: state.currentLocation!.latitude,
              longitude: state.currentLocation!.longitude,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.light
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
                    top: 32,
                    bottom: BarzSpacing.lg,
                  ),
                  children: [
                    const SizedBox(height: 32),
                    _buildCategoriesSection(context),
                    const SizedBox(height: BarzSpacing.lg),
                    _buildSectionTitleWithSubtitle(
                      AppLocalizations.of(context)!.meet_our_partners,
                      AppLocalizations.of(
                        context,
                      )!.here_are_the_closest_partners,
                      colors,
                    ),
                    const SizedBox(height: BarzSpacing.md),
                    _buildBarsCarousel(context),
                    const SizedBox(height: BarzSpacing.xl),
                    _buildSectionTitleWithSubtitle(
                      AppLocalizations.of(context)!.most_wanted,
                      AppLocalizations.of(context)!.want_a_specific_drink,
                      colors,
                    ),
                    const SizedBox(height: BarzSpacing.md),
                    _buildMostWantedDrinksSection(context),
                    const SizedBox(height: BarzSpacing.xl), // Increased spacing
                    _buildSectionTitleWithSubtitle(
                      AppLocalizations.of(context)!.home_hottest_drinks_title,
                      AppLocalizations.of(
                        context,
                      )!.home_hottest_drinks_subtitle,
                      colors,
                    ),
                    const SizedBox(height: BarzSpacing.md),
                    _buildHottestDrinksSection(context),
                    const SizedBox(height: BarzSpacing.lg),
                    _buildSectionTitleWithSubtitle(
                      AppLocalizations.of(context)!.home_promotions_title,
                      AppLocalizations.of(context)!.home_promotions_subtitle,
                      colors,
                    ),
                    const SizedBox(height: BarzSpacing.md),
                    _buildPromotionsSection(context),
                    const SizedBox(height: BarzSpacing.xl),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: HomeConnectedHeader(nearbyBarName: nearbyBarName),
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

  Widget _buildPromotionsSection(BuildContext context) {
    return BlocBuilder<PromotionsBloc, PromotionsState>(
      builder: (context, state) {
        if (state.isLoading) return _buildLoadingCard();
        if (state.error != null) {
          return _buildErrorCard(state.error!, () {
            if (context.mounted &&
                context.read<LocationBloc>().state.currentLocation != null) {
              final loc = context.read<LocationBloc>().state.currentLocation!;
              context.read<PromotionsBloc>().add(
                LoadPromotions(
                  latitude: loc.latitude,
                  longitude: loc.longitude,
                ),
              );
            } else {
              context.read<LocationBloc>().add(GetCurrentLocation());
            }
          });
        }
        if (state.promotions.isEmpty) {
          return _buildEmptyCard(
            AppLocalizations.of(context)!.empty_no_promotions,
            Icons.local_offer,
          );
        }
        return SizedBox(
          height: 112,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.lg),
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
        discountLabel = AppLocalizations.of(context)!.promo_label_bogo;
        break;
      default:
        discountLabel = AppLocalizations.of(context)!.promo_label_deal;
    }

    return GestureDetector(
      onTap: () => AppRoute.pushPromotion(context, promo.id),
      child: Container(
        width: 160,
        height: 224,
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
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        barzDark,
                        barzGold.withValues(alpha: 0.3),
                        barzGold.withValues(alpha: 0.9),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: barzGold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    discountLabel,
                    style: const TextStyle(
                      color: barzDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
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
                      Text(
                        promo.title ??
                            AppLocalizations.of(context)!.promo_default_title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: barzDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: barzDark.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${promo.startTime ?? '00:00'} - ${promo.endTime ?? '23:59'}',
                              style: TextStyle(
                                fontSize: 10,
                                color: barzDark.withValues(alpha: 0.7),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: (50 * (index % 5)).ms).slideX(begin: 0.1, end: 0),
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

  String _formatDistance(double? distanceMeters) {
    if (distanceMeters == null) return '';
    if (distanceMeters < 1000) return '${distanceMeters.toInt()}m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
  }

  String _getBarType(dynamic bar) {
    return AppLocalizations.of(context)!.category_bars;
  }

  Widget _buildBarsCarousel(BuildContext context) {
    return BlocBuilder<BarBloc, BarState>(
      builder: (context, state) {
        if (state is BarLoading) return _buildLoadingCard();
        if (state is BarError) {
          return _buildErrorCard(state.message, () => _refreshData(context));
        }
        if (state is BarsLoaded) {
          if (state.bars.isEmpty) {
            return _buildEmptyCard(
              AppLocalizations.of(context)!.empty_no_bars_nearby,
              Icons.store,
            );
          }
          final displayBars = state.bars.length > 10
              ? state.bars.sublist(0, 10)
              : state.bars;
          return SizedBox(
            height: 200,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.lg),
              scrollDirection: Axis.horizontal,
              itemCount: displayBars.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final bar = displayBars[index];
                return SizedBox(
                  width: 160,
                  child:
                      Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(BarzRadii.lg),
                              boxShadow:
                                  Theme.of(context).brightness ==
                                      Brightness.light
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: BarCard(
                              name: bar.name,
                              type: _getBarType(bar),
                              distance: _formatDistance(
                                bar.approximateLocation,
                              ),
                              rating: 4.5,
                              imageUrl: bar.imageUrl,
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
        return _buildEmptyCard(
          AppLocalizations.of(context)!.empty_pull_to_refresh,
          Icons.refresh,
        );
      },
    );
  }

  Widget _buildMostWantedDrinksSection(BuildContext context) {
    return BlocBuilder<TrendingBloc, TrendingState>(
      builder: (context, state) {
        if (state.isLoadingMostWanted) return _buildLoadingCard();
        if (state.mostWantedDrinks.isEmpty) {
          return _buildEmptyCard(
            AppLocalizations.of(context)!.empty_no_drinks,
            Icons.local_bar,
          );
        }
        return SizedBox(
          height: 224,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.lg),
            scrollDirection: Axis.horizontal,
            itemCount: state.mostWantedDrinks.length > 10
                ? 10
                : state.mostWantedDrinks.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final drink = state.mostWantedDrinks[index];
              return _buildDrinkCard(drink, index, false, false);
            },
          ),
        );
      },
    );
  }

  Widget _buildHottestDrinksSection(BuildContext context) {
    return BlocBuilder<TrendingBloc, TrendingState>(
      builder: (context, state) {
        if (state.isLoadingHottest) return _buildLoadingCard();
        if (state.hottestDrinks.isEmpty) {
          return _buildEmptyCard(
            AppLocalizations.of(context)!.empty_no_hot_deals,
            Icons.whatshot,
          );
        }
        return SizedBox(
          height: 140,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.lg),
            scrollDirection: Axis.horizontal,
            itemCount: state.hottestDrinks.length > 10
                ? 10
                : state.hottestDrinks.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final drink = state.hottestDrinks[index];
              return _buildDrinkCard(drink, index, drink.isPromoted, true);
            },
          ),
        );
      },
    );
  }

  Widget _buildDrinkCard(
    dynamic drink,
    int index,
    bool showHotBadge,
    bool isCircular,
  ) {
    final priceText = drink.priceAvg != null
        ? 'R\$ ${drink.priceAvg!.toStringAsFixed(2)}'
        : (drink.price != null ? 'R\$ ${drink.price!.toStringAsFixed(2)}' : '');

    if (isCircular) {
      return GestureDetector(
        onTap: () {},
        child: SizedBox(
          width: 110,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  ClipOval(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        border: Border.all(color: barzDarkMuted, width: 1),
                      ),
                      child: Stack(
                        children: [
                          if (drink.imageUrl != null || drink.picture != null)
                            Positioned.fill(
                              child: Image.network(
                                drink.imageUrl ?? drink.picture ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _drinkPlaceholder(),
                              ),
                            )
                          else
                            Positioned.fill(child: _drinkPlaceholder()),
                          // Gradient for Hot Badge only
                          if (showHotBadge)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.deepOrange.withValues(alpha: 0.1),
                                      Colors.deepOrange.withValues(alpha: 0.4),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (showHotBadge)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.whatshot,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                drink.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.black87
                      : textOnDark,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: (40 * index).ms).slideX(begin: 0.1, end: 0);
    }

    // Rectangular card (with price)
    return GestureDetector(
      onTap: () {},
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
              if (drink.imageUrl != null || drink.picture != null)
                Positioned.fill(
                  child: Image.network(
                    drink.imageUrl ?? drink.picture ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _drinkPlaceholder(),
                  ),
                )
              else
                Positioned.fill(child: _drinkPlaceholder()),
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
                      if (drink.barName != null)
                        Text(
                          drink.barName!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: textOnDark.withValues(alpha: 0.7),
                            letterSpacing: 0.5,
                          ),
                        ),
                      if (drink.barName != null) const SizedBox(height: 4),
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
                      const SizedBox(height: 4),
                      if (priceText.isNotEmpty)
                        Text(
                          priceText,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: barzGold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (40 * index).ms).slideX(begin: 0.1, end: 0);
  }

  Widget _drinkPlaceholder() {
    return Container(
      color: barzDarkLight,
      child: const Center(
        child: Icon(Icons.local_bar, size: 40, color: textSecondary),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return legacy.BarzCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: barzGold, strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(
              AppLocalizations.of(context)!.loading_text,
              style: TextStyle(color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message, VoidCallback onRetry) {
    return legacy.BarzCard(
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
              child: Text(
                AppLocalizations.of(context)!.error_retry_button,
                style: TextStyle(color: barzGoldDark),
              ),
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
}
