import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/advertising/domain/usecases/advertising_usecase.dart';
import 'advertising_event.dart';
import 'advertising_state.dart';

/// BLoC for advertising operations.
/// Handles both client-side ad serving and business-side campaign management.
class AdvertisingBloc extends Bloc<AdvertisingEvent, AdvertisingState> {
  final AdvertisingUsecase _usecase;

  AdvertisingBloc(this._usecase) : super(AdvertisingState.initial()) {
    // Ad serving events
    on<LoadFeaturedAds>(_onLoadFeaturedAds);
    on<LoadSearchAds>(_onLoadSearchAds);
    on<LoadMapAds>(_onLoadMapAds);
    on<TrackImpression>(_onTrackImpression);
    on<TrackClick>(_onTrackClick);

    // Business events
    on<LoadPlans>(_onLoadPlans);
    on<LoadSubscription>(_onLoadSubscription);
    on<CreateSubscription>(_onCreateSubscription);
    on<CancelSubscription>(_onCancelSubscription);
    on<LoadCampaigns>(_onLoadCampaigns);
    on<LoadCampaign>(_onLoadCampaign);
    on<CreateCampaignEvent>(_onCreateCampaign);
    on<PauseCampaign>(_onPauseCampaign);
    on<ResumeCampaign>(_onResumeCampaign);
    on<LoadAnalytics>(_onLoadAnalytics);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AD SERVING HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _onLoadFeaturedAds(
    LoadFeaturedAds event,
    Emitter<AdvertisingState> emit,
  ) async {
    emit(state.copyWith(isLoadingFeatured: true, error: null));
    try {
      final ads = await _usecase.getFeaturedAds(
        latitude: event.latitude,
        longitude: event.longitude,
        limit: event.limit,
      );
      emit(state.copyWith(featuredAds: ads, isLoadingFeatured: false));
    } catch (e) {
      emit(state.copyWith(
        isLoadingFeatured: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onLoadSearchAds(
    LoadSearchAds event,
    Emitter<AdvertisingState> emit,
  ) async {
    emit(state.copyWith(isLoadingSearch: true, error: null));
    try {
      final ads = await _usecase.getSearchAds(
        latitude: event.latitude,
        longitude: event.longitude,
        query: event.query,
        category: event.category,
        limit: event.limit,
      );
      emit(state.copyWith(searchAds: ads, isLoadingSearch: false));
    } catch (e) {
      emit(state.copyWith(
        isLoadingSearch: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMapAds(
    LoadMapAds event,
    Emitter<AdvertisingState> emit,
  ) async {
    emit(state.copyWith(isLoadingMap: true, error: null));
    try {
      final ads = await _usecase.getMapAds(
        latitude: event.latitude,
        longitude: event.longitude,
        zoomLevel: event.zoomLevel,
        limit: event.limit,
      );
      emit(state.copyWith(mapAds: ads, isLoadingMap: false));
    } catch (e) {
      emit(state.copyWith(
        isLoadingMap: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onTrackImpression(
    TrackImpression event,
    Emitter<AdvertisingState> emit,
  ) async {
    // Fire and forget - don't block UI
    _usecase.trackImpression(
      campaignId: event.campaignId,
      placement: event.placement,
      latitude: event.latitude,
      longitude: event.longitude,
    );
  }

  Future<void> _onTrackClick(
    TrackClick event,
    Emitter<AdvertisingState> emit,
  ) async {
    // Fire and forget - don't block UI
    _usecase.trackClick(
      campaignId: event.campaignId,
      placement: event.placement,
      latitude: event.latitude,
      longitude: event.longitude,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUSINESS HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _onLoadPlans(
    LoadPlans event,
    Emitter<AdvertisingState> emit,
  ) async {
    emit(state.copyWith(isLoadingPlans: true, error: null));
    try {
      final plans = await _usecase.getPlans(regionCode: event.regionCode);
      emit(state.copyWith(plans: plans, isLoadingPlans: false));
    } catch (e) {
      emit(state.copyWith(
        isLoadingPlans: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onLoadSubscription(
    LoadSubscription event,
    Emitter<AdvertisingState> emit,
  ) async {
    emit(state.copyWith(isLoadingSubscription: true, error: null));
    try {
      final subscription = await _usecase.getSubscription(event.barId);
      emit(state.copyWith(
        subscription: subscription,
        isLoadingSubscription: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingSubscription: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onCreateSubscription(
    CreateSubscription event,
    Emitter<AdvertisingState> emit,
  ) async {
    emit(state.copyWith(isLoadingSubscription: true, error: null));
    try {
      final subscription = await _usecase.createSubscription(
        barId: event.barId,
        tier: event.tier,
        regionCode: event.regionCode,
      );
      emit(state.copyWith(
        subscription: subscription,
        isLoadingSubscription: false,
        successMessage: 'Subscription created successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingSubscription: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onCancelSubscription(
    CancelSubscription event,
    Emitter<AdvertisingState> emit,
  ) async {
    emit(state.copyWith(isLoadingSubscription: true, error: null));
    try {
      await _usecase.cancelSubscription(event.subscriptionId);
      emit(state.copyWith(
        subscription: null,
        isLoadingSubscription: false,
        successMessage: 'Subscription cancelled',
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingSubscription: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onLoadCampaigns(
    LoadCampaigns event,
    Emitter<AdvertisingState> emit,
  ) async {
    emit(state.copyWith(isLoadingCampaigns: true, error: null));
    try {
      final campaigns = await _usecase.getCampaigns(event.barId);
      emit(state.copyWith(campaigns: campaigns, isLoadingCampaigns: false));
    } catch (e) {
      emit(state.copyWith(
        isLoadingCampaigns: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onLoadCampaign(
    LoadCampaign event,
    Emitter<AdvertisingState> emit,
  ) async {
    emit(state.copyWith(isLoadingCampaign: true, error: null));
    try {
      final campaign = await _usecase.getCampaign(event.campaignId);
      emit(state.copyWith(
        selectedCampaign: campaign,
        isLoadingCampaign: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingCampaign: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onCreateCampaign(
    CreateCampaignEvent event,
    Emitter<AdvertisingState> emit,
  ) async {
    emit(state.copyWith(isLoadingCampaign: true, error: null));
    try {
      final campaign = await _usecase.createCampaign(event.request);
      final updatedCampaigns = [...state.campaigns, campaign];
      emit(state.copyWith(
        campaigns: updatedCampaigns,
        selectedCampaign: campaign,
        isLoadingCampaign: false,
        successMessage: 'Campaign created successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingCampaign: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onPauseCampaign(
    PauseCampaign event,
    Emitter<AdvertisingState> emit,
  ) async {
    emit(state.copyWith(isLoadingCampaign: true, error: null));
    try {
      final campaign = await _usecase.pauseCampaign(event.campaignId);
      final updatedCampaigns = state.campaigns
          .map((c) => c.id == campaign.id ? campaign : c)
          .toList();
      emit(state.copyWith(
        campaigns: updatedCampaigns,
        selectedCampaign: campaign,
        isLoadingCampaign: false,
        successMessage: 'Campaign paused',
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingCampaign: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onResumeCampaign(
    ResumeCampaign event,
    Emitter<AdvertisingState> emit,
  ) async {
    emit(state.copyWith(isLoadingCampaign: true, error: null));
    try {
      final campaign = await _usecase.resumeCampaign(event.campaignId);
      final updatedCampaigns = state.campaigns
          .map((c) => c.id == campaign.id ? campaign : c)
          .toList();
      emit(state.copyWith(
        campaigns: updatedCampaigns,
        selectedCampaign: campaign,
        isLoadingCampaign: false,
        successMessage: 'Campaign resumed',
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingCampaign: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onLoadAnalytics(
    LoadAnalytics event,
    Emitter<AdvertisingState> emit,
  ) async {
    emit(state.copyWith(isLoadingAnalytics: true, error: null));
    try {
      final analytics = await _usecase.getCampaignAnalytics(event.campaignId);
      emit(state.copyWith(analytics: analytics, isLoadingAnalytics: false));
    } catch (e) {
      emit(state.copyWith(
        isLoadingAnalytics: false,
        error: e.toString(),
      ));
    }
  }
}
