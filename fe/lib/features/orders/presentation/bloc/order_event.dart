import 'package:equatable/equatable.dart';

abstract class OrderEvent extends Equatable {
  const OrderEvent();

  @override
  List<Object?> get props => [];
}

class LoadMyOrders extends OrderEvent {
  final int page;
  final int pageSize;
  final String? status;

  const LoadMyOrders({
    this.page = 1,
    this.pageSize = 10,
    this.status,
  });

  @override
  List<Object?> get props => [page, pageSize, status];
}

class LoadOrder extends OrderEvent {
  final int orderId;

  const LoadOrder({required this.orderId});

  @override
  List<Object?> get props => [orderId];
}

class LoadOrderTimeline extends OrderEvent {
  final int orderId;

  const LoadOrderTimeline({required this.orderId});

  @override
  List<Object?> get props => [orderId];
}

class CancelOrder extends OrderEvent {
  final int orderId;

  const CancelOrder({required this.orderId});

  @override
  List<Object?> get props => [orderId];
}
