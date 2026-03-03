import 'package:barz/core/error/failures.dart';
import 'package:barz/features/orders/data/repositories/live_orders_repository_impl.dart';
import 'package:barz/features/orders/domain/models/live_order_model.dart';
import 'package:dartz/dartz.dart';

class GetLiveOrdersUseCase {
  final LiveOrdersRepository repository;

  GetLiveOrdersUseCase(this.repository);

  Future<Either<Failure, List<LiveOrderModel>>> call(int barId) {
    return repository.getLiveOrders(barId);
  }
}

class UpdateLiveOrderStatusUseCase {
  final LiveOrdersRepository repository;

  UpdateLiveOrderStatusUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required int barId,
    required String orderId,
    required String newStatus,
  }) {
    return repository.updateOrderStatus(barId, orderId, newStatus);
  }
}
