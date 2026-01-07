import 'package:equatable/equatable.dart';
import 'package:barz/features/advertising/domain/models/models.dart';

/// State for advertising BLoC.
/// Contains both client-side ad data and business-side campaign data.
class AdvertisingState extends Equatable {
  // AD SERVING STATE (Client App)
  final List<FeaturedAd> featuredAds;
  final List<SearchAd> searchAds;
  final List<MapAd> mapAds;
  final bool isLoadingFeatured;
  final bool isLoadingSearch;
  final bool isLoadingMap;

  // BUSINESS STATE (Business App)
  final PlansResponse? plans;
  final bool isLoadingPlans;
  final AdSubscription? subscription;
  final bool isLoadingSubscription;
  final List<AdCampaign> campaigns;
  final bool isLoadingCampaigns;
  final AdCampaign? selectedCampaign;
  final bool isLoadingCampaign;
  final CampaignAnalytics? analytics;
  final bool isLoadingAnalytics;

  // COMMON STATE
  final String? error;
  final String? successMessage;

  const AdvertisingState({
    this.featuredAds = const [],
    this.searchAds = const [],
    this.mapAds = const [],
    this.isLoadingFeatured = false,
    this.isLoadingSearch = false,
    this.isLoadingMap = false,
    this.plans,
    this.isLoadingPlans = false,
    this.subscription,
    this.isLoadingSubscription = false,
    this.campaigns = const [],
    this.isLoadingCampaigns = false,
    this.selectedCampaign,
    this.isLoadingCampaign = false,
    this.analytics,
    this.isLoadingAnalytics = false,
    this.error,
    this.successMessage,
  });

  AdvertisingState copyWith({
    List<FeaturedAd>? featuredAds,
    List<SearchAd>? searchAds,
    List<MapAd>? mapAds,
    bool? isLoadingFeatured,
    bool? isLoadingSearch,
    bool? isLoadingMap,
    PlansResponse? plans,
    bool? isLoadingPlans,
    AdSubscription? subscription,
    bool? isLoadingSubscription,
    List<AdCampaign>? campaigns,
    bool? isLoadingCampaigns,
    AdCampaign? selectedCampaign,
    bool? isLoadingCampaign,
    CampaignAnalytics? analytics,
    bool? isLoadingAnalytics,
    String? error,
    String? successMessage,
  }) {
    return AdvertisingState(
      featuredAds: featuredAds ?? this.featuredAds,
      searchAds: searchAds ?? this.searchAds,
      mapAds: mapAds ?? this.mapAds,
      isLoadingFeatured: isLoadingFeatured ?? this.isLoadingFeatured,
      isLoadingSearch: isLoadingSearch ?? this.isLoadingSearch,
      isLoadingMap: isLoadingMap ?? this.isLoadingMap,
      plans: plans ?? this.plans,
      isLoadingPlans: isLoadingPlans ?? this.isLoadingPlans,
      subscription: subscription ?? this.subscription,
      isLoadingSubscription: isLoadingSubscription ?? this.isLoadingSubscription,
      campaigns: campaigns ?? this.campaigns,
      isLoadingCampaigns: isLoadingCampaigns ?? this.isLoadingCampaigns,
      selectedCampaign: selectedCampaign ?? this.selectedCampaign,
      isLoadingCampaign: isLoadingCampaign ?? this.isLoadingCampaign,
      analytics: analytics ?? this.analytics,
      isLoadingAnalytics: isLoadingAnalytics ?? this.isLoadingAnalytics,
      error: error,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
        featuredAds,
        searchAds,
        mapAds,
        isLoadingFeatured,
        isLoadingSearch,
        isLoadingMap,
        plans,
        isLoadingPlans,
        subscription,
        isLoadingSubscription,
        campaigns,
        isLoadingCampaigns,
        selectedCampaign,
        isLoadingCampaign,
        analytics,
        isLoadingAnalytics,
        error,
        successMessage,
      ];
}
