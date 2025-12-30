import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/orders/data/data_sources/order_network_datasource.dart';
import 'package:barz/features/orders/domain/models/order_model.dart';
import 'package:barz/features/orders/domain/repositories/abstract_order_repository.dart';
import 'package:dartz/dartz.dart';

class OrderRepositoryImpl extends AbstractOrderRepository {
  final OrderNetworkDataSource networkDataSource;

  OrderRepositoryImpl({required this.networkDataSource});

  @override
  Future<Either<Failure, PaginatedOrders>> getMyOrders({
    required int page,
    required int pageSize,
    String? status,
  }) async {
    try {
      final result = await networkDataSource.getMyOrders(
        page: page,
        pageSize: pageSize,
        status: status,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, OrderModel>> getOrder(int orderId) async {
    try {
      final result = await networkDataSource.getOrder(orderId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, OrderModel>> getOrderTimeline(int orderId) async {
    try {
      final result = await networkDataSource.getOrderTimeline(orderId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, OrderModel>> cancelOrder(int orderId) async {
    try {
      final result = await networkDataSource.cancelOrder(orderId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }
}
