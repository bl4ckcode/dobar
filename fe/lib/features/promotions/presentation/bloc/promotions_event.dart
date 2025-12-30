import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:barz/features/promotions/domain/models/promotion_model.dart';

part 'promotions_event.freezed.dart';

@freezed
class PromotionsEvent with _$PromotionsEvent {
  const factory PromotionsEvent.loadPromotions() = LoadPromotions;
  const factory PromotionsEvent.loadPromotionsByType(PromotionType type) = LoadPromotionsByType;
  const factory PromotionsEvent.loadPromotionById(int id) = LoadPromotionById;
  const factory PromotionsEvent.loadOffers() = LoadOffers;
  const factory PromotionsEvent.loadOffersByPartnerId(int partnerId) = LoadOffersByPartnerId;
  const factory PromotionsEvent.loadOfferById(int id) = LoadOfferById;
  const factory PromotionsEvent.redeemOffer(int offerId) = RedeemOffer;
  const factory PromotionsEvent.clearError() = ClearPromotionsError;
}
