import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/orders/domain/models/order_model.dart';
import 'package:barz/features/orders/domain/repositories/abstract_order_repository.dart';
import 'package:dartz/dartz.dart';

class OrderUsecase {
  final AbstractOrderRepository repository;

  OrderUsecase({required this.repository});

  Future<Either<Failure, PaginatedOrders>> getMyOrders({
    int limit = 20,
    String? cursor,
    String? status,
  }) {
    return repository.getMyOrders(
      limit: limit,
      cursor: cursor,
      status: status,
    );
  }

  Future<Either<Failure, OrderModel>> getOrder(int orderId) {
    return repository.getOrder(orderId);
  }

  Future<Either<Failure, OrderModel>> getOrderTimeline(int orderId) {
    return repository.getOrderTimeline(orderId);
  }

  Future<Either<Failure, OrderModel>> cancelOrder(int orderId) {
    return repository.cancelOrder(orderId);
  }
}
