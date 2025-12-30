import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:barz/features/promotions/domain/models/promotion_model.dart';
import 'package:barz/features/promotions/domain/models/offer_model.dart';

part 'promotions_state.freezed.dart';

@freezed
class PromotionsState with _$PromotionsState {
  const factory PromotionsState({
    @Default([]) List<PromotionModel> promotions,
    @Default([]) List<OfferModel> offers,
    @Default(false) bool isLoading,
    @Default(false) bool isLoadingOffers,
    String? error,
    PromotionModel? selectedPromotion,
    OfferModel? selectedOffer,
    OfferModel? redeemedOffer,
  }) = _PromotionsState;
}
