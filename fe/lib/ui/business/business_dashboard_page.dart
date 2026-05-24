import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/features/advertising/presentation/widgets/create_campaign_sheet.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:barz/features/bars/presentation/bloc/dashboard_bloc.dart';
import 'package:barz/features/bars/domain/models/dashboard_models.dart';
import 'package:barz/ui/business/widgets/business_toolbars.dart';

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
          key: ValueKey('dashboard_${activeBar.barId}'),
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
        return Material(
          color: dobar.background,
          child: RefreshIndicator(
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
                  child: ResponsiveCenterContainer(
                    maxWidthPercentage: 0.9,
                    maxWidth: 1400,
                    padding: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _QuickActionsSection(activeBar: activeBar),
                          const SizedBox(height: 24),
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
                            _PromoteCampaignCard(
                              key: const ValueKey('promote_campaign_card'),
                            ),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
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
    final isWeb = MediaQuery.of(context).size.width >= 768.0;

    if (!isWeb) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Space Grotesk',
                  ),
                ),
                Text(
                  'Welcome back, ${role.displayName}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            Row(
              children: [
                BusinessStatusToggle(isOpen: isOpen, onTap: onToggleOpen),
                const SizedBox(width: 8),
                const ProfilePopupMenu(),
              ],
            ),
          ],
        ),
      );
    }

    return BusinessStatusToolbar(
      title: 'Dashboard',
      subtitle: 'Welcome back, ${role.displayName}',
      isOpen: isOpen,
      onToggleOpen: onToggleOpen,
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
                ? (isDark ? const Color(0xFF111111) : dobar.surfaceElevated)
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

    // Filter out completed and cancelled orders — only show active pipeline
    final activeOrders =
        orders?.orders
            .where((o) => o.status != 'completed' && o.status != 'cancelled')
            .toList() ??
        [];

    final activeOrdersCount = activeOrders.length;

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
              itemCount: activeOrders.length,
              separatorBuilder: (context, index) =>
                  Divider(color: borderColor, height: 1),
              itemBuilder: (context, index) {
                return _QueueOrderItem(
                  order: activeOrders[index],
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

  /// Normalizes backend status to our display constants.
  String get _displayStatus =>
      order.status == 'confirmed' ? 'pending' : order.status;

  Color _getStatusColor() {
    switch (_displayStatus) {
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
    switch (_displayStatus) {
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
        return _displayStatus;
    }
  }

  /// Computes a human-readable relative time string from a DateTime.
  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final textColor = isDark ? textOnDark : textPrimary;
    final mutedColor = isDark ? textTertiary : textSecondary;
    final hoverColor = isDark ? Colors.white12 : Colors.black12;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactMobile = screenWidth < 400;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        hoverColor: hoverColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: isCompactMobile ? 60 : 72,
                      child: Text(
                        order.orderNumber,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: barzGold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        order.tableNumber != null
                            ? 'Table ${order.tableNumber}'
                            : (order.customerName ?? 'Walk-in'),
                        style: TextStyle(color: textColor, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (!isCompactMobile)
                      Text(
                        ' · ${order.itemsCount} items',
                        style: TextStyle(color: mutedColor, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isCompactMobile)
                    Text(
                      _relativeTime(order.createdAt),
                      style: TextStyle(color: mutedColor, fontSize: 11),
                    ),
                  if (!isCompactMobile) const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
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
                        fontSize: isCompactMobile ? 8 : 9,
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
  const _PromoteCampaignCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 450;

          return Flex(
            direction: isNarrow ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: isNarrow
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: barzDark.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      LucideIcons.megaphone,
                      color: barzDark,
                      size: 24,
                    ),
                  ),
                  if (isNarrow) ...[
                    const SizedBox(width: 16),
                    Text(
                      'Boost Your Sales',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: barzDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              if (isNarrow) const SizedBox(height: 12),
              if (!isNarrow) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Boost Your Sales',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: barzDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create a campaign and reach more customers in your area!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: barzDark.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                Text(
                  'Create a campaign and reach more customers in your area!',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: barzDark.withValues(alpha: 0.7),
                  ),
                ),
              if (isNarrow) const SizedBox(height: 20),
              if (!isNarrow) const SizedBox(width: 24),
              SizedBox(
                key: const ValueKey('promote_btn_wrapper'),
                width: isNarrow ? double.infinity : null,
                child: FilledButton.icon(
                  onPressed: () => CreateCampaignSheet.show(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: barzDark,
                    foregroundColor: barzGold,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text(
                    'Create Campaign',
                    key: ValueKey('promote_btn_label'),
                  ),
                ),
              ),
            ],
          );
        },
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
              icon: LucideIcons.wallet,
              label: 'Cashier',
              onTap: () => context.go(AppRoute.businessCashier.path),
            ),
            if (activeBar.canEditMenu)
              _QuickActionChip(
                icon: LucideIcons.utensilsCrossed,
                label: 'Edit Menu',
                onTap: () => context.go(AppRoute.businessMenu.path),
              ),
            if (isOwnerOrAdmin) ...[
              _QuickActionChip(
                icon: LucideIcons.tag,
                label: 'New Promo',
                onTap: () => context.go(AppRoute.businessCampaigns.path),
              ),
              _QuickActionChip(
                icon: LucideIcons.qrCode,
                label: 'Table QR',
                onTap: () => _showComingSoon(context, 'Table QR Generator'),
              ),
            ],
            if (activeBar.canManageStaff)
              _QuickActionChip(
                icon: LucideIcons.userPlus,
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
