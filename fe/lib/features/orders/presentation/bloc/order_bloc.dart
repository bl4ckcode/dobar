import 'package:barz/features/orders/domain/models/order_model.dart';
import 'package:barz/features/orders/domain/usecases/order_usecase.dart';
import 'package:barz/features/orders/presentation/bloc/order_event.dart';
import 'package:barz/features/orders/presentation/bloc/order_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final OrderUsecase orderUsecase;

  OrderBloc({required this.orderUsecase}) : super(OrderInitial()) {
    on<LoadMyOrders>(_onLoadMyOrders);
    on<LoadMoreOrders>(_onLoadMoreOrders);
    on<LoadOrder>(_onLoadOrder);
    on<LoadOrderTimeline>(_onLoadOrderTimeline);
    on<CancelOrder>(_onCancelOrder);
  }

  Future<void> _onLoadMyOrders(
    LoadMyOrders event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderLoading());
    final result = await orderUsecase.getMyOrders(status: event.status);
    result.fold(
      (failure) => emit(OrderError(message: failure.errorMessage)),
      (paginatedOrders) => emit(
        OrdersLoaded(
          paginatedOrders: paginatedOrders,
          hasReachedMax: !paginatedOrders.hasMore,
        ),
      ),
    );
  }

  Future<void> _onLoadMoreOrders(
    LoadMoreOrders event,
    Emitter<OrderState> emit,
  ) async {
    if (state is! OrdersLoaded) return;
    final currentState = state as OrdersLoaded;
    if (currentState.hasReachedMax || currentState.isFetchingMore) return;

    emit(currentState.copyWith(isFetchingMore: true));

    final result = await orderUsecase.getMyOrders(
      cursor: currentState.paginatedOrders.nextCursor,
      status: event.status,
    );

    result.fold(
      (failure) => emit(currentState.copyWith(isFetchingMore: false)),
      (paginatedOrders) {
        final allOrders = List<OrderModel>.from(
          currentState.paginatedOrders.orders,
        )..addAll(paginatedOrders.orders);

        emit(
          OrdersLoaded(
            paginatedOrders: PaginatedOrders(
              orders: allOrders,
              hasMore: paginatedOrders.hasMore,
              nextCursor: paginatedOrders.nextCursor,
            ),
            hasReachedMax: !paginatedOrders.hasMore,
            isFetchingMore: false,
          ),
        );
      },
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
    final isAlreadyLoaded = state is OrderTimelineLoaded;
    if (!isAlreadyLoaded) {
      emit(OrderLoading());
    }
    
    final result = await orderUsecase.getOrderTimeline(event.orderId);
    result.fold(
      (failure) {
        if (!isAlreadyLoaded) {
          emit(OrderError(message: failure.errorMessage));
        }
      },
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
