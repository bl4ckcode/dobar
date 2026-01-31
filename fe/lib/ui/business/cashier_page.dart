import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';

/// Order status for filtering
enum OrderFilter { all, pending, preparing, ready, completed }

/// Cashier page for managing orders in real-time.
///
/// This is the main view for cashiers and staff who process orders.
/// Shows:
/// - Live order feed with WebSocket updates
/// - Order status tabs (pending, preparing, ready)
/// - Quick actions to confirm/prepare/complete orders
class CashierPage extends StatefulWidget {
  const CashierPage({super.key});

  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        if (state is! SessionReady) {
          return const Center(child: CircularProgressIndicator());
        }

        final activeBar = state.session.activeBar;
        if (activeBar == null) {
          return const Center(child: Text('No bar selected'));
        }

        return Scaffold(
          backgroundColor: barzGoldSoft,
          body: Column(
            children: [
              _buildOrderTabs(),
              Expanded(child: _buildOrderList()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: barzDark,
        unselectedLabelColor: Colors.grey,
        indicatorColor: barzGold,
        tabs: [
          _buildTab('Pending', 0, Colors.orange),
          _buildTab('Preparing', 0, Colors.blue),
          _buildTab('Ready', 0, Colors.green),
          _buildTab('All', 0, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int count, Color color) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildEmptyOrdersView('pending'),
        _buildEmptyOrdersView('preparing'),
        _buildEmptyOrdersView('ready'),
        _buildEmptyOrdersView('all'),
      ],
    );
  }

  Widget _buildEmptyOrdersView(String filter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No $filter orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Orders will appear here when customers place them',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Refresh orders
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  // TODO(cashier): Use this method when order backend is integrated
  // ignore: unused_element
  Widget _buildOrderCard({
    required int orderId,
    required String status,
    required String customerName,
    required double total,
    required List<String> items,
    required DateTime createdAt,
  }) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'preparing':
        statusColor = Colors.blue;
        break;
      case 'ready':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #$orderId',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(customerName, style: TextStyle(color: Colors.grey[600])),
            const Divider(),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(item),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'R\$ ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Row(
                  children: [
                    if (status.toLowerCase() == 'pending')
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Confirm order
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('Confirm'),
                      ),
                    if (status.toLowerCase() == 'preparing')
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Mark as ready
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                        child: const Text('Ready'),
                      ),
                    if (status.toLowerCase() == 'ready')
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Complete order
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: barzGold,
                          foregroundColor: barzDark,
                        ),
                        child: const Text('Complete'),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
