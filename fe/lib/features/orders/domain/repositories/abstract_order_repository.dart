import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/orders/domain/models/order_model.dart';
import 'package:dartz/dartz.dart';

abstract class AbstractOrderRepository {
  Future<Either<Failure, PaginatedOrders>> getMyOrders({
    required int page,
    required int pageSize,
    String? status,
  });
  Future<Either<Failure, OrderModel>> getOrder(int orderId);
  Future<Either<Failure, OrderModel>> getOrderTimeline(int orderId);
  Future<Either<Failure, OrderModel>> cancelOrder(int orderId);
}
