import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/bars/domain/models/bar_model.dart';
import 'package:barz/features/bars/domain/models/menu_model.dart';
import 'package:barz/features/bars/domain/repositories/abstract_bar_repository.dart';
import 'package:dartz/dartz.dart';

class MockBarRepository implements AbstractBarRepository {
  static final List<BarModel> _mockBars = [
    BarModel(
      id: 1,
      name: 'Bar do Zé',
      address: 'Rua Augusta, 1234, São Paulo, SP',
      phoneNumber: '+5511988887777',
      email: 'contato@bardoze.com.br',
      ownerId: 1,
      imageUrl: 'https://picsum.photos/400/300?random=1',
      approximateLocation: 0.5,
    ),
    BarModel(
      id: 2,
      name: 'Boteco da Esquina',
      address: 'Av. Paulista, 2000, São Paulo, SP',
      phoneNumber: '+5511977776666',
      email: 'contato@boteco.com.br',
      ownerId: 1,
      imageUrl: 'https://picsum.photos/400/300?random=2',
      approximateLocation: 1.2,
    ),
    BarModel(
      id: 3,
      name: 'Cervejaria Artesanal',
      address: 'Rua Oscar Freire, 500, São Paulo, SP',
      phoneNumber: '+5511966665555',
      email: 'contato@cervejaria.com.br',
      ownerId: 1,
      imageUrl: 'https://picsum.photos/400/300?random=3',
      approximateLocation: 2.0,
    ),
    BarModel(
      id: 4,
      name: 'Rooftop Lounge',
      address: 'Al. Santos, 800, São Paulo, SP',
      phoneNumber: '+5511955554444',
      email: 'contato@rooftop.com.br',
      ownerId: 1,
      imageUrl: 'https://picsum.photos/400/300?random=4',
      approximateLocation: 3.5,
    ),
    BarModel(
      id: 5,
      name: 'Pub Irlandês',
      address: 'Rua Haddock Lobo, 300, São Paulo, SP',
      phoneNumber: '+5511944443333',
      email: 'contato@pubirl.com.br',
      ownerId: 1,
      imageUrl: 'https://picsum.photos/400/300?random=5',
      approximateLocation: 4.0,
    ),
  ];

  @override
  Future<Either<Failure, List<BarModel>>> getNearbyBars(
      double lat, double lng, double maxDistance) async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    return Right(_mockBars);
  }

  @override
  Future<Either<Failure, BarModel>> getBar(int barId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final bar = _mockBars.firstWhere(
      (b) => b.id == barId,
      orElse: () => _mockBars.first,
    );
    return Right(bar);
  }

  @override
  Future<Either<Failure, List<MenuModel>>> getBarMenus(int barId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Right([
      MenuModel(
        id: 1,
        barId: barId,
        items: [
          MenuItemModel(id: 1, itemName: 'Cerveja Pilsen', price: 12.00, description: 'Chopp 500ml', category: 'Bebidas'),
          MenuItemModel(id: 2, itemName: 'Caipirinha', price: 18.00, description: 'Limão, cachaça, açúcar', category: 'Bebidas'),
          MenuItemModel(id: 3, itemName: 'Suco Natural', price: 10.00, description: 'Laranja, limão ou abacaxi', category: 'Bebidas'),
        ],
      ),
      MenuModel(
        id: 2,
        barId: barId,
        items: [
          MenuItemModel(id: 4, itemName: 'Porção de Batata Frita', price: 25.00, description: 'Com cheddar e bacon', category: 'Petiscos'),
          MenuItemModel(id: 5, itemName: 'Bolinho de Bacalhau', price: 30.00, description: '8 unidades', category: 'Petiscos'),
          MenuItemModel(id: 6, itemName: 'Tábua de Frios', price: 45.00, description: 'Queijos e embutidos', category: 'Petiscos'),
        ],
      ),
      MenuModel(
        id: 3,
        barId: barId,
        items: [
          MenuItemModel(id: 7, itemName: 'Hambúrguer Artesanal', price: 38.00, description: 'Blend 180g, queijo, bacon', category: 'Pratos'),
          MenuItemModel(id: 8, itemName: 'Picanha na Chapa', price: 65.00, description: 'Com arroz, farofa e vinagrete', category: 'Pratos'),
        ],
      ),
    ]);
  }
}
