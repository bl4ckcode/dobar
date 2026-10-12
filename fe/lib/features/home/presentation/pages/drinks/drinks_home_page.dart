import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/utils/location_handler.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/advertising/presentation/bloc/advertising_bloc.dart';
import 'package:barz/features/advertising/presentation/bloc/advertising_event.dart';
import 'package:barz/features/advertising/presentation/bloc/advertising_state.dart';
import 'package:barz/features/advertising/presentation/widgets/ad_tracking_service.dart';
import 'package:barz/features/advertising/presentation/widgets/featured_ad_card.dart';
import 'package:barz/features/home/domain/usecases/drinks_home_usecase.dart';
import 'package:barz/features/home/presentation/bloc/drinks/drinks_home_bloc.dart';
import 'package:barz/features/home/presentation/bloc/drinks/drinks_home_event.dart';
import 'package:barz/features/home/presentation/bloc/drinks/drinks_home_state.dart';
import 'package:barz/features/trending/domain/models/trending_drink.dart';
import 'package:barz/features/trending/presentation/bloc/trending_bloc.dart';
import 'package:barz/features/trending/presentation/bloc/trending_event.dart';
import 'package:barz/features/trending/presentation/bloc/trending_state.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:barz/shared/domain/models/card_type_model.dart';
import 'package:barz/shared/domain/models/parallax_recipe_ui_model.dart';
import 'package:barz/shared/presentation/loading_util.dart';
import 'package:barz/shared/presentation/widget/parallax_scroll_widget/horizontal_sliding_cards.dart';
import 'package:barz/shared/presentation/widget/title_subtitle_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';

class DrinksHomePage extends StatefulWidget {
  const DrinksHomePage({super.key});

  @override
  State<DrinksHomePage> createState() => _DrinksHomePageState();
}

class _DrinksHomePageState extends State<DrinksHomePage> {
  late DrinksHomeBloc _drinksHomeBloc;
  late AdvertisingBloc _advertisingBloc;
  late TrendingBloc _trendingBloc;
  late AdTrackingService _adTrackingService;
  LocationData? _currentLocation;

  @override
  void initState() {
    super.initState();
    _drinksHomeBloc = DrinksHomeBloc(
      drinksHomeUseCase: getItInjector<DrinksHomeUseCase>(),
    );
    _advertisingBloc = getItInjector<AdvertisingBloc>();
    _trendingBloc = getItInjector<TrendingBloc>()
      ..add(const TrendingEvent.loadCategories())
      ..add(const TrendingEvent.loadTrendingDrinks());
    _adTrackingService = AdTrackingService();
    _fetchLocationAndLoadPartners();
  }

  Future<void> _fetchLocationAndLoadPartners() async {
    try {
      if (await requestLocationPermission()) {
        final Location location = Location();
        final currentLocation = await location.getLocation();

        setState(() {
          _currentLocation = currentLocation;
        });

        final lat = _currentLocation?.latitude;
        final lng = _currentLocation?.longitude;

        if (lat != null && lng != null) {
          _drinksHomeBloc.add(
            DrinksHomeLoadPartners(
              latitude: lat,
              longitude: lng,
              maxDistance: 35000,
            ),
          );

          _advertisingBloc.add(
            AdvertisingEvent.loadFeaturedAds(
              latitude: lat,
              longitude: lng,
              limit: 5,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching location: $e');
    }
  }

  @override
  void dispose() {
    _drinksHomeBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<DrinksHomeBloc, DrinksHomeState>(
          bloc: _drinksHomeBloc,
          listener: (context, state) {
            if (state is Loading) {
              LoadingUtil.showLoadingDialog(context);
            } else if (state is Success) {
              Navigator.of(context).pop(); // Dismiss loading dialog
            } else if (state is Failure) {
              Navigator.of(context).pop();
              // Optionally show error message (e.g., using a SnackBar)
            }
          },
          builder: (context, state) {
            // Build UI based on state
            if (state is Success) {
              // The Success state now holds a list of ParallaxRecipeUiModel
              return _buildContent(context, state.partners);
            }
            // While loading or if there's an error, you can show a placeholder
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<ParallaxRecipeUiModel> partners,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            alignment: Alignment.topCenter,
            margin: const EdgeInsets.only(top: 16),
            child: Text(
              l10n.app_title,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'JuliusSansOne', fontSize: 24.sp),
            ).animate().fade().scale(),
          ),
          _buildFeaturedAdsCarousel(),
          TitleSubtitleWidget(
            title: l10n.meet_our_partners,
            subtitle: l10n.here_are_the_closest_partners,
          ),
          HorizontalSlidingCards(
            list: partners,
            cardsType: CardType.rectangular,
            onCardTap: (ParallaxRecipeUiModel selectedBar) {
              AppRoute.pushBar(context, selectedBar.id);
            },
          ),
          TitleSubtitleWidget(
            title: l10n.most_wanted,
            subtitle: l10n.want_a_specific_drink,
          ),
          _buildCategoryChips(),
          _buildTrendingDrinks(),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return BlocBuilder<TrendingBloc, TrendingState>(
      bloc: _trendingBloc,
      builder: (context, state) {
        if (state.drinkCategories.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.drinkCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = state.drinkCategories[index];
                final isSelected = state.selectedCategory == category.category;

                return FilterChip(
                  selected: isSelected,
                  label: Text(category.label),
                  selectedColor: barzGold,
                  checkmarkColor: barzDark,
                  backgroundColor: Colors.grey.shade200,
                  onSelected: (_) {
                    _trendingBloc.add(
                      TrendingEvent.loadCategory(category: category.category),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendingDrinks() {
    return BlocBuilder<TrendingBloc, TrendingState>(
      bloc: _trendingBloc,
      builder: (context, state) {
        if (state.isLoadingTrending || state.isLoadingCategory) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: barzGold)),
          );
        }

        final drinks = state.selectedCategory != null
            ? state.categoryDrinks
            : state.trendingDrinks;

        if (drinks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                AppLocalizations.of(context)!.no_data_available,
                style: TextStyle(color: textSecondary),
              ),
            ),
          );
        }

        return HorizontalSlidingCards(
          list: drinks
              .map(
                (drink) => ParallaxRecipeUiModel(
                  id: drink.id,
                  imageUrl: drink.picture ?? 'default_drink.png',
                  name: drink.name,
                ),
              )
              .toList(),
          cardsType: CardType.circle,
          onCardTap: (ParallaxRecipeUiModel selected) {
            final drink = drinks.firstWhere((d) => d.id == selected.id);
            _showDrinkDetails(context, drink);
          },
        );
      },
    );
  }

  Widget _buildFeaturedAdsCarousel() {
    return BlocBuilder<AdvertisingBloc, AdvertisingState>(
      bloc: _advertisingBloc,
      builder: (context, state) {
        if (state.featuredAds.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
              child: Text(
                AppLocalizations.of(context)!.featured,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 180,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.85),
                itemCount: state.featuredAds.length,
                itemBuilder: (context, index) {
                  final ad = state.featuredAds[index];
                  return FeaturedAdCard(
                    ad: ad,
                    onVisible: () {
                      _adTrackingService.trackImpression(
                        ad.campaignId,
                        AdPlacement.home,
                        latitude: _currentLocation?.latitude,
                        longitude: _currentLocation?.longitude,
                      );
                    },
                    onTap: () {
                      _adTrackingService.trackClick(
                        ad.campaignId,
                        AdPlacement.home,
                        latitude: _currentLocation?.latitude,
                        longitude: _currentLocation?.longitude,
                      );
                      context.push('/bar/${ad.barId}');
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDrinkDetails(BuildContext context, TrendingDrink drink) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                if (drink.picture != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      drink.picture!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: barzGold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.local_bar,
                          color: barzGold,
                          size: 40,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: barzGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_bar,
                      color: barzGold,
                      size: 40,
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drink.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: barzGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          drink.category ?? '',
                          style: TextStyle(
                            color: barzGold.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  currencyFormat.format(drink.price),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: barzGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (drink.description != null && drink.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                drink.description!,
                style: theme.textTheme.bodyMedium?.copyWith(color: textSecondary),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(
                  drink.available ? Icons.check_circle : Icons.cancel,
                  color: drink.available ? successGreen : errorRed,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  drink.available
                      ? 'Available'
                      : AppLocalizations.of(context)!.menu_item_unavailable,
                  style: TextStyle(
                    color: drink.available ? successGreen : errorRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
