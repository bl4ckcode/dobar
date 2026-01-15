import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:barz/features/advertising/presentation/pages/campaigns_page.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'business_dashboard_page.dart';
import 'cashier_page.dart';
import 'menu_management_page.dart';
import 'staff_management_page.dart';
import 'widgets/business_onboarding_view.dart';
import 'widgets/business_side_menu.dart';

/// Responsive breakpoint for switching between mobile and web layouts
const double kBusinessWebBreakpoint = 768.0;

/// Main shell for business users (bar owners/staff).
/// 
/// Responsive design:
/// - Mobile (< 768px): Bottom navigation bar
/// - Web/Tablet (≥ 768px): Side navigation menu
/// 
/// Provides navigation between:
/// - Dashboard: Overview and analytics
/// - Cashier: Order management (main view for cashiers)
/// - Menu: Menu and item management
/// - Ads: Campaign management (Master+ plans)
/// - Staff: Staff management (owners/admins only)
class BusinessShell extends StatefulWidget {
  const BusinessShell({super.key});

  @override
  State<BusinessShell> createState() => _BusinessShellState();
}

class _BusinessShellState extends State<BusinessShell> {
  int _selectedIndex = 0;
  late List<BusinessNavItem> _currentNavItems = [];

  void navigateToTab(int index) {
    if (index >= 0 && index < _currentNavItems.length) {
      setState(() => _selectedIndex = index);
    }
  }

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

        // New business user with no bars - show onboarding
        if (session.barAccess.isEmpty) {
          return const BusinessOnboardingView();
        }

        // Has bars but none selected - auto-select first or show selector
        if (activeBar == null && session.barAccess.isNotEmpty) {
          // Auto-select first bar
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

        // Build navigation items based on permissions
        final navItems = _buildNavItems(context, activeBar);
        _currentNavItems = navItems;
        
        // Ensure selected index is valid
        if (_selectedIndex >= navItems.length) {
          _selectedIndex = 0;
        }

        // Responsive: Use side menu for web, bottom nav for mobile
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWebLayout = constraints.maxWidth >= kBusinessWebBreakpoint;
            
            if (isWebLayout) {
              return _buildWebLayout(context, session.barAccess, activeBar, navItems);
            } else {
              return _buildMobileLayout(context, session.barAccess, activeBar, navItems);
            }
          },
        );
      },
    );
  }

  /// Mobile layout with bottom navigation bar
  Widget _buildMobileLayout(
    BuildContext context,
    List<BarAccess> bars,
    BarAccess activeBar,
    List<BusinessNavItem> navItems,
  ) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: barzBlack,
        foregroundColor: Colors.white,
        title: _buildBarSelector(context, bars, activeBar),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: AppLocalizations.of(context)!.business_client_mode,
            onPressed: () {
              context.read<SessionBloc>().add(const SessionEvent.switchToClientMode());
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: navItems.map((item) => item.page).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: barzBlack,
        selectedItemColor: barzYellow,
        unselectedItemColor: Colors.white60,
        items: navItems.map((item) => BottomNavigationBarItem(
          icon: Icon(item.icon),
          label: item.label,
        )).toList(),
      ),
    );
  }

  /// Web/tablet layout with side navigation menu
  Widget _buildWebLayout(
    BuildContext context,
    List<BarAccess> bars,
    BarAccess activeBar,
    List<BusinessNavItem> navItems,
  ) {
    return Scaffold(
      body: Row(
        children: [
          // Side navigation menu
          BusinessSideMenu(
            bars: bars,
            activeBar: activeBar,
            navItems: navItems,
            selectedIndex: _selectedIndex,
            onNavItemSelected: (index) => setState(() => _selectedIndex = index),
            onBarSelected: (barId) {
              context.read<SessionBloc>().add(
                SessionEvent.switchActiveBar(barId: barId),
              );
              setState(() => _selectedIndex = 0);
            },
            onSwitchToClientMode: () {
              context.read<SessionBloc>().add(const SessionEvent.switchToClientMode());
            },
          ),
          // Vertical divider
          Container(
            width: 1,
            color: Colors.grey[300],
          ),
          // Main content area
          Expanded(
            child: navItems[_selectedIndex].page,
          ),
        ],
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
                ? Icon(Icons.check, color: barzYellow)
                : const SizedBox(width: 24),
            title: Text(bar.barName),
            subtitle: Text(bar.role.displayName),
          ),
        );
      }).toList(),
      onSelected: (barId) {
        context.read<SessionBloc>().add(SessionEvent.switchActiveBar(barId: barId));
        setState(() => _selectedIndex = 0);
      },
    );
  }

  List<BusinessNavItem> _buildNavItems(BuildContext context, BarAccess activeBar) {
    final l10n = AppLocalizations.of(context)!;
    final items = <BusinessNavItem>[
      BusinessNavItem(
        icon: Icons.dashboard,
        label: l10n.business_dashboard,
        page: const BusinessDashboardPage(),
      ),
      BusinessNavItem(
        icon: Icons.point_of_sale,
        label: l10n.business_orders,
        page: const CashierPage(),
      ),
    ];

    if (activeBar.canEditMenu) {
      items.add(BusinessNavItem(
        icon: Icons.restaurant_menu,
        label: l10n.business_menu,
        page: const MenuManagementPage(),
      ));
    }

    if (activeBar.canManageAds) {
      items.add(BusinessNavItem(
        icon: Icons.campaign,
        label: l10n.business_promotions,
        page: const CampaignsPage(),
      ));
    }

    if (activeBar.canManageStaff) {
      items.add(BusinessNavItem(
        icon: Icons.people,
        label: 'Staff',
        page: const StaffManagementPage(),
      ));
    }

    return items;
  }
}

/// Navigation item for business shell
class BusinessNavItem {
  final IconData icon;
  final String label;
  final Widget page;

  const BusinessNavItem({
    required this.icon,
    required this.label,
    required this.page,
  });
}
