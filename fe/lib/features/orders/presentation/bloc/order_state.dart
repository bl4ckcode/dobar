import 'package:barz/features/orders/domain/models/order_model.dart';
import 'package:equatable/equatable.dart';

abstract class OrderState extends Equatable {
  const OrderState();

  @override
  List<Object?> get props => [];
}

class OrderInitial extends OrderState {}

class OrderLoading extends OrderState {}

class OrdersLoaded extends OrderState {
  final PaginatedOrders paginatedOrders;
  final bool hasReachedMax;
  final bool isFetchingMore;

  const OrdersLoaded({
    required this.paginatedOrders,
    this.hasReachedMax = false,
    this.isFetchingMore = false,
  });

  OrdersLoaded copyWith({
    PaginatedOrders? paginatedOrders,
    bool? hasReachedMax,
    bool? isFetchingMore,
  }) {
    return OrdersLoaded(
      paginatedOrders: paginatedOrders ?? this.paginatedOrders,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
    );
  }

  @override
  List<Object?> get props => [paginatedOrders, hasReachedMax, isFetchingMore];
}

class OrderLoaded extends OrderState {
  final OrderModel order;

  const OrderLoaded({required this.order});

  @override
  List<Object?> get props => [order];
}

class OrderTimelineLoaded extends OrderState {
  final OrderModel order;

  const OrderTimelineLoaded({required this.order});

  @override
  List<Object?> get props => [order];
}

class OrderCancelled extends OrderState {
  final OrderModel order;

  const OrderCancelled({required this.order});

  @override
  List<Object?> get props => [order];
}

class OrderError extends OrderState {
  final String message;

  const OrderError({required this.message});

  @override
  List<Object?> get props => [message];
}
