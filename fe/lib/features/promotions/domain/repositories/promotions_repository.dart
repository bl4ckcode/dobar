import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/promotions/domain/models/promotion_model.dart';
import 'package:barz/features/promotions/domain/models/offer_model.dart';

abstract class PromotionsRepository {
  /// Get promotions near user's location (location now required by backend)
  Future<Either<Failure, List<PromotionModel>>> getPromotions({
    required double latitude,
    required double longitude,
    double maxDistance = 5000,
    bool activeOnly = true,
  });
  Future<Either<Failure, List<PromotionModel>>> getPromotionsByDiscountType(PromoDiscountType type);
  Future<Either<Failure, List<PromotionModel>>> getPromotionsByBar(int barId, {bool activeOnly = true});
  Future<Either<Failure, PromotionModel>> getPromotionById(int id);
  Future<Either<Failure, List<OfferModel>>> getOffers();
  Future<Either<Failure, List<OfferModel>>> getOffersByPartnerId(int partnerId);
  Future<Either<Failure, OfferModel>> getOfferById(int id);
  Future<Either<Failure, OfferModel>> redeemOffer(int offerId);
}
