import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'widgets/business_onboarding_view.dart';

const double kBusinessWebBreakpoint = 768.0;

class BusinessRootShell extends StatelessWidget {
  final Widget child;

  const BusinessRootShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        if (state is! SessionReady) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = state.session;
        final activeBar = session.activeBar;

        if (session.barAccess.isEmpty) {
          return const BusinessOnboardingView();
        }

        if (activeBar == null && session.barAccess.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<SessionBloc>().add(
              SessionEvent.switchActiveBar(barId: session.barAccess.first.barId),
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (activeBar == null) {
          return const BusinessOnboardingView();
        }

        final isWide = MediaQuery.of(context).size.width >= kBusinessWebBreakpoint;
        final currentRoute = AppRouteX.fromLocation(
          GoRouterState.of(context).uri.toString(),
        );
        final navItems = buildBusinessNavItems(
          canEditMenu: activeBar.canEditMenu,
          canManageAds: activeBar.canManageAds,
          canManageStaff: activeBar.canManageStaff,
        );

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                _BusinessSideNav(
                  bars: session.barAccess,
                  activeBar: activeBar,
                  navItems: navItems,
                  currentRoute: currentRoute,
                  onNavItemSelected: (route) => context.go(route.path),
                  onBarSelected: (barId) {
                    context.read<SessionBloc>().add(
                      SessionEvent.switchActiveBar(barId: barId),
                    );
                    context.go(AppRoute.businessDashboard.path);
                  },
                  onSwitchToClientMode: () {
                    context.read<SessionBloc>().add(const SessionEvent.switchToClientMode());
                  },
                ),
                Container(width: 1, color: Colors.grey[300]),
                Expanded(child: child),
              ],
            ),
          );
        } else {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: barzDark,
              foregroundColor: Colors.white,
              title: _buildBarSelector(context, session.barAccess, activeBar),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_outline),
                  tooltip: 'Client Mode',
                  onPressed: () {
                    context.read<SessionBloc>().add(const SessionEvent.switchToClientMode());
                  },
                ),
              ],
            ),
            body: child,
            bottomNavigationBar: _buildBottomNav(context, navItems, currentRoute),
          );
        }
      },
    );
  }

  Widget _buildBarSelector(
    BuildContext context,
    List<BarAccess> bars,
    BarAccess activeBar,
  ) {
    if (bars.length == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(activeBar.barName, style: const TextStyle(fontSize: 16)),
          Text(
            activeBar.role.displayName,
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      );
    }

    return PopupMenuButton<int>(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(activeBar.barName, style: const TextStyle(fontSize: 16)),
              Text(
                activeBar.role.displayName,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
      itemBuilder: (context) => bars.map((bar) {
        return PopupMenuItem<int>(
          value: bar.barId,
          child: ListTile(
            leading: bar.barId == activeBar.barId
                ? const Icon(Icons.check, color: barzGold)
                : const SizedBox(width: 24),
            title: Text(bar.barName),
            subtitle: Text(bar.role.displayName),
          ),
        );
      }).toList(),
      onSelected: (barId) {
        context.read<SessionBloc>().add(SessionEvent.switchActiveBar(barId: barId));
        context.go(AppRoute.businessDashboard.path);
      },
    );
  }

  Widget _buildBottomNav(
    BuildContext context,
    List<BusinessNavigationItem> navItems,
    AppRoute? currentRoute,
  ) {
    final selectedIndex = navItems.indexWhere((item) => item.route == currentRoute);
    
    return BottomNavigationBar(
      currentIndex: selectedIndex >= 0 ? selectedIndex : 0,
      onTap: (index) => context.go(navItems[index].route.path),
      type: BottomNavigationBarType.fixed,
      backgroundColor: barzDark,
      selectedItemColor: barzGold,
      unselectedItemColor: Colors.white60,
      items: navItems.map((item) => BottomNavigationBarItem(
        icon: Icon(item.icon),
        label: item.label,
      )).toList(),
    );
  }
}

class _BusinessSideNav extends StatelessWidget {
  final List<BarAccess> bars;
  final BarAccess activeBar;
  final List<BusinessNavigationItem> navItems;
  final AppRoute? currentRoute;
  final void Function(AppRoute) onNavItemSelected;
  final void Function(int) onBarSelected;
  final VoidCallback onSwitchToClientMode;

  const _BusinessSideNav({
    required this.bars,
    required this.activeBar,
    required this.navItems,
    required this.currentRoute,
    required this.onNavItemSelected,
    required this.onBarSelected,
    required this.onSwitchToClientMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: barzDark,
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: navItems.length,
              itemBuilder: (context, i) {
                final item = navItems[i];
                final isSelected = item.route == currentRoute;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onNavItemSelected(item.route),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? barzGold.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              color: isSelected ? barzGold : Colors.white70,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected ? barzGold : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          _buildClientModeButton(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: barzGold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront, color: barzDark, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeBar.barName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      activeBar.role.displayName,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (bars.length > 1)
                PopupMenuButton<int>(
                  icon: const Icon(Icons.unfold_more, color: Colors.white54),
                  onSelected: onBarSelected,
                  itemBuilder: (context) => bars.map((bar) {
                    return PopupMenuItem<int>(
                      value: bar.barId,
                      child: Row(
                        children: [
                          if (bar.barId == activeBar.barId)
                            const Icon(Icons.check, color: barzGold, size: 18)
                          else
                            const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          Text(bar.barName),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClientModeButton(BuildContext context) {
    return InkWell(
      onTap: onSwitchToClientMode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: const Row(
          children: [
            Icon(Icons.person_outline, color: Colors.white54, size: 22),
            SizedBox(width: 12),
            Text(
              'Switch to Client Mode',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
