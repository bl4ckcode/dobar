import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:barz/features/bars/presentation/bloc/dashboard_bloc.dart';
import 'package:barz/features/bars/domain/models/dashboard_models.dart';
import 'package:barz/shared/presentation/widget/theme_toggle_button.dart';

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
          create: (context) =>
              getItInjector<DashboardBloc>()
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
    final isOwnerOrAdmin =
        activeBar.role == BarRole.owner || activeBar.role == BarRole.admin;
    final dobar = context.dobarColors;

    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, dashboardState) {
        return Scaffold(
          backgroundColor: dobar.background,
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<DashboardBloc>().add(
                RefreshDashboard(barId: activeBar.barId),
              );
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _BusinessDashboardHeader(
                    barName: activeBar.barName,
                    role: activeBar.role,
                    isOpen: dashboardState is DashboardLoaded
                        ? dashboardState.status.isOpen
                        : true,
                    onToggleOpen: () {
                      if (dashboardState is DashboardLoaded) {
                        context.read<DashboardBloc>().add(
                          ToggleBarOpen(
                            barId: activeBar.barId,
                            isOpen: !dashboardState.status.isOpen,
                          ),
                        );
                      }
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SummaryCardsGrid(
                          isOwnerOrAdmin: isOwnerOrAdmin,
                          stats: dashboardState is DashboardLoaded
                              ? dashboardState.stats
                              : null,
                          isLoading: dashboardState is DashboardLoading,
                        ),
                        const SizedBox(height: 24),
                        _LiveOrderQueue(
                          orders: dashboardState is DashboardLoaded
                              ? dashboardState.recentOrders
                              : null,
                          isLoading: dashboardState is DashboardLoading,
                        ),
                        const SizedBox(height: 24),
                        if (isOwnerOrAdmin) ...[
                          _PromoteCampaignCard(),
                          const SizedBox(height: 24),
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

class _BusinessDashboardHeader extends StatelessWidget {
  final String barName;
  final BarRole role;
  final bool isOpen;
  final VoidCallback onToggleOpen;

  const _BusinessDashboardHeader({
    required this.barName,
    required this.role,
    required this.isOpen,
    required this.onToggleOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dobar = context.dobarColors;
    final headerBg = dobar.surfaceElevated;
    final borderColor = theme.colorScheme.outline;
    final textColor = dobar.labelPrimary;
    final mutedTextColor = dobar.labelSecondary;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Welcome back, ${role.displayName}',
                style: TextStyle(color: mutedTextColor, fontSize: 12),
              ),
            ],
          ),
          Row(
            children: [
              // Open/Closed Toggle
              GestureDetector(
                onTap: onToggleOpen,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? successGreen.withValues(alpha: 0.15)
                        : errorRed.withValues(alpha: 0.15),
                    border: Border.all(
                      color: isOpen
                          ? successGreen.withValues(alpha: 0.3)
                          : errorRed.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isOpen ? successGreen : errorRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOpen ? 'Open' : 'Closed',
                        style: TextStyle(
                          color: isOpen ? successGreen : errorRed,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Search
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.search, size: 16, color: mutedTextColor),
              ),
              const SizedBox(width: 12),
              // Notifications
              Stack(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.notifications_outlined,
                      size: 16,
                      color: mutedTextColor,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: barzGold,
                        shape: BoxShape.circle,
                        border: Border.all(color: headerBg, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Theme Toggle
              const ThemeToggleButton(),
              const SizedBox(width: 12),
              // Switch to client
              TextButton.icon(
                icon: Icon(
                  Icons.person_outline,
                  size: 20,
                  color: mutedTextColor,
                ),
                label: Text(
                  'Switch to Client Mode',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: mutedTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(color: borderColor),
                  ),
                ),
                onPressed: () {
                  context.read<SessionBloc>().add(
                    const SessionEvent.switchToClientMode(),
                  );
                },
              ),
              const SizedBox(width: 12),
              // Avatar
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: barzGold.withValues(alpha: 0.1),
                  border: Border.all(color: barzGold.withValues(alpha: 0.3)),
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  'JD',
                  style: TextStyle(
                    color: barzGold,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCardsGrid extends StatelessWidget {
  final bool isOwnerOrAdmin;
  final DashboardStats? stats;
  final bool isLoading;

  const _SummaryCardsGrid({
    required this.isOwnerOrAdmin,
    this.stats,
    this.isLoading = false,
  });

  String _formatTrend(double percent) {
    if (percent >= 0) return '+${percent.toStringAsFixed(1)}%';
    return '${percent.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final orderStats = stats?.orders;
    final revenueStats = stats?.revenue;
    final avgTicket = stats?.averageTicket;

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 800
            ? 3
            : (constraints.maxWidth > 500 ? 2 : 1);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: constraints.maxWidth > 500 ? 2.2 : 2.5,
          children: [
            if (isOwnerOrAdmin)
              _BusinessSummaryCard(
                title: "Today's Revenue",
                value: isLoading
                    ? '-'
                    : (revenueStats?.formattedTotal ?? 'R\$ 0'),
                subtitle: 'vs yesterday',
                icon: Icons.attach_money_rounded,
                trendValue: revenueStats != null
                    ? _formatTrend(revenueStats.trendPercent)
                    : null,
                trendPositive: revenueStats != null
                    ? revenueStats.trendPercent >= 0
                    : true,
                isLoading: isLoading,
              ),
            _BusinessSummaryCard(
              title: "Active Orders",
              value: isLoading ? '-' : '${orderStats?.pending ?? 0}',
              subtitle: '${orderStats?.pending ?? 0} pending',
              icon: Icons.shopping_cart_outlined,
              isLoading: isLoading,
            ),
            if (isOwnerOrAdmin)
              _BusinessSummaryCard(
                title: "Avg. Ticket",
                value: isLoading ? '-' : (avgTicket?.formattedValue ?? 'R\$ 0'),
                subtitle: 'across all orders today',
                icon: Icons.analytics_outlined,
                isLoading: isLoading,
              ),
          ],
        );
      },
    );
  }
}

class _BusinessSummaryCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final String? trendValue;
  final bool trendPositive;
  final bool isLoading;

  const _BusinessSummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.trendValue,
    this.trendPositive = true,
    this.isLoading = false,
  });

  @override
  State<_BusinessSummaryCard> createState() => _BusinessSummaryCardState();
}

class _BusinessSummaryCardState extends State<_BusinessSummaryCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dobar = context.dobarColors;
    final isDark = context.isDark;
    final cardBg = dobar.surface;
    final borderColor = theme.colorScheme.outline;
    final textColor = dobar.labelPrimary;
    final mutedColor = dobar.labelSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedScale(
        scale: _isHovering ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isHovering
                ? (isDark ? const Color(0xFF262626) : dobar.surfaceElevated)
                : cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovering
                  ? barzGold.withValues(alpha: 0.5)
                  : borderColor,
            ),
            boxShadow: _isHovering
                ? [
                    BoxShadow(
                      color: barzGold.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: widget.isLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.title.toUpperCase(),
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.value,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (widget.trendValue != null) ...[
                                Text(
                                  '${widget.trendPositive ? "↑" : "↓"} ${widget.trendValue}',
                                  style: TextStyle(
                                    color: widget.trendPositive
                                        ? successGreen
                                        : errorRed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  widget.subtitle,
                                  style: TextStyle(
                                    color: mutedColor,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: barzGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(widget.icon, color: barzGold, size: 20),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LiveOrderQueue extends StatelessWidget {
  final RecentOrdersResponse? orders;
  final bool isLoading;

  const _LiveOrderQueue({this.orders, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dobar = context.dobarColors;
    final isDark = context.isDark;
    final cardBg = dobar.surface;
    final borderColor = theme.colorScheme.outline;
    final textColor = dobar.labelPrimary;
    final mutedColor = dobar.labelSecondary;

    final activeOrdersCount =
        orders?.orders
            .where((o) => o.status != 'completed' && o.status != 'cancelled')
            .length ??
        0;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE ORDER QUEUE',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$activeOrdersCount active orders',
                      style: TextStyle(color: mutedColor, fontSize: 11),
                    ),
                  ],
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: successGreen,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (orders == null || orders!.orders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No active orders right now.',
                  style: TextStyle(color: mutedColor, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders!.orders.length,
              separatorBuilder: (context, index) =>
                  Divider(color: borderColor, height: 1),
              itemBuilder: (context, index) {
                return _QueueOrderItem(
                  order: orders!.orders[index],
                  isDark: isDark,
                  borderColor: borderColor,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _QueueOrderItem extends StatelessWidget {
  final RecentOrder order;
  final bool isDark;
  final Color borderColor;

  const _QueueOrderItem({
    required this.order,
    required this.isDark,
    required this.borderColor,
  });

  Color _getStatusColor() {
    switch (order.status) {
      case 'pending':
        return warningOrange;
      case 'preparing':
        return barzGold;
      case 'ready':
        return successGreen;
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
        return 'Served';
      case 'cancelled':
        return 'Cancelled';
      default:
        return order.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final textColor = isDark ? textOnDark : textPrimary;
    final mutedColor = isDark ? textTertiary : textSecondary;
    final hoverColor = isDark ? Colors.white12 : Colors.black12;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        hoverColor: hoverColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: barzGold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    order.tableNumber != null
                        ? 'Table ${order.tableNumber}'
                        : (order.customerName ?? 'Walk-in'),
                    style: TextStyle(color: textColor, fontSize: 13),
                  ),
                  Text(
                    ' · ${order.itemsCount} items',
                    style: TextStyle(color: mutedColor, fontSize: 11),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Just now',
                    style: TextStyle(color: mutedColor, fontSize: 11),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusLabel().toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
                  style: TextStyle(
                    color: barzDark.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: barzDark,
                    foregroundColor: barzGold,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? textOnDark : textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Bars',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            TextButton.icon(
              onPressed: () => _navigateToCreateBar(context),
              icon: Icon(Icons.add, size: 18, color: barzGold),
              label: Text(
                'Add Bar',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: barzGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : surfaceWhite;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: barzGold,
              style: BorderStyle.solid,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: barzGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.add_business_rounded,
                  color: barzGold,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add Bar',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: barzGold,
                ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : surfaceWhite;
    final borderColor = isDark ? barzDarkMuted : surfaceDim;
    final textColor = isDark ? textOnDark : textPrimary;

    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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
                  color: barzGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.local_bar_rounded, color: barzGold, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bar.barName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: barzGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              bar.role.displayName,
              style: TextStyle(
                color: barzGold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
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
    final theme = Theme.of(context);
    final isOwnerOrAdmin =
        activeBar.role == BarRole.owner || activeBar.role == BarRole.admin;
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? textOnDark : textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickActionChip(
              icon: Icons.point_of_sale_rounded,
              label: 'Cashier',
              onTap: () => context.go(AppRoute.businessCashier.path),
            ),
            if (activeBar.canEditMenu)
              _QuickActionChip(
                icon: Icons.restaurant_menu_rounded,
                label: 'Edit Menu',
                onTap: () => context.go(AppRoute.businessMenu.path),
              ),
            if (isOwnerOrAdmin) ...[
              _QuickActionChip(
                icon: Icons.local_offer_rounded,
                label: 'New Promo',
                onTap: () => context.go(AppRoute.businessCampaigns.path),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : surfaceWhite;
    final borderColor = isDark ? barzDarkMuted : surfaceDim;
    final textColor = isDark ? textOnDark : textPrimary;

    return Material(
      color: highlighted ? barzGold : cardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: highlighted ? null : Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: highlighted ? barzDark : textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: highlighted ? barzDark : textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
