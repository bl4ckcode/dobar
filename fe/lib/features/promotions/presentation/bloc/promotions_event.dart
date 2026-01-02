import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:barz/features/promotions/domain/models/promotion_model.dart';

part 'promotions_event.freezed.dart';

@freezed
sealed class PromotionsEvent with _$PromotionsEvent {
  const factory PromotionsEvent.loadPromotions({@Default(true) bool activeOnly}) = LoadPromotions;
  const factory PromotionsEvent.loadPromotionsByDiscountType(PromoDiscountType type) = LoadPromotionsByDiscountType;
  const factory PromotionsEvent.loadPromotionsByBar(int barId, {@Default(true) bool activeOnly}) = LoadPromotionsByBar;
  const factory PromotionsEvent.loadNearbyPromotions({
    required double latitude,
    required double longitude,
    @Default(5000.0) double maxDistance,
    @Default(true) bool activeOnly,
  }) = LoadNearbyPromotions;
  const factory PromotionsEvent.loadPromotionById(int id) = LoadPromotionById;
  const factory PromotionsEvent.loadOffers() = LoadOffers;
  const factory PromotionsEvent.loadOffersByPartnerId(int partnerId) = LoadOffersByPartnerId;
  const factory PromotionsEvent.loadOfferById(int id) = LoadOfferById;
  const factory PromotionsEvent.redeemOffer(int offerId) = RedeemOffer;
  const factory PromotionsEvent.clearError() = ClearPromotionsError;
}
