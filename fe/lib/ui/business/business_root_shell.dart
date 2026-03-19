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
    return BlocListener<SessionBloc, SessionState>(
      listener: (context, state) {
        if (state is SessionLoggedOut) {
          AppRoute.login.go(context);
        }
      },
      child: BlocBuilder<SessionBloc, SessionState>(
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
                SessionEvent.switchActiveBar(
                  barId: session.barAccess.first.barId,
                ),
              );
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (activeBar == null) {
            return const BusinessOnboardingView();
          }

          final isWide =
              MediaQuery.of(context).size.width >= kBusinessWebBreakpoint;
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
              body: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: child,
                      ),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: _BusinessSideNav(
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
                          context.read<SessionBloc>().add(
                            const SessionEvent.switchToClientMode(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
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
                      context.read<SessionBloc>().add(
                        const SessionEvent.switchToClientMode(),
                      );
                    },
                  ),
                ],
              ),
              body: child,
              bottomNavigationBar: _buildBottomNav(
                context,
                navItems,
                currentRoute,
              ),
            );
          }
        },
      ),
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
        context.read<SessionBloc>().add(
          SessionEvent.switchActiveBar(barId: barId),
        );
        context.go(AppRoute.businessDashboard.path);
      },
    );
  }

  Widget _buildBottomNav(
    BuildContext context,
    List<BusinessNavigationItem> navItems,
    AppRoute? currentRoute,
  ) {
    final selectedIndex = navItems.indexWhere(
      (item) => item.route == currentRoute,
    );

    return BottomNavigationBar(
      currentIndex: selectedIndex >= 0 ? selectedIndex : 0,
      onTap: (index) => context.go(navItems[index].route.path),
      type: BottomNavigationBarType.fixed,
      backgroundColor: barzDark,
      selectedItemColor: barzGold,
      unselectedItemColor: Colors.white60,
      items: navItems
          .map(
            (item) => BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.label,
            ),
          )
          .toList(),
    );
  }
}

class _BusinessSideNav extends StatefulWidget {
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
  State<_BusinessSideNav> createState() => _BusinessSideNavState();
}

class _BusinessSideNavState extends State<_BusinessSideNav> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: _isExpanded ? 240 : 64,
          decoration: const BoxDecoration(
            color: barzDark,
            border: Border(right: BorderSide(color: Colors.white12, width: 1)),
          ),
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 240,
              maxWidth: 240,
              child: Column(
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: widget.navItems.length,
                      itemBuilder: (context, i) {
                        final item = widget.navItems[i];
                        final isSelected = item.route == widget.currentRoute;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => widget.onNavItemSelected(item.route),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? barzGold.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      item.icon,
                                      color: isSelected
                                          ? barzGold
                                          : Colors.white70,
                                      size: 22,
                                    ),
                                    Expanded(
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        opacity: _isExpanded ? 1.0 : 0.0,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 12,
                                          ),
                                          child: Text(
                                            item.label,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                              color: isSelected
                                                  ? barzGold
                                                  : Colors.white70,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.clip,
                                            softWrap: false,
                                          ),
                                        ),
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
                  const Divider(color: Colors.white12, height: 1),
                  // Actions Area
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildActionRow(
                          icon: Icons.logout,
                          label: 'Logout',
                          onTap: () => context.read<SessionBloc>().add(
                            const SessionEvent.logout(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 80,
          right: -12,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: barzDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _isExpanded ? Icons.chevron_left : Icons.chevron_right,
                  color: Colors.white70,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: widget.bars.length > 1
          ? () => _showBarSelectorMenu(context)
          : null,
      hoverColor: Colors.white10,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
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
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _isExpanded ? 1.0 : 0.0,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.activeBar.barName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                          ),
                          Text(
                            widget.activeBar.role.displayName,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                          ),
                        ],
                      ),
                    ),
                    if (widget.bars.length > 1)
                      const Icon(Icons.unfold_more, color: Colors.white54),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBarSelectorMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final menuItems = widget.bars.map((bar) {
      final isActive = bar.barId == widget.activeBar.barId;
      return PopupMenuItem<int>(
        value: bar.barId,
        child: Row(
          children: [
            Icon(
              isActive ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isActive ? barzGold : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bar.barName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    bar.role.displayName,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();

    showMenu<int>(
      context: context,
      color: barzDarkLight,
      position: RelativeRect.fromRect(
        button.localToGlobal(Offset.zero) & button.size,
        Offset.zero & overlay.size,
      ),
      items: menuItems,
    ).then((value) {
      if (value != null && value != widget.activeBar.barId) {
        widget.onBarSelected(value);
      }
    });
  }

  Widget _buildActionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        hoverColor: Colors.white10,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.white54, size: 22),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _isExpanded ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
