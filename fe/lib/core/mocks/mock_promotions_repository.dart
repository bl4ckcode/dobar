import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/promotions/domain/models/promotion_model.dart';
import 'package:barz/features/promotions/domain/models/offer_model.dart';
import 'package:barz/features/promotions/domain/repositories/promotions_repository.dart';
import 'package:dartz/dartz.dart';

class MockPromotionsRepository implements PromotionsRepository {
  static final List<PromotionModel> _mockPromotions = [
    PromotionModel(
      id: 1,
      type: PromotionType.cashback,
      title: '20% Cashback',
      subtitle: 'Em todos os bares parceiros',
      description: 'Ganhe 20% de cashback em todas as compras nos bares parceiros. Válido até o fim do mês!',
      imageUrl: 'https://picsum.photos/600/300?random=10',
      priority: 1,
      startDate: DateTime.now().subtract(const Duration(days: 7)),
      endDate: DateTime.now().add(const Duration(days: 30)),
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      cashbackPercentage: 20.0,
    ),
    PromotionModel(
      id: 2,
      type: PromotionType.drink,
      title: 'Happy Hour',
      subtitle: 'Chopp em dobro',
      description: 'Das 17h às 20h, pague um chopp e leve dois! Válido de segunda a quinta.',
      imageUrl: 'https://picsum.photos/600/300?random=11',
      priority: 2,
      startDate: DateTime.now().subtract(const Duration(days: 3)),
      endDate: DateTime.now().add(const Duration(days: 60)),
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    PromotionModel(
      id: 3,
      type: PromotionType.partner,
      title: 'Novo Parceiro!',
      subtitle: 'Cervejaria Artesanal',
      description: 'Conheça nosso mais novo bar parceiro com cervejas artesanais exclusivas.',
      imageUrl: 'https://picsum.photos/600/300?random=12',
      partnerId: 3,
      priority: 3,
      startDate: DateTime.now().subtract(const Duration(days: 1)),
      endDate: DateTime.now().add(const Duration(days: 90)),
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  static final List<OfferModel> _mockOffers = [
    OfferModel(
      id: 1,
      partnerId: 1,
      title: '10% OFF na primeira compra',
      description: 'Desconto exclusivo para novos clientes',
      type: OfferType.discount,
      discountType: DiscountType.percentage,
      discountValue: 10.0,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      endDate: DateTime.now().add(const Duration(days: 60)),
      isActive: true,
      isPremiumOnly: false,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    OfferModel(
      id: 2,
      partnerId: 2,
      title: 'Petisco Grátis',
      description: 'Compras acima de R\$ 50 ganham petisco grátis',
      type: OfferType.freeItem,
      freeItemName: 'Porção de Batata Frita',
      minOrderValue: 50.0,
      startDate: DateTime.now().subtract(const Duration(days: 7)),
      endDate: DateTime.now().add(const Duration(days: 30)),
      isActive: true,
      isPremiumOnly: false,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];

  @override
  Future<Either<Failure, List<PromotionModel>>> getPromotions() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return Right(_mockPromotions);
  }

  @override
  Future<Either<Failure, List<PromotionModel>>> getPromotionsByType(PromotionType type) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final filtered = _mockPromotions.where((p) => p.type == type).toList();
    return Right(filtered);
  }

  @override
  Future<Either<Failure, PromotionModel>> getPromotionById(int id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final promo = _mockPromotions.firstWhere(
      (p) => p.id == id,
      orElse: () => _mockPromotions.first,
    );
    return Right(promo);
  }

  @override
  Future<Either<Failure, List<OfferModel>>> getOffers() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return Right(_mockOffers);
  }

  @override
  Future<Either<Failure, List<OfferModel>>> getOffersByPartnerId(int partnerId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final filtered = _mockOffers.where((o) => o.partnerId == partnerId).toList();
    return Right(filtered);
  }

  @override
  Future<Either<Failure, OfferModel>> getOfferById(int id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final offer = _mockOffers.firstWhere(
      (o) => o.id == id,
      orElse: () => _mockOffers.first,
    );
    return Right(offer);
  }

  @override
  Future<Either<Failure, OfferModel>> redeemOffer(int offerId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final offer = _mockOffers.firstWhere(
      (o) => o.id == offerId,
      orElse: () => _mockOffers.first,
    );
    return Right(offer);
  }
}
