import 'package:equatable/equatable.dart';
import 'package:barz/features/promotions/domain/models/promotion_model.dart';
import 'package:barz/features/promotions/domain/models/offer_model.dart';

class PromotionsState extends Equatable {
  final List<PromotionModel> promotions;
  final List<OfferModel> offers;
  final bool isLoading;
  final bool isLoadingOffers;
  final String? error;
  final PromotionModel? selectedPromotion;
  final OfferModel? selectedOffer;
  final OfferModel? redeemedOffer;

  const PromotionsState({
    this.promotions = const [],
    this.offers = const [],
    this.isLoading = false,
    this.isLoadingOffers = false,
    this.error,
    this.selectedPromotion,
    this.selectedOffer,
    this.redeemedOffer,
  });

  PromotionsState copyWith({
    List<PromotionModel>? promotions,
    List<OfferModel>? offers,
    bool? isLoading,
    bool? isLoadingOffers,
    String? error,
    PromotionModel? selectedPromotion,
    OfferModel? selectedOffer,
    OfferModel? redeemedOffer,
  }) {
    return PromotionsState(
      promotions: promotions ?? this.promotions,
      offers: offers ?? this.offers,
      isLoading: isLoading ?? this.isLoading,
      isLoadingOffers: isLoadingOffers ?? this.isLoadingOffers,
      error: error ?? this.error,
      selectedPromotion: selectedPromotion ?? this.selectedPromotion,
      selectedOffer: selectedOffer ?? this.selectedOffer,
      redeemedOffer: redeemedOffer ?? this.redeemedOffer,
    );
  }

  @override
  List<Object?> get props => [
    promotions,
    offers,
    isLoading,
    isLoadingOffers,
    error,
    selectedPromotion,
    selectedOffer,
    redeemedOffer,
  ];
}
