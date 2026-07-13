import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:barz/features/advertising/domain/models/models.dart';

part 'advertising_state.freezed.dart';

/// State for advertising BLoC.
/// Contains both client-side ad data and business-side campaign data.
@freezed
abstract class AdvertisingState with _$AdvertisingState {
  const factory AdvertisingState({
    // AD SERVING STATE (Client App)
    @Default([]) List<FeaturedAd> featuredAds,
    @Default([]) List<SearchAd> searchAds,
    @Default([]) List<MapAd> mapAds,
    @Default(false) bool isLoadingFeatured,
    @Default(false) bool isLoadingSearch,
    @Default(false) bool isLoadingMap,

    // BUSINESS STATE (Business App)
    PlansResponse? plans,
    @Default(false) bool isLoadingPlans,
    AdSubscription? subscription,
    @Default(false) bool isLoadingSubscription,
    SubscriptionTrialSetupResult? trialSetup,
    @Default(false) bool isSettingUpTrial,
    @Default([]) List<AdCampaign> campaigns,
    @Default(false) bool isLoadingCampaigns,
    AdCampaign? selectedCampaign,
    @Default(false) bool isLoadingCampaign,
    CampaignAnalytics? analytics,
    @Default(false) bool isLoadingAnalytics,

    // UI STATE (Campaigns Page)
    String? filterStatus,
    String? sortBy,
    @Default('') String searchQuery,

    // COMMON STATE
    String? error,
    String? successMessage,
  }) = _AdvertisingState;
}
