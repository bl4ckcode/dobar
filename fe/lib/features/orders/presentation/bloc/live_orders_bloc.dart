import 'dart:async';
import 'package:barz/core/services/websocket/websocket_service.dart';
import 'package:barz/features/orders/domain/models/live_order_model.dart';
import 'package:barz/features/orders/domain/usecases/live_orders_usecases.dart';
import 'package:barz/features/orders/presentation/bloc/live_orders_event.dart';
import 'package:barz/features/orders/presentation/bloc/live_orders_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LiveOrdersBloc extends Bloc<LiveOrdersEvent, LiveOrdersState> {
  final GetLiveOrdersUseCase getLiveOrdersUseCase;
  final UpdateLiveOrderStatusUseCase updateLiveOrderStatusUseCase;
  final WebSocketService webSocketService;
  StreamSubscription? _wsSubscription;

  LiveOrdersBloc({
    required this.getLiveOrdersUseCase,
    required this.updateLiveOrderStatusUseCase,
    required this.webSocketService,
  }) : super(const LiveOrdersState.initial()) {
    on<LiveOrdersEvent>((event, emit) async {
      await event.map(
        loadOrders: (e) => _onLoadOrders(e.barId, emit),
        updateOrderStatus: (e) =>
            _onUpdateOrderStatus(e.barId, e.orderId, e.newStatus, emit),
        receiveWebSocketEvent: (e) =>
            _onReceiveWebSocketEvent(e.eventType, e.data, emit),
      );
    });

    _initWebSocket();
  }

  void _initWebSocket() {
    webSocketService.connect();
    _wsSubscription = webSocketService.messages.listen((message) {
      add(LiveOrdersEvent.receiveWebSocketEvent(message.type, message.data));
    });
  }

  Future<void> _onLoadOrders(int barId, Emitter<LiveOrdersState> emit) async {
    emit(const LiveOrdersState.loading());
    final result = await getLiveOrdersUseCase(barId);
    result.fold(
      (failure) => emit(
        LiveOrdersState.error(failure.message ?? 'Failed to load orders'),
      ),
      (orders) => emit(LiveOrdersState.loaded(orders)),
    );
  }

  Future<void> _onUpdateOrderStatus(
    int barId,
    String orderId,
    String newStatus,
    Emitter<LiveOrdersState> emit,
  ) async {
    final currentState = state;
    List<LiveOrderModel>? currentOrders;

    currentState.maybeMap(
      loaded: (s) => currentOrders = s.orders,
      orElse: () {},
    );

    if (currentOrders == null) return;

    // Optimistic Update
    final updatedOrders = currentOrders!.map((order) {
      if (order.id == orderId) {
        return order.copyWith(status: newStatus);
      }
      return order;
    }).toList();

    emit(LiveOrdersState.loaded(updatedOrders));

    final result = await updateLiveOrderStatusUseCase(
      barId: barId,
      orderId: orderId,
      newStatus: newStatus,
    );

    result.fold(
      (failure) {
        // Revert on failure
        emit(
          LiveOrdersState.error(failure.message ?? 'Failed to update status'),
        );
        emit(currentState);
      },
      (updatedOrder) {
        // Replace optimistic order with full backend response
        final serverOrders = currentOrders!.map((order) {
          if (order.id == orderId) {
            return order.copyWith(
              id: updatedOrder.id,
              userId: updatedOrder.userId,
              barId: updatedOrder.barId,
              customerName: updatedOrder.customerName,
              status: updatedOrder.status,
              totalPrice: updatedOrder.totalPrice,
              subtotal: updatedOrder.subtotal,
              tax: updatedOrder.tax,
              tip: updatedOrder.tip,
              deliveryFee: updatedOrder.deliveryFee,
              discount: updatedOrder.discount,
              orderType: updatedOrder.orderType,
              paymentMethod: updatedOrder.paymentMethod,
              paymentStatus: updatedOrder.paymentStatus,
              createdAt: updatedOrder.createdAt,
              updatedAt: updatedOrder.updatedAt,
              estimatedReadyTime: updatedOrder.estimatedReadyTime,
              completedAt: updatedOrder.completedAt,
              items: updatedOrder.items,
            );
          }
          return order;
        }).toList();
        emit(LiveOrdersState.loaded(serverOrders));
      },
    );
  }

  Future<void> _onReceiveWebSocketEvent(
    String eventType,
    Map<String, dynamic> data,
    Emitter<LiveOrdersState> emit,
  ) async {
    final currentState = state;
    currentState.maybeMap(
      loaded: (s) {
        final currentOrders = List<LiveOrderModel>.from(s.orders);

        if (eventType == 'new_order') {
          if (data['order'] != null) {
            final newOrder = LiveOrderModel.fromJson(data['order']);
            if (!currentOrders.any((o) => o.id == newOrder.id)) {
              currentOrders.insert(0, newOrder);
              emit(LiveOrdersState.loaded(currentOrders));
            }
          }
        } else if (eventType == 'status_changed') {
          final orderId = data['order_id'] as String?;
          final newStatus = data['status'] as String?;

          if (orderId != null && newStatus != null) {
            final updatedOrders = currentOrders.map((order) {
              if (order.id == orderId) {
                return order.copyWith(status: newStatus);
              }
              return order;
            }).toList();
            emit(LiveOrdersState.loaded(updatedOrders));
          }
        }
      },
      orElse: () {},
    );
  }

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    webSocketService.disconnect();
    return super.close();
  }
}
