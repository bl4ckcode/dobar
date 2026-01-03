import 'dart:async';
import 'package:barz/core/services/websocket/order_tracking_service.dart';
import 'package:barz/core/services/websocket/websocket_service.dart';
import 'package:barz/core/services/token_storage_service.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/orders/presentation/bloc/order_bloc.dart';
import 'package:barz/features/orders/presentation/bloc/order_event.dart';
import 'package:barz/features/orders/presentation/bloc/order_state.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Real-time order tracking page with WebSocket connection
class OrderTrackingPage extends StatefulWidget {
  final int orderId;

  const OrderTrackingPage({super.key, required this.orderId});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage>
    with SingleTickerProviderStateMixin {
  OrderTrackingService? _trackingService;
  late AnimationController _pulseController;
  StreamSubscription<OrderStatusUpdate>? _statusSubscription;
  StreamSubscription<WebSocketState>? _connectionSubscription;

  OrderStatus _currentStatus = OrderStatus.pending;
  bool _isConnected = false;
  bool _isReconnecting = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _initTracking();
  }

  Future<void> _initTracking() async {
    final tokenService = getItInjector<TokenStorageService>();
    final token = await tokenService.getAccessToken();

    if (token == null) {
      // Not authenticated
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to track orders')),
        );
      }
      return;
    }

    _trackingService = OrderTrackingService(
      orderId: widget.orderId,
      token: token,
    );

    _statusSubscription = _trackingService!.statusUpdates.listen((update) {
      if (mounted) {
        setState(() {
          _currentStatus = update.status;
        });
        _showStatusNotification(update);
      }
    });

    _connectionSubscription = _trackingService!.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          _isConnected = state == WebSocketState.connected;
          _isReconnecting = state == WebSocketState.reconnecting;
        });
      }
    });

    await _trackingService!.startTracking();
  }

  void _showStatusNotification(OrderStatusUpdate update) {
    final l10n = AppLocalizations.of(context)!;
    String message;
    
    switch (update.status) {
      case OrderStatus.confirmed:
        message = l10n.notification_order_confirmed;
        break;
      case OrderStatus.preparing:
        message = l10n.notification_order_preparing;
        break;
      case OrderStatus.ready:
        message = l10n.notification_order_ready;
        break;
      default:
        message = update.message ?? update.status.displayName;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(update.status.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusSubscription?.cancel();
    _connectionSubscription?.cancel();
    _trackingService?.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return BlocProvider(
      create: (_) => getItInjector<OrderBloc>()
        ..add(LoadOrderTimeline(orderId: widget.orderId)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.order_number(widget.orderId)),
          actions: [
            _buildConnectionIndicator(),
          ],
        ),
        body: Column(
          children: [
            // Status Progress
            _buildStatusProgress(theme),

            // Order Details
            Expanded(
              child: BlocBuilder<OrderBloc, OrderState>(
                builder: (context, state) {
                  if (state is OrderLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is OrderError) {
                    return _buildErrorView(state.message, l10n);
                  }
                  if (state is OrderTimelineLoaded) {
                    return _buildOrderDetails(state, l10n, theme);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    if (_isReconnecting) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Icon(
        _isConnected ? Icons.wifi : Icons.wifi_off,
        color: _isConnected ? Colors.green : Colors.red,
        size: 20,
      ),
    );
  }

  Widget _buildStatusProgress(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          // Animated Status Icon
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final isActive = _currentStatus != OrderStatus.completed &&
                  _currentStatus != OrderStatus.cancelled;
              return Transform.scale(
                scale: isActive ? 1.0 + (_pulseController.value * 0.1) : 1.0,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _getStatusColor(_currentStatus).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _getStatusColor(_currentStatus),
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _currentStatus.emoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Status Text
          Text(
            _getLocalizedStatus(_currentStatus),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Progress Bar
          _buildProgressBar(theme),
        ],
      ),
    );
  }

  Widget _buildProgressBar(ThemeData theme) {
    final steps = [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.completed,
    ];

    final currentIndex = steps.indexOf(_currentStatus);

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepIndex = index ~/ 2;
          final isActive = stepIndex < currentIndex;
          return Expanded(
            child: Container(
              height: 4,
              color: isActive ? theme.colorScheme.primary : Colors.grey[300],
            ),
          );
        } else {
          // Step dot
          final stepIndex = index ~/ 2;
          final isActive = stepIndex <= currentIndex;
          final isCurrent = stepIndex == currentIndex;

          return Container(
            width: isCurrent ? 24 : 16,
            height: isCurrent ? 24 : 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? theme.colorScheme.primary : Colors.grey[300],
              border: isCurrent
                  ? Border.all(color: theme.colorScheme.primary, width: 3)
                  : null,
            ),
            child: isActive && !isCurrent
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          );
        }
      }),
    );
  }

  Widget _buildOrderDetails(
    OrderTimelineLoaded state,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final order = state.order;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Items Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.order_items_count(order.items.length),
                    style: theme.textTheme.titleMedium,
                  ),
                  const Divider(),
                  ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Text('${item.quantity}x'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(item.menuItemName)),
                            Text(
                              '\$${item.totalPrice.toStringAsFixed(2)}',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Total Card
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.order_total,
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(
                    '\$${order.totalPrice.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Cancel Button (only for pending orders)
          if (_currentStatus == OrderStatus.pending)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showCancelDialog(context, l10n),
                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                label: Text(
                  l10n.order_cancel,
                  style: const TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(message),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context
                  .read<OrderBloc>()
                  .add(LoadOrderTimeline(orderId: widget.orderId));
            },
            child: Text(l10n.error_retry),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.order_cancel),
        content: Text(l10n.order_cancel_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<OrderBloc>().add(CancelOrder(orderId: widget.orderId));
              context.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  String _getLocalizedStatus(OrderStatus status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case OrderStatus.pending:
        return l10n.order_status_pending;
      case OrderStatus.confirmed:
        return l10n.order_status_confirmed;
      case OrderStatus.preparing:
        return l10n.order_status_preparing;
      case OrderStatus.ready:
        return l10n.order_status_ready;
      case OrderStatus.completed:
        return l10n.order_status_completed;
      case OrderStatus.cancelled:
        return l10n.order_status_cancelled;
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.completed:
        return Colors.teal;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }
}
