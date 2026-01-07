import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/promotions/domain/models/promotion_model.dart';
import 'package:barz/features/promotions/domain/models/offer_model.dart';
import 'package:barz/features/promotions/domain/repositories/promotions_repository.dart';

class PromotionsUsecase {
  final PromotionsRepository _repository;

  PromotionsUsecase(this._repository);

  /// Get promotions near user's location (location now required by backend)
  Future<Either<Failure, List<PromotionModel>>> getPromotions({
    required double latitude,
    required double longitude,
    double maxDistance = 5000,
    bool activeOnly = true,
  }) {
    return _repository.getPromotions(
      latitude: latitude,
      longitude: longitude,
      maxDistance: maxDistance,
      activeOnly: activeOnly,
    );
  }

  Future<Either<Failure, List<PromotionModel>>> getPromotionsByDiscountType(PromoDiscountType type) {
    return _repository.getPromotionsByDiscountType(type);
  }

  Future<Either<Failure, List<PromotionModel>>> getPromotionsByBar(int barId, {bool activeOnly = true}) {
    return _repository.getPromotionsByBar(barId, activeOnly: activeOnly);
  }

  Future<Either<Failure, PromotionModel>> getPromotionById(int id) {
    return _repository.getPromotionById(id);
  }

  Future<Either<Failure, List<OfferModel>>> getOffers() {
    return _repository.getOffers();
  }

  Future<Either<Failure, List<OfferModel>>> getOffersByPartnerId(int partnerId) {
    return _repository.getOffersByPartnerId(partnerId);
  }

  Future<Either<Failure, OfferModel>> getOfferById(int id) {
    return _repository.getOfferById(id);
  }

  Future<Either<Failure, OfferModel>> redeemOffer(int offerId) {
    return _repository.redeemOffer(offerId);
  }
}
