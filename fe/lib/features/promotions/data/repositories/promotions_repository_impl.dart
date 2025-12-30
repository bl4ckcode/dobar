import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/promotions/data/datasources/promotions_datasource.dart';
import 'package:barz/features/promotions/domain/models/promotion_model.dart';
import 'package:barz/features/promotions/domain/models/offer_model.dart';
import 'package:barz/features/promotions/domain/repositories/promotions_repository.dart';

class PromotionsRepositoryImpl implements PromotionsRepository {
  final PromotionsDatasource _datasource;

  PromotionsRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<PromotionModel>>> getPromotions() async {
    try {
      final result = await _datasource.getPromotions();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, List<PromotionModel>>> getPromotionsByType(PromotionType type) async {
    try {
      final result = await _datasource.getPromotionsByType(type);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, PromotionModel>> getPromotionById(int id) async {
    try {
      final result = await _datasource.getPromotionById(id);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, List<OfferModel>>> getOffers() async {
    try {
      final result = await _datasource.getOffers();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, List<OfferModel>>> getOffersByPartnerId(int partnerId) async {
    try {
      final result = await _datasource.getOffersByPartnerId(partnerId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, OfferModel>> getOfferById(int id) async {
    try {
      final result = await _datasource.getOfferById(id);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, OfferModel>> redeemOffer(int offerId) async {
    try {
      final result = await _datasource.redeemOffer(offerId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }
}
