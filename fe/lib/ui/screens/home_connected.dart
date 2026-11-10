import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/session/shell_session.dart';
import 'package:barz/core/theme/theme_cubit.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/design/components/category_pill.dart';
import 'package:barz/core/design/components/home_connected_header.dart';
import 'package:barz/features/home/domain/home_toolbar.dart';
import 'package:barz/features/home/domain/models/home_model.dart';
import 'package:barz/features/home/presentation/bloc/home_bloc.dart';
import 'package:barz/features/home/presentation/bloc/home_event.dart';
import 'package:barz/features/home/presentation/bloc/home_state.dart';
import 'package:barz/features/location/presentation/bloc/location_cubit.dart';
import 'package:barz/features/location/presentation/bloc/location_state.dart';
import 'package:barz/features/location/presentation/location_permission_explainer.dart';
import 'package:barz/features/venues/domain/venue_category.dart';
import 'package:barz/features/venues/presentation/venue_presentation.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:barz/core/design/components/location_permission_alert.dart';
import 'package:barz/features/home/presentation/widgets/location_mismatch_dialog.dart';
import 'package:barz/features/user/presentation/bloc/user_bloc.dart';
import 'package:barz/features/user/presentation/bloc/user_event.dart';
import 'package:barz/features/user/presentation/bloc/user_state.dart';

/// Maximum content width on larger screens (matches the Profile surface).
const double kHomeMaxContentWidth = 600;

class HomeConnected extends StatelessWidget {
  const HomeConnected({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getItInjector<HomeBloc>()),
        BlocProvider(create: (_) => getItInjector<UserBloc>()),
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

class _HomeConnectedViewState extends State<HomeConnectedView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Browsing needs no location: load immediately (country-level discovery
    // without coordinates). The bloc reuses cached data when still fresh and
    // coalesces duplicates.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = getItInjector<ShellSession>();
      _load(force: session.homeStale);
      // Pick up a position silently only when permission was already granted.
      context.read<LocationCubit>().restoreIfGranted();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The user may have granted permission in Settings.
      context.read<LocationCubit>().restoreIfGranted();
    }
  }

  void _load({bool force = false}) {
    final location = context.read<LocationCubit>().state.currentLocation;
    context.read<HomeBloc>().add(
      LoadHomeData(
        latitude: location?.latitude,
        longitude: location?.longitude,
        force: force,
      ),
    );
  }

  Future<void> _refresh() async {
    await context.read<LocationCubit>().restoreIfGranted();
    if (!mounted) return;
    _load(force: true);
  }

  Future<void> _openCheckin(NearestVenue venue) async {
    // Existing check-in flow; it explains and requests location itself.
    await AppRoute.checkin.push(context, extra: venue.toBarModel());
  }

  Future<void> _openNotifications() async {
    await AppRoute.notifications.push(context);
    if (mounted) _load(force: true);
  }

  Future<void> _enableLocation() async {
    if (await LocationPermissionExplainer.ensure(context)) {
      // BlocListener below reloads with coordinates.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.dobarColors;
    final homeState = context.watch<HomeBloc>().state;
    final locationState = context.watch<LocationCubit>().state;
    final data = homeState is HomeLoaded ? homeState.data : null;
    final toolbar = resolveHomeToolbar(data);
    final isDark = theme.brightness == Brightness.dark;

    return BlocListener<LocationCubit, LocationState>(
      listenWhen: (prev, curr) =>
          prev.currentLocation != curr.currentLocation &&
          curr.currentLocation != null,
      listener: (context, state) => _load(),
      child: MultiBlocListener(
        listeners: [
          BlocListener<HomeBloc, HomeState>(
            listener: (context, state) {
              if (state is HomeLoaded && state.data.locationMismatch) {
                _showLocationMismatchDialog(context);
              }
            },
          ),
          BlocListener<UserBloc, UserState>(
            listenWhen: (prev, curr) =>
                prev.isCountryUpdated != curr.isCountryUpdated,
            listener: (context, state) {
              if (state.isCountryUpdated) _load(force: true);
            },
          ),
        ],
        child: Scaffold(
          backgroundColor: isDark ? colors.background : Colors.white,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: 0.6,
                      child: Center(
                        child: Image.asset(
                          'assets/icons/dobar-logo-animated-transparent.gif',
                          height: 300,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kHomeMaxContentWidth,
                    ),
                    child: Column(
                      children: [
                        HomeConnectedHeader(
                          content: toolbar,
                          unreadNotifications:
                              data?.userStatus?.unreadNotifications ?? 0,
                          isDark: isDark,
                          onToggleTheme: () =>
                              getItInjector<ThemeCubit>().toggleTheme(),
                          onNotificationTap: _openNotifications,
                          onNearbyTap: toolbar is NearbyVenueToolbar
                              ? () => _openCheckin(toolbar.venue)
                              : null,
                        ),
                        if (locationState.currentLocation == null)
                          LocationPermissionAlert(
                            error: locationState.error,
                            isLoading: locationState.isLoading,
                            onGrant: _enableLocation,
                          ),
                        _buildCategoriesSection(context),
                        const SizedBox(height: BarzSpacing.sm),
                        Expanded(child: _buildScrollBody(context, colors)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollBody(BuildContext context, DobarColors colors) {
    final l10n = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: _refresh,
      color: colors.buttonPrimary,
      backgroundColor: colors.surface,
      child: ListView(
        // Scroll position is owned by the shell (PrimaryScrollController).
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: BarzSpacing.lg),
        children: [
          const SizedBox(height: BarzSpacing.sm),
          _buildSectionTitleWithSubtitle(
            l10n.meet_our_partners,
            l10n.here_are_the_closest_partners,
            colors,
          ),
          const SizedBox(height: BarzSpacing.md),
          BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              if (state is HomeLoading) return _buildLoadingCard();
              if (state is HomeError) {
                return _buildErrorCard(state.message, () => _load(force: true));
              }
              if (state is HomeLoaded) {
                if (state.data.nearbyBars.isEmpty) {
                  return _buildEmptyCard(
                    l10n.empty_no_bars_nearby,
                    Icons.store,
                  );
                }
                return _buildBarsCarousel(context, state.data.nearbyBars);
              }
              return _buildEmptyCard(l10n.empty_pull_to_refresh, Icons.refresh);
            },
          ),
          const SizedBox(height: BarzSpacing.xl),
          _buildSectionTitleWithSubtitle(
            l10n.most_wanted,
            l10n.want_a_specific_drink,
            colors,
          ),
          const SizedBox(height: BarzSpacing.md),
          BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              if (state is HomeLoading) return _buildLoadingCard();
              if (state is HomeLoaded) {
                if (state.data.trendingDrinks.mostWanted.isEmpty) {
                  return _buildEmptyCard(l10n.empty_no_drinks, Icons.local_bar);
                }
                return _buildDrinksList(
                  context,
                  state.data.trendingDrinks.mostWanted,
                  false,
                );
              }
              return _buildEmptyCard(l10n.empty_no_drinks, Icons.local_bar);
            },
          ),
          const SizedBox(height: BarzSpacing.xl),
          _buildSectionTitleWithSubtitle(
            l10n.home_hottest_drinks_title,
            l10n.home_hottest_drinks_subtitle,
            colors,
          ),
          const SizedBox(height: BarzSpacing.md),
          BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              if (state is HomeLoading) return _buildLoadingCard();
              if (state is HomeLoaded) {
                if (state.data.trendingDrinks.hottest.isEmpty) {
                  return _buildEmptyCard(
                    l10n.empty_no_hot_deals,
                    Icons.whatshot,
                  );
                }
                return _buildDrinksList(
                  context,
                  state.data.trendingDrinks.hottest,
                  true,
                );
              }
              return _buildEmptyCard(l10n.empty_no_hot_deals, Icons.whatshot);
            },
          ),
          const SizedBox(height: BarzSpacing.xl),
        ],
      ),
    );
  }

  /// Entrance animation unless the platform asks for reduced motion.
  Widget _motion(
    BuildContext context,
    Widget child,
    int index, {
    Offset slide = const Offset(0.1, 0),
  }) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return child
        .animate()
        .fadeIn(delay: (50 * index).ms, duration: 400.ms)
        .slide(begin: slide, end: Offset.zero, duration: 400.ms);
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
            ElevatedButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)!.home_retry),
            ),
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
      (
        icon: LucideIcons.wine,
        label: l10n.category_bars,
        id: VenueCategory.bars,
      ),
      (
        icon: LucideIcons.utensils_crossed,
        label: l10n.category_restaurants,
        id: VenueCategory.restaurants,
      ),
      (
        icon: LucideIcons.party_popper,
        label: l10n.category_clubs,
        id: VenueCategory.clubs,
      ),
    ];

    return Semantics(
      container: true,
      label: l10n.home_categories_label,
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.lg),
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final category = categories[index];
            return Center(
              child: _motion(
                context,
                CategoryPill(
                  icon: category.icon,
                  label: category.label,
                  isSelected: false,
                  onTap: () => AppRoute.pushCategory(context, category.id),
                ),
                index,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBarsCarousel(BuildContext context, List<NearbyBar> bars) {
    final displayBars = bars.length > 10 ? bars.sublist(0, 10) : bars;
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 208,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.lg),
        scrollDirection: Axis.horizontal,
        itemCount: displayBars.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final bar = displayBars[index];
          return SizedBox(
            width: 160,
            child: _motion(
              context,
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(BarzRadii.lg),
                  border: Theme.of(context).brightness == Brightness.light
                      ? Border.all(color: barzDarkMuted, width: 1)
                      : null,
                ),
                child: BarCard(
                  name: bar.name,
                  type: l10n.category_bars,
                  distance: formatVenueDistance(bar.distanceMeters),
                  rating: bar.rating,
                  imageUrl: bar.imageUrl,
                  badges: badgesFor(bar.primaryPromotion),
                  onTap: () => AppRoute.pushBar(context, bar.id),
                ),
              ),
              index,
            ),
          );
        },
      ),
    );
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
                      color: const Color(0xFFFF8A3D),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.flame,
                          size: 13,
                          color: barzDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)!.badge_hot,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: barzDark,
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

  void _showLocationMismatchDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => LocationMismatchDialog(
        onConfirm: () {
          final locationState = context.read<LocationCubit>().state;
          if (locationState.currentLocation != null) {
            context.read<UserBloc>().add(
              UserEvent.updateCountry(
                latitude: locationState.currentLocation!.latitude,
                longitude: locationState.currentLocation!.longitude,
              ),
            );
          }
          Navigator.of(dialogContext).pop();
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
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
