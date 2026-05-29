import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/ui/business/widgets/business_toolbars.dart';
import 'package:get_it/get_it.dart';
import 'package:barz/features/orders/domain/models/live_order_model.dart';
import 'package:barz/features/orders/presentation/bloc/live_orders_bloc.dart';
import 'package:barz/features/orders/presentation/bloc/live_orders_event.dart';
import 'package:barz/features/orders/presentation/bloc/live_orders_state.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/l10n/app_localizations.dart';

// --- CONSTANTS ---
const String statusPending = 'pending';
const String statusPreparing = 'preparing';
const String statusReady = 'ready';
const String statusCompleted = 'completed';

class CashierPage extends StatefulWidget {
  const CashierPage({super.key});

  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage>
    with SingleTickerProviderStateMixin {
  String? _activeFilter = statusPending;
  bool _soundOn = true;
  Timer? _uiRefreshTimer;
  LiveOrdersBloc? _liveOrdersBloc;
  int? _activeBarId;
  int _totalOrders = 0;

  final Set<String> _urgentAlertedIds = {};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) setState(() {});
    });

    _initLiveOrdersBloc();
  }

  Future<void> _initLiveOrdersBloc() async {
    final bloc = await GetIt.I.getAsync<LiveOrdersBloc>();
    if (!mounted) {
      bloc.close();
      return;
    }
    setState(() => _liveOrdersBloc = bloc);
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _playSound(SystemSoundType type) {
    if (_soundOn) {
      SystemSound.play(type);
      HapticFeedback.lightImpact();
    }
  }

  void _checkUrgentAlerts(List<LiveOrderModel> orders) {
    final now = DateTime.now();
    for (final order in orders) {
      if (order.status != statusCompleted) {
        final mins = now.difference(order.createdAt).inMinutes;
        if (mins >= 15 && !_urgentAlertedIds.contains(order.id)) {
          _urgentAlertedIds.add(order.id);
          _playSound(SystemSoundType.alert); // Urgent sound
        }
      }
    }
  }

  void _handleAction(int barId, String orderId, String newStatus) {
    _liveOrdersBloc?.add(
      LiveOrdersEvent.updateOrderStatus(barId, orderId, newStatus),
    );
    _playSound(SystemSoundType.click);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dobar = context.dobarColors;
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = dobar.background;
    final cardColor = dobar.surface;
    final textColor = dobar.labelPrimary;
    final mutedColor = dobar.labelSecondary;
    final borderColor = cs.outline;

    return _liveOrdersBloc == null
        ? Material(
            color: bgColor,
            child: const Center(child: CircularProgressIndicator()),
          )
        : BlocProvider<LiveOrdersBloc>.value(
            value: _liveOrdersBloc!,
            child: Material(
              color: bgColor,
              child: Column(
                children: [
                  BusinessStatusToolbar(
                    title: l10n.business_cashier_title,
                    subtitle: l10n.business_cashier_subtitle(_totalOrders),
                    showStatusToggle: false,
                    actions: [
                      IconButton(
                        icon: Icon(
                          _soundOn ? LucideIcons.volume2 : LucideIcons.volumeX,
                          size: 20,
                          color: _soundOn ? barzGold : mutedColor,
                        ),
                        onPressed: () => setState(() => _soundOn = !_soundOn),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) => Opacity(
                              opacity: _pulseAnimation.value,
                              child: child,
                            ),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.business_status_live,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: mutedColor,
                              fontFamily: 'JetBrains Mono',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(LucideIcons.refreshCw, size: 18),
                        onPressed: () {
                          if (_activeBarId != null) {
                            _liveOrdersBloc?.add(
                              LiveOrdersEvent.loadOrders(_activeBarId!),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: BlocBuilder<SessionBloc, SessionState>(
                      builder: (context, sessionState) {
                        final activeBar = sessionState.maybeMap(
                          ready: (s) => s.session.activeBar,
                          orElse: () => null,
                        );
                        if (activeBar == null) {
                          return Center(
                            child: Text(
                              l10n.business_select_bar_cashier,
                              style: TextStyle(color: mutedColor),
                            ),
                          );
                        }

                        if (_activeBarId != activeBar.barId) {
                          _activeBarId = activeBar.barId;
                          _liveOrdersBloc!.add(
                            LiveOrdersEvent.loadOrders(_activeBarId!),
                          );
                        }

                        return BlocConsumer<LiveOrdersBloc, LiveOrdersState>(
                          listener: (context, state) {
                            state.maybeMap(
                              loaded: (s) => _checkUrgentAlerts(s.orders),
                              error: (s) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(s.message),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              },
                              orElse: () {},
                            );
                          },
                          builder: (context, state) {
                            List<LiveOrderModel> currentOrders = [];

                            state.maybeMap(
                              loaded: (s) {
                                currentOrders = s.orders;
                              },
                              orElse: () {},
                            );

                            if (_totalOrders != currentOrders.length) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(
                                    () => _totalOrders = currentOrders.length,
                                  );
                                }
                              });
                            }

                            final filteredOrders = _activeFilter == null
                                ? currentOrders
                                : currentOrders
                                      .where(
                                        (o) =>
                                            (_activeFilter == statusPending &&
                                                    o.status == 'confirmed') ||
                                            o.status == _activeFilter,
                                      )
                                      .toList();

                            return Column(
                              children: [
                                _buildTabs(
                                  isDark,
                                  cardColor,
                                  borderColor,
                                  currentOrders,
                                ),
                                Expanded(
                                  child: ResponsiveCenterContainer(
                                    maxWidthPercentage: 0.9,
                                    maxWidth: 1400,
                                    padding: EdgeInsets.zero,
                                    child: state.maybeMap(
                                      loading: (_) => Center(
                                        child: CircularProgressIndicator(
                                          color: barzGold,
                                        ),
                                      ),
                                      orElse: () {
                                        if (filteredOrders.isEmpty) {
                                          return _buildEmptyState(mutedColor);
                                        }
                                        return _buildOrderGrid(
                                          filteredOrders,
                                          isDark,
                                          cardColor,
                                          borderColor,
                                          textColor,
                                          mutedColor,
                                          activeBar.barId,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
  }

  Widget _buildTabs(
    bool isDark,
    Color cardColor,
    Color borderColor,
    List<LiveOrderModel> allOrders,
  ) {
    final counts = <String, int>{
      statusPending: 0,
      statusPreparing: 0,
      statusReady: 0,
      statusCompleted: 0,
    };
    int total = allOrders.length;
    for (var o in allOrders) {
      // Map backend "confirmed" to our "pending" filter
      final normalizedStatus =
          o.status == 'confirmed' ? statusPending : o.status;
      counts[normalizedStatus] = (counts[normalizedStatus] ?? 0) + 1;
    }

    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1F1F22)
                    : const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _buildTabItem(l10n.business_status_pending, statusPending, counts[statusPending]!),
                  _buildTabItem(l10n.business_status_preparing, statusPreparing, counts[statusPreparing]!),
                  _buildTabItem(l10n.business_status_ready, statusReady, counts[statusReady]!),
                  _buildTabItem(l10n.business_status_completed, statusCompleted, counts[statusCompleted]!),
                  _buildTabItem(l10n.business_status_all, null, total),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(String label, String? statusFilter, int count) {
    final isSelected = _activeFilter == statusFilter;
    final dobar = context.dobarColors;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _activeFilter = statusFilter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? dobar.buttonPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? dobar.buttonOnPrimary
                    : dobar.labelSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.black.withValues(alpha: 0.15)
                      : (isDark ? Colors.grey[800] : Colors.grey[300]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? dobar.buttonOnPrimary
                        : dobar.labelPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color mutedColor) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Text(
        l10n.business_no_orders_pipeline,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: mutedColor,
        ),
      ),
    );
  }

  Widget _buildOrderGrid(
    List<LiveOrderModel> orders,
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color mutedColor,
    int barId,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 1000) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 700) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 500) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _OrderCard(
              order: order,
              isDark: isDark,
              pulseAnimation: _pulseAnimation,
              onAction: (orderId, status) =>
                  _handleAction(barId, orderId, status),
            );
          },
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final LiveOrderModel order;
  final bool isDark;
  final Animation<double> pulseAnimation;
  final Function(String, String) onAction;

  const _OrderCard({
    required this.order,
    required this.isDark,
    required this.pulseAnimation,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dobar = context.dobarColors;
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final minsWait = now.difference(order.createdAt).inMinutes;
    final isUrgent = order.status != statusCompleted && minsWait >= 15;

    final cardColor = dobar.surface;
    Color borderColor = cs.outline;
    if (isUrgent) {
      borderColor = Colors.red.withValues(alpha: 0.6);
    }

    // Normalize backend status to our filter constants
    final displayStatus = order.status == 'confirmed' ? statusPending : order.status;

    // Status config
    Color statusColor;
    switch (displayStatus) {
      case statusPending:
        statusColor = Colors.amber;
        break;
      case statusPreparing:
        statusColor = const Color(0xFF3B82F6); // info -> Blue
        break;
      case statusReady:
        statusColor = const Color(0xFF16A34A); // success -> Green
        break;
      case statusCompleted:
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.grey;
        break;
    }

    final isConfirmed = order.status == 'confirmed';
    String? actionLabel;
    String? nextStatus;
    Color? actionColor;
    Color? actionTextColor;

    final l10n = AppLocalizations.of(context)!;
    switch (displayStatus) {
      case statusPending:
        actionLabel = isConfirmed ? l10n.business_status_preparing : l10n.business_confirm;
        nextStatus = statusPreparing;
        actionColor = const Color(0xFF16A34A); // Success
        actionTextColor = Colors.white;
        break;
      case statusPreparing:
        actionLabel = l10n.business_status_ready;
        nextStatus = statusReady;
        actionColor = const Color(0xFF3B82F6); // Info
        actionTextColor = Colors.white;
        break;
      case statusReady:
        actionLabel = l10n.business_complete;
        nextStatus = statusCompleted;
        actionColor = barzDark;
        actionTextColor = Colors.white;
        if (isDark) {
          actionColor = barzGold;
          actionTextColor = Colors.black;
        }
        break;
      case statusCompleted:
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor, width: isUrgent ? 1.5 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF27272A) : Colors.grey[200]!,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order.id,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'JetBrains Mono',
                        color: dobar.labelPrimary,
                      ),
                    ),
                  ],
                ),
                isUrgent
                    ? AnimatedBuilder(
                        animation: pulseAnimation,
                        builder: (context, child) => Opacity(
                          opacity: pulseAnimation.value,
                          child: child,
                        ),
                        child: _buildTimeText(context, minsWait, isUrgent),
                      )
                    : _buildTimeText(context, minsWait, isUrgent),
              ],
            ),
          ),

          // Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: dobar.labelSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        order.customerName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: dobar.labelPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: order.items
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${item.quantity}× ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: dobar.labelPrimary,
                                      ),
                                    ),
                                    TextSpan(
                                      text: item.name,
                                      style: TextStyle(
                                        color: dobar.labelSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141416) : surfaceMuted,
              border: Border(top: BorderSide(color: cs.outline)),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'R\$ ${order.totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? barzGold : barzDark,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
                if (actionLabel != null && nextStatus != null)
                  InkWell(
                    onTap: () => onAction(order.id, nextStatus!),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: actionColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        actionLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: actionTextColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeText(BuildContext context, int minsWait, bool isUrgent) {
    final l10n = AppLocalizations.of(context)!;
    String timeStr = minsWait == 0 ? l10n.business_time_just_now : l10n.business_time_ago(minsWait);
    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: 14,
          color: isUrgent ? Colors.red : Colors.grey,
        ),
        const SizedBox(width: 4),
        Text(
          timeStr,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'JetBrains Mono',
            fontWeight: isUrgent ? FontWeight.bold : FontWeight.w500,
            color: isUrgent ? Colors.red : Colors.grey,
          ),
        ),
      ],
    );
  }
}
