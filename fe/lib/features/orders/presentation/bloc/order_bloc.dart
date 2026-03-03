import 'package:barz/features/orders/domain/usecases/order_usecase.dart';
import 'package:barz/features/orders/presentation/bloc/order_event.dart';
import 'package:barz/features/orders/presentation/bloc/order_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final OrderUsecase orderUsecase;

  OrderBloc({required this.orderUsecase}) : super(OrderInitial()) {
    on<LoadMyOrders>(_onLoadMyOrders);
    on<LoadOrder>(_onLoadOrder);
    on<LoadOrderTimeline>(_onLoadOrderTimeline);
    on<CancelOrder>(_onCancelOrder);
  }

  Future<void> _onLoadMyOrders(
    LoadMyOrders event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderLoading());
    final result = await orderUsecase.getMyOrders(
      page: event.page,
      pageSize: event.pageSize,
      status: event.status,
    );
    result.fold(
      (failure) => emit(OrderError(message: failure.errorMessage)),
      (paginatedOrders) => emit(OrdersLoaded(paginatedOrders: paginatedOrders)),
    );
  }

  Future<void> _onLoadOrder(LoadOrder event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    final result = await orderUsecase.getOrder(event.orderId);
    result.fold(
      (failure) => emit(OrderError(message: failure.errorMessage)),
      (order) => emit(OrderLoaded(order: order)),
    );
  }

  Future<void> _onLoadOrderTimeline(
    LoadOrderTimeline event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderLoading());
    final result = await orderUsecase.getOrderTimeline(event.orderId);
    result.fold(
      (failure) => emit(OrderError(message: failure.errorMessage)),
      (order) => emit(OrderTimelineLoaded(order: order)),
    );
  }

  Future<void> _onCancelOrder(
    CancelOrder event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderLoading());
    final result = await orderUsecase.cancelOrder(event.orderId);
    result.fold(
      (failure) => emit(OrderError(message: failure.errorMessage)),
      (order) => emit(OrderCancelled(order: order)),
    );
  }
}
