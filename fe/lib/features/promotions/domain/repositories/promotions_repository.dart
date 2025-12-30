import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/promotions/domain/models/promotion_model.dart';
import 'package:barz/features/promotions/domain/models/offer_model.dart';

abstract class PromotionsRepository {
  Future<Either<Failure, List<PromotionModel>>> getPromotions();
  Future<Either<Failure, List<PromotionModel>>> getPromotionsByType(PromotionType type);
  Future<Either<Failure, PromotionModel>> getPromotionById(int id);
  Future<Either<Failure, List<OfferModel>>> getOffers();
  Future<Either<Failure, List<OfferModel>>> getOffersByPartnerId(int partnerId);
  Future<Either<Failure, OfferModel>> getOfferById(int id);
  Future<Either<Failure, OfferModel>> redeemOffer(int offerId);
}
