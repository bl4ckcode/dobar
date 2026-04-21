import 'package:barz/features/bars/domain/repositories/abstract_bar_repository.dart';
import 'package:barz/features/cart/domain/models/cart_model.dart';
import 'package:barz/features/cart/domain/models/cart_models.dart';
import 'package:barz/features/cart/domain/usecases/cart_usecase.dart';
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:barz/features/cart/presentation/bloc/cart_event.dart';
import 'package:barz/features/cart/presentation/bloc/cart_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCartUsecase extends Mock implements CartUsecase {}

class MockBarRepository extends Mock implements AbstractBarRepository {}

void main() {
  late CartBloc cartBloc;
  late MockCartUsecase mockCartUsecase;
  late MockBarRepository mockBarRepository;

  setUp(() {
    mockCartUsecase = MockCartUsecase();
    mockBarRepository = MockBarRepository();
    cartBloc = CartBloc(
      cartUsecase: mockCartUsecase,
      barRepository: mockBarRepository,
    );
  });

  tearDown(() {
    cartBloc.close();
  });

  final tLocationConfig = LocationConfig(
    method: LocationMethod.tableNumber,
    spots: [],
  );

  final tPromotions = [
    Promotion(
      id: 'promo_1',
      name: 'Happy Hour',
      benefit: '10% off',
      type: 'discount',
      value: 10,
    ),
  ];

  final tCartModel = CartModel(
    id: 1,
    userId: 1,
    items: [],
    totalItems: 0,
    subtotal: 0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  test(
    'LoadCheckoutConfig emits loaded state with config and promotions',
    () async {
      // Arrange
      // First, emit CartLoaded to simulate initial state
      // We cannot easily inject initial state, but we can emit it
      // Or we can mock the state handling?
      // CartBloc checks `if (state is CartLoaded)` in `_onLoadCheckoutConfig`
      // So we need to be in CartLoaded state.

      // Hack: We mock getCart to return tCartModel, and add LoadCart event first?
      // Or we can just test the logic if we could set state.
      // Since we can't set state directly, we'll assume we flow from LoadCart -> LoadCheckoutConfig.

      when(
        () => mockCartUsecase.getCart(),
      ).thenAnswer((_) async => Right(tCartModel));

      when(
        () => mockBarRepository.getLocationConfig(any()),
      ).thenAnswer((_) async => Right(tLocationConfig));
      when(
        () => mockBarRepository.getPromotions(any()),
      ).thenAnswer((_) async => Right(tPromotions));

      // Act
      cartBloc.add(LoadCart());
      await Future.delayed(Duration.zero); // Wait for LoadCart

      cartBloc.add(LoadCheckoutConfig(barId: 1));
      await Future.delayed(Duration.zero); // Wait for processing

      // Assert
      expect(cartBloc.state, isA<CartLoaded>());
      final state = cartBloc.state as CartLoaded;
      expect(state.locationConfig, equals(tLocationConfig));
      expect(state.activePromotions, equals(tPromotions));
    },
  );

  test('Checkout calls usecase with correct parameters', () async {
    // Arrange
    final tCheckoutResult = CheckoutResult(
      orderId: 123,
      status: 'success',
      total: 100,
      message: 'Order created',
    );

    when(
      () => mockCartUsecase.checkout(
        orderType: any(named: 'orderType'),
        paymentMethod: any(named: 'paymentMethod'),
        tableNumber: any(named: 'tableNumber'),
        specialInstructions: any(named: 'specialInstructions'),
        activePromotionIds: any(named: 'activePromotionIds'),
      ),
    ).thenAnswer((_) async => Right(tCheckoutResult));

    // Act
    cartBloc.add(
      Checkout(
        orderType: 'dine_in',
        paymentMethod: 'credit_card',
        tableNumber: '5',
        specialInstructions: 'No ice',
        activePromotionIds: ['promo_1'],
      ),
    );

    await Future.delayed(Duration.zero);

    // Assert
    verify(
      () => mockCartUsecase.checkout(
        orderType: 'dine_in',
        paymentMethod: 'credit_card',
        tableNumber: '5',
        specialInstructions: 'No ice',
        activePromotionIds: ['promo_1'],
      ),
    ).called(1);

    expect(cartBloc.state, isA<CheckoutSuccess>());
  });
}
