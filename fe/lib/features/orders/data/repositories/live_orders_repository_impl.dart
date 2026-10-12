import 'package:barz/core/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/core/services/offline/connectivity_service.dart';
import 'package:barz/features/orders/data/data_sources/live_orders_remote_data_source.dart';
import 'package:barz/features/orders/domain/models/live_order_model.dart';
import 'package:dartz/dartz.dart';

abstract class LiveOrdersRepository {
  Future<Either<Failure, List<LiveOrderModel>>> getLiveOrders(int barId);
  Future<Either<Failure, LiveOrderModel>> updateOrderStatus(
    int barId,
    String orderId,
    String newStatus,
  );
}

class LiveOrdersRepositoryImpl implements LiveOrdersRepository {
  final LiveOrdersRemoteDataSource remoteDataSource;
  final ConnectivityService connectivityService;

  LiveOrdersRepositoryImpl({
    required this.remoteDataSource,
    required this.connectivityService,
  });

  @override
  Future<Either<Failure, List<LiveOrderModel>>> getLiveOrders(int barId) async {
    if (connectivityService.isOnline) {
      try {
        final orders = await remoteDataSource.getLiveOrders(barId);
        return Right(orders);
      } on ServerException catch (e) {
        return Left(ServerFailure.unknown(e.message));
      } catch (e) {
        return Left(ServerFailure.unknown('Unexpected error: $e'));
      }
    } else {
      return Left(NetworkFailure.noInternet());
    }
  }

  @override
  Future<Either<Failure, LiveOrderModel>> updateOrderStatus(
    int barId,
    String orderId,
    String newStatus,
  ) async {
    if (connectivityService.isOnline) {
      try {
        final order = await remoteDataSource.updateOrderStatus(
          barId,
          orderId,
          newStatus,
        );
        return Right(order);
      } on ServerException catch (e) {
        return Left(ServerFailure.unknown(e.message));
      } catch (e) {
        return Left(ServerFailure.unknown('Unexpected error: $e'));
      }
    } else {
      return Left(NetworkFailure.noInternet());
    }
  }
}
