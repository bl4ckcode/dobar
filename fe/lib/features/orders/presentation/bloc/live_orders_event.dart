import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_orders_event.freezed.dart';

@freezed
abstract class LiveOrdersEvent with _$LiveOrdersEvent {
  const factory LiveOrdersEvent.loadOrders(int barId) = _LoadOrders;
  const factory LiveOrdersEvent.updateOrderStatus(
    int barId,
    String orderId,
    String newStatus,
  ) = _UpdateOrderStatus;
  const factory LiveOrdersEvent.receiveWebSocketEvent(
    String eventType,
    Map<String, dynamic> data,
  ) = _ReceiveWebSocketEvent;
}
