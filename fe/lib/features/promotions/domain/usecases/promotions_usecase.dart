import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/promotions/domain/models/promotion_model.dart';
import 'package:barz/features/promotions/domain/models/offer_model.dart';
import 'package:barz/features/promotions/domain/repositories/promotions_repository.dart';

class PromotionsUsecase {
  final PromotionsRepository _repository;

  PromotionsUsecase(this._repository);

  Future<Either<Failure, List<PromotionModel>>> getPromotions() {
    return _repository.getPromotions();
  }

  Future<Either<Failure, List<PromotionModel>>> getPromotionsByType(PromotionType type) {
    return _repository.getPromotionsByType(type);
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
