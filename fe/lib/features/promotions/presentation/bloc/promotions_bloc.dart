import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/promotions/domain/usecases/promotions_usecase.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_event.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_state.dart';

class PromotionsBloc extends Bloc<PromotionsEvent, PromotionsState> {
  final PromotionsUsecase _usecase;

  PromotionsBloc(this._usecase) : super(const PromotionsState()) {
    on<LoadPromotions>(_onLoadPromotions);
    on<LoadPromotionsByDiscountType>(_onLoadPromotionsByDiscountType);
    on<LoadPromotionsByBar>(_onLoadPromotionsByBar);
    on<LoadNearbyPromotions>(_onLoadNearbyPromotions);
    on<LoadPromotionById>(_onLoadPromotionById);
    on<LoadOffers>(_onLoadOffers);
    on<LoadOffersByPartnerId>(_onLoadOffersByPartnerId);
    on<LoadOfferById>(_onLoadOfferById);
    on<RedeemOffer>(_onRedeemOffer);
    on<ClearPromotionsError>(_onClearError);
  }

  Future<void> _onLoadPromotions(
    LoadPromotions event,
    Emitter<PromotionsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await _usecase.getPromotions(activeOnly: event.activeOnly);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.errorMessage)),
      (promotions) => emit(state.copyWith(isLoading: false, promotions: promotions)),
    );
  }

  Future<void> _onLoadPromotionsByDiscountType(
    LoadPromotionsByDiscountType event,
    Emitter<PromotionsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await _usecase.getPromotionsByDiscountType(event.type);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.errorMessage)),
      (promotions) => emit(state.copyWith(isLoading: false, promotions: promotions)),
    );
  }

  Future<void> _onLoadPromotionsByBar(
    LoadPromotionsByBar event,
    Emitter<PromotionsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await _usecase.getPromotionsByBar(event.barId, activeOnly: event.activeOnly);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.errorMessage)),
      (promotions) => emit(state.copyWith(isLoading: false, promotions: promotions)),
    );
  }

  Future<void> _onLoadNearbyPromotions(
    LoadNearbyPromotions event,
    Emitter<PromotionsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await _usecase.getNearbyPromotions(
      latitude: event.latitude,
      longitude: event.longitude,
      maxDistance: event.maxDistance,
      activeOnly: event.activeOnly,
    );
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.errorMessage)),
      (promotions) => emit(state.copyWith(isLoading: false, promotions: promotions)),
    );
  }

  Future<void> _onLoadPromotionById(
    LoadPromotionById event,
    Emitter<PromotionsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await _usecase.getPromotionById(event.id);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.errorMessage)),
      (promotion) => emit(state.copyWith(isLoading: false, selectedPromotion: promotion)),
    );
  }

  Future<void> _onLoadOffers(
    LoadOffers event,
    Emitter<PromotionsState> emit,
  ) async {
    emit(state.copyWith(isLoadingOffers: true, error: null));
    final result = await _usecase.getOffers();
    result.fold(
      (failure) => emit(state.copyWith(isLoadingOffers: false, error: failure.errorMessage)),
      (offers) => emit(state.copyWith(isLoadingOffers: false, offers: offers)),
    );
  }

  Future<void> _onLoadOffersByPartnerId(
    LoadOffersByPartnerId event,
    Emitter<PromotionsState> emit,
  ) async {
    emit(state.copyWith(isLoadingOffers: true, error: null));
    final result = await _usecase.getOffersByPartnerId(event.partnerId);
    result.fold(
      (failure) => emit(state.copyWith(isLoadingOffers: false, error: failure.errorMessage)),
      (offers) => emit(state.copyWith(isLoadingOffers: false, offers: offers)),
    );
  }

  Future<void> _onLoadOfferById(
    LoadOfferById event,
    Emitter<PromotionsState> emit,
  ) async {
    emit(state.copyWith(isLoadingOffers: true, error: null));
    final result = await _usecase.getOfferById(event.id);
    result.fold(
      (failure) => emit(state.copyWith(isLoadingOffers: false, error: failure.errorMessage)),
      (offer) => emit(state.copyWith(isLoadingOffers: false, selectedOffer: offer)),
    );
  }

  Future<void> _onRedeemOffer(
    RedeemOffer event,
    Emitter<PromotionsState> emit,
  ) async {
    emit(state.copyWith(isLoadingOffers: true, error: null));
    final result = await _usecase.redeemOffer(event.offerId);
    result.fold(
      (failure) => emit(state.copyWith(isLoadingOffers: false, error: failure.errorMessage)),
      (offer) => emit(state.copyWith(isLoadingOffers: false, redeemedOffer: offer)),
    );
  }

  void _onClearError(
    ClearPromotionsError event,
    Emitter<PromotionsState> emit,
  ) {
    emit(state.copyWith(error: null));
  }
}
