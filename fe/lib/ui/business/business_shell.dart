import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:barz/features/advertising/presentation/pages/campaigns_page.dart';
import 'package:barz/features/advertising/presentation/pages/subscription_plans_page.dart';
import 'business_dashboard_page.dart';
import 'business_settings_page.dart';
import 'cashier_page.dart';
import 'menu_management_page.dart';
import 'staff_management_page.dart';
import 'widgets/business_onboarding_view.dart';
import 'widgets/business_side_menu.dart';

/// Responsive breakpoint for switching between mobile and web layouts
const double kBusinessWebBreakpoint = 768.0;

class BusinessNavigation extends InheritedWidget {
  final void Function(int index) navigateToTab;
  final int currentIndex;

  const BusinessNavigation({
    super.key,
    required this.navigateToTab,
    required this.currentIndex,
    required super.child,
  });

  static BusinessNavigation? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BusinessNavigation>();
  }

  @override
  bool updateShouldNotify(BusinessNavigation oldWidget) {
    return currentIndex != oldWidget.currentIndex;
  }
}

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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

        // Build navigation items based on permissions
        final navItems = _buildNavItems(context, activeBar);
        _currentNavItems = navItems;

        // Ensure selected index is valid
        if (_selectedIndex >= navItems.length) {
          _selectedIndex = 0;
        }

        // Wrap in BusinessNavigation for child widgets to access navigation
        return BusinessNavigation(
          navigateToTab: navigateToTab,
          currentIndex: _selectedIndex,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWebLayout =
                  constraints.maxWidth >= kBusinessWebBreakpoint;

              if (isWebLayout) {
                return _buildWebLayout(
                  context,
                  session.barAccess,
                  activeBar,
                  navItems,
                );
              } else {
                return _buildMobileLayout(
                  context,
                  session.barAccess,
                  activeBar,
                  navItems,
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    List<BarAccess> bars,
    BarAccess activeBar,
    List<BusinessNavItem> navItems,
  ) {
    final colors = context.dobarColors;

    // For mobile bottom nav, we only show the first 5 items
    final bottomNavItems = navItems.take(5).toList();
    if (_selectedIndex >= bottomNavItems.length) {
      // If settings was selected, it will now be in the drawer
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: colors.navBackground,
        foregroundColor: colors.navIconSelected,
        leading: IconButton(
          icon: const Icon(LucideIcons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: _buildBarSelector(context, bars, activeBar, colors),
        actions: [
          IconButton(icon: const Icon(LucideIcons.bell), onPressed: () {}),
        ],
      ),
      drawer: _BusinessDrawer(
        bars: bars,
        activeBar: activeBar,
        navItems: navItems,
        selectedIndex: _selectedIndex,
        onNavItemSelected: (index) {
          Navigator.pop(context); // Close drawer
          navigateToTab(index);
        },
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: navItems.map((item) => item.page).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex < bottomNavItems.length
            ? _selectedIndex
            : 0,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: colors.navBackground,
        selectedItemColor: colors.navIconSelected,
        unselectedItemColor: colors.navIcon,
        items: bottomNavItems
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                label: item.label,
              ),
            )
            .toList(),
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
            onNavItemSelected: (index) =>
                setState(() => _selectedIndex = index),
            onBarSelected: (barId) {
              context.read<SessionBloc>().add(
                SessionEvent.switchActiveBar(barId: barId),
              );
              setState(() => _selectedIndex = 0);
            },
          ),
          // Vertical divider
          Container(width: 1, color: Colors.grey[300]),
          // Main content area
          Expanded(child: navItems[_selectedIndex].page),
        ],
      ),
    );
  }

  Widget _buildBarSelector(
    BuildContext context,
    List<BarAccess> bars,
    BarAccess activeBar,
    DobarColors colors,
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
                ? Icon(Icons.check, color: colors.labelSelected)
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
        setState(() => _selectedIndex = 0);
      },
    );
  }

  List<BusinessNavItem> _buildNavItems(
    BuildContext context,
    BarAccess activeBar,
  ) {
    final items = <BusinessNavItem>[
      const BusinessNavItem(
        icon: LucideIcons.layoutDashboard,
        label: 'Dashboard',
        page: BusinessDashboardPage(),
      ),
      const BusinessNavItem(
        icon: LucideIcons.shoppingBag,
        label: 'Orders',
        page: CashierPage(),
      ),
    ];

    if (activeBar.canEditMenu) {
      items.add(
        const BusinessNavItem(
          icon: LucideIcons.utensilsCrossed,
          label: 'Menu',
          page: MenuManagementPage(),
        ),
      );
    }

    if (activeBar.canManageStaff) {
      items.add(
        const BusinessNavItem(
          icon: LucideIcons.users,
          label: 'Team',
          page: StaffManagementPage(),
        ),
      );
    }

    if (activeBar.canManageAds) {
      items.add(
        const BusinessNavItem(
          icon: LucideIcons.megaphone,
          label: 'Marketing',
          page: CampaignsPage(),
        ),
      );
    }

    if (activeBar.canViewBilling || activeBar.canManageAds) {
      items.add(
        const BusinessNavItem(
          icon: LucideIcons.creditCard,
          label: 'Subscription',
          page: SubscriptionPlansPage(),
        ),
      );
    }

    items.add(
      const BusinessNavItem(
        icon: LucideIcons.settings,
        label: 'Settings',
        page: BusinessSettingsPage(),
      ),
    );

    return items;
  }
}

class _BusinessDrawer extends StatelessWidget {
  final List<BarAccess> bars;
  final BarAccess activeBar;
  final List<BusinessNavItem> navItems;
  final int selectedIndex;
  final Function(int) onNavItemSelected;

  const _BusinessDrawer({
    required this.bars,
    required this.activeBar,
    required this.navItems,
    required this.selectedIndex,
    required this.onNavItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outline;

    return Drawer(
      backgroundColor: colors.background,
      child: Column(
        children: [
          // Drawer Header
          DrawerHeader(
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: barzGold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.glassWater,
                    color: barzDark,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  activeBar.barName,
                  style: TextStyle(
                    color: colors.labelPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  activeBar.role.displayName,
                  style: TextStyle(color: colors.labelSecondary, fontSize: 13),
                ),
              ],
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ...navItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = selectedIndex == index;

                  return ListTile(
                    leading: Icon(
                      item.icon,
                      color: isSelected ? barzGold : colors.labelSecondary,
                      size: 22,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? barzGold : colors.labelPrimary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () => onNavItemSelected(index),
                  );
                }),

                const Divider(),

                // Client Mode
                ListTile(
                  leading: Icon(
                    LucideIcons.user,
                    color: colors.labelSecondary,
                    size: 22,
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.business_client_mode,
                    style: TextStyle(color: colors.labelPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.read<SessionBloc>().add(
                      const SessionEvent.switchToClientMode(),
                    );
                  },
                ),
              ],
            ),
          ),

          // Bottom area: Logout
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Divider(),
                ListTile(
                  leading: const Icon(
                    LucideIcons.logOut,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.read<SessionBloc>().add(
                      const SessionEvent.logout(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
