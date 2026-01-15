import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:barz/features/bars/presentation/bloc/dashboard_bloc.dart';
import 'package:barz/features/bars/domain/models/dashboard_models.dart';

class BusinessDashboardPage extends StatelessWidget {
  const BusinessDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        if (state is! SessionReady) {
          return const Center(child: CircularProgressIndicator());
        }

        final session = state.session;
        final activeBar = session.activeBar;
        if (activeBar == null) {
          return const Center(child: Text('No bar selected'));
        }

        return BlocProvider(
          create: (context) => getItInjector<DashboardBloc>()
            ..add(LoadDashboard(barId: activeBar.barId)),
          child: _DashboardContent(
            activeBar: activeBar,
            allBars: session.barAccess,
          ),
        );
      },
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final BarAccess activeBar;
  final List<BarAccess> allBars;

  const _DashboardContent({required this.activeBar, required this.allBars});

  @override
  Widget build(BuildContext context) {
    final isOwnerOrAdmin = activeBar.role == BarRole.owner || activeBar.role == BarRole.admin;

    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, dashboardState) {
        return Scaffold(
          backgroundColor: barzGoldSoft,
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<DashboardBloc>().add(RefreshDashboard(barId: activeBar.barId));
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _WelcomeHeader(
                          barName: activeBar.barName,
                          role: activeBar.role,
                          isOpen: dashboardState is DashboardLoaded ? dashboardState.status.isOpen : true,
                          onToggleOpen: () {
                            if (dashboardState is DashboardLoaded) {
                              context.read<DashboardBloc>().add(ToggleBarOpen(
                                barId: activeBar.barId,
                                isOpen: !dashboardState.status.isOpen,
                              ));
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        _QuickStatsGrid(
                          isOwnerOrAdmin: isOwnerOrAdmin,
                          stats: dashboardState is DashboardLoaded ? dashboardState.stats : null,
                          isLoading: dashboardState is DashboardLoading,
                        ),
                        const SizedBox(height: 24),
                        if (isOwnerOrAdmin) ...[
                          _PromoteCampaignCard(),
                          const SizedBox(height: 24),
                        ],
                        _RecentOrdersSection(
                          orders: dashboardState is DashboardLoaded ? dashboardState.recentOrders : null,
                          isLoading: dashboardState is DashboardLoading,
                        ),
                        const SizedBox(height: 24),
                        if (isOwnerOrAdmin) ...[
                          _BarsOverviewSection(bars: allBars),
                          const SizedBox(height: 24),
                        ],
                        _QuickActionsSection(activeBar: activeBar),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  final String barName;
  final BarRole role;
  final bool isOpen;
  final VoidCallback onToggleOpen;

  const _WelcomeHeader({
    required this.barName,
    required this.role,
    required this.isOpen,
    required this.onToggleOpen,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [barzDark, barzDark.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: barzDark.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    barName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onToggleOpen,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOpen ? successGreen : errorRed,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOpen ? 'Open' : 'Closed',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: barzGold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              role.displayName,
              style: TextStyle(color: barzGold, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatsGrid extends StatelessWidget {
  final bool isOwnerOrAdmin;
  final DashboardStats? stats;
  final bool isLoading;

  const _QuickStatsGrid({
    required this.isOwnerOrAdmin,
    this.stats,
    this.isLoading = false,
  });

  String _formatTrend(double percent) {
    if (percent >= 0) return '+${percent.toStringAsFixed(0)}%';
    return '${percent.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    final orderStats = stats?.orders;
    final revenueStats = stats?.revenue;
    final avgTicket = stats?.averageTicket;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _StatCard(
          title: "Today's Orders",
          value: isLoading ? '-' : '${orderStats?.total ?? 0}',
          icon: Icons.receipt_long_rounded,
          color: infoBlue,
          trend: orderStats != null ? _formatTrend(orderStats.trendPercent) : null,
          isLoading: isLoading,
        ),
        _StatCard(
          title: 'Pending',
          value: isLoading ? '-' : '${orderStats?.pending ?? 0}',
          icon: Icons.pending_actions_rounded,
          color: warningOrange,
          showBadge: (orderStats?.pending ?? 0) > 0,
          isLoading: isLoading,
        ),
        if (isOwnerOrAdmin) ...[
          _StatCard(
            title: 'Revenue',
            value: isLoading ? '-' : (revenueStats?.formattedTotal ?? 'R\$ 0'),
            icon: Icons.trending_up_rounded,
            color: successGreen,
            trend: revenueStats != null ? _formatTrend(revenueStats.trendPercent) : null,
            isLoading: isLoading,
          ),
          _StatCard(
            title: 'Avg. Ticket',
            value: isLoading ? '-' : (avgTicket?.formattedValue ?? 'R\$ 0'),
            icon: Icons.analytics_rounded,
            color: barzGold,
            isLoading: isLoading,
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;
  final bool showBadge;
  final bool isLoading;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.showBadge = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    trend!,
                    style: TextStyle(color: successGreen, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              if (showBadge)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: warningOrange,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromoteCampaignCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [barzGold, barzGold.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: barzGold.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.campaign_rounded, color: barzDark, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Boost Your Sales',
                      style: TextStyle(
                        color: barzDark,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a campaign and reach more customers in your area!',
                  style: TextStyle(color: barzDark.withValues(alpha: 0.7), fontSize: 14),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: barzDark,
                    foregroundColor: barzGold,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create Campaign'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: barzDark.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.trending_up_rounded, color: barzDark, size: 40),
          ),
        ],
      ),
    );
  }
}

class _RecentOrdersSection extends StatelessWidget {
  final RecentOrdersResponse? orders;
  final bool isLoading;

  const _RecentOrdersSection({this.orders, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final hasOrders = orders != null && orders!.orders.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Orders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            TextButton(
              onPressed: () {},
              child: Text('View All', style: TextStyle(color: barzGold, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isLoading)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: surfaceWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: surfaceDim),
            ),
            child: const Center(child: CircularProgressIndicator()),
          )
        else if (!hasOrders)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: surfaceWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: surfaceDim),
            ),
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: barzGoldSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.receipt_long_rounded, size: 32, color: barzGold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No orders yet',
                    style: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Orders will appear here when customers place them',
                    style: TextStyle(color: textTertiary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: orders!.orders.map((order) => _OrderCard(order: order)).toList(),
          ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final RecentOrder order;

  const _OrderCard({required this.order});

  Color _getStatusColor() {
    switch (order.status) {
      case 'pending':
        return warningOrange;
      case 'preparing':
        return infoBlue;
      case 'ready':
        return successGreen;
      case 'completed':
        return textSecondary;
      case 'cancelled':
        return errorRed;
      default:
        return textSecondary;
    }
  }

  String _getStatusLabel() {
    switch (order.status) {
      case 'pending':
        return 'Pending';
      case 'preparing':
        return 'Preparing';
      case 'ready':
        return 'Ready';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return order.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaceDim),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getStatusColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                order.orderNumber,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.customerName ?? 'Customer',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      order.formattedTotal,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getStatusLabel(),
                        style: TextStyle(
                          color: _getStatusColor(),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${order.itemsCount} items',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    if (order.tableNumber != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Table ${order.tableNumber}',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarsOverviewSection extends StatelessWidget {
  final List<BarAccess> bars;

  const _BarsOverviewSection({required this.bars});

  Future<void> _navigateToCreateBar(BuildContext context) async {
    final result = await context.push<bool>('/create-bar');
    if (result == true && context.mounted) {
      context.read<SessionBloc>().add(const SessionEvent.refreshBarAccess());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Bars',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            TextButton.icon(
              onPressed: () => _navigateToCreateBar(context),
              icon: Icon(Icons.add, size: 18, color: barzGold),
              label: Text('Add Bar', style: TextStyle(color: barzGold, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: bars.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == bars.length) {
                return _AddBarCard(onTap: () => _navigateToCreateBar(context));
              }
              final bar = bars[index];
              return _BarMiniCard(bar: bar);
            },
          ),
        ),
      ],
    );
  }
}

class _AddBarCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddBarCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: barzGold, style: BorderStyle.solid, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: barzGoldSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.add_business_rounded, color: barzGold, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                'Add Bar',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: barzGold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarMiniCard extends StatelessWidget {
  final BarAccess bar;

  const _BarMiniCard({required this.bar});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaceDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: barzGoldSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.local_bar_rounded, color: barzGold, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bar.barName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: barzGoldSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              bar.role.displayName,
              style: TextStyle(color: barzGold, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  final BarAccess activeBar;

  const _QuickActionsSection({required this.activeBar});

  void _navigateToTab(BuildContext context, int tabIndex) {
    final shellState = context.findAncestorStateOfType<State>();
    if (shellState != null && shellState.mounted) {
      (shellState as dynamic).navigateToTab(tabIndex);
    }
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwnerOrAdmin = activeBar.role == BarRole.owner || activeBar.role == BarRole.admin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickActionChip(
              icon: Icons.point_of_sale_rounded,
              label: 'Cashier',
              onTap: () => _navigateToTab(context, 1),
            ),
            if (activeBar.canEditMenu)
              _QuickActionChip(
                icon: Icons.restaurant_menu_rounded,
                label: 'Edit Menu',
                onTap: () => _navigateToTab(context, 2),
              ),
            if (isOwnerOrAdmin) ...[
              _QuickActionChip(
                icon: Icons.local_offer_rounded,
                label: 'New Promo',
                onTap: () => _navigateToTab(context, activeBar.canEditMenu ? 3 : 2),
              ),
              _QuickActionChip(
                icon: Icons.qr_code_rounded,
                label: 'Table QR',
                onTap: () => _showComingSoon(context, 'Table QR Generator'),
              ),
            ],
            if (activeBar.canManageStaff)
              _QuickActionChip(
                icon: Icons.person_add_rounded,
                label: 'Invite Staff',
                onTap: () => _showComingSoon(context, 'Staff Invitations'),
                highlighted: true,
              ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? barzGold : surfaceWhite,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: highlighted ? null : Border.all(color: surfaceDim),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: highlighted ? barzDark : textPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: highlighted ? barzDark : textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
