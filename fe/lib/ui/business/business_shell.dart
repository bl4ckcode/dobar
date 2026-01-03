import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'business_dashboard_page.dart';
import 'cashier_page.dart';
import 'menu_management_page.dart';
import 'staff_management_page.dart';

/// Main shell for business users (bar owners/staff).
/// 
/// Provides navigation between:
/// - Dashboard: Overview and analytics
/// - Cashier: Order management (main view for cashiers)
/// - Menu: Menu and item management
/// - Staff: Staff management (owners/admins only)
/// - Settings: Bar settings
class BusinessShell extends StatefulWidget {
  const BusinessShell({super.key});

  @override
  State<BusinessShell> createState() => _BusinessShellState();
}

class _BusinessShellState extends State<BusinessShell> {
  int _selectedIndex = 0;

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

        if (activeBar == null) {
          return _buildNoBarSelected(context);
        }

        final pages = _buildPages(activeBar);
        final navItems = _buildNavItems(activeBar);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: barzBlack,
            foregroundColor: Colors.white,
            title: _buildBarSelector(context, session.barAccess, activeBar),
            actions: [
              // Switch to client mode button
              IconButton(
                icon: const Icon(Icons.person_outline),
                tooltip: 'Switch to Client Mode',
                onPressed: () {
                  context.read<SessionBloc>().add(const SessionEvent.switchToClientMode());
                },
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: pages,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: barzBlack,
            selectedItemColor: barzYellow,
            unselectedItemColor: Colors.white60,
            items: navItems,
          ),
        );
      },
    );
  }

  Widget _buildNoBarSelected(BuildContext context) {
    return Scaffold(
      backgroundColor: barzCream,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No bar selected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Select a bar from the menu to continue'),
          ],
        ),
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
                ? const Icon(Icons.check, color: barzYellow)
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

  List<Widget> _buildPages(BarAccess activeBar) {
    final pages = <Widget>[
      const BusinessDashboardPage(),
      const CashierPage(),
    ];

    if (activeBar.canEditMenu) {
      pages.add(const MenuManagementPage());
    }

    if (activeBar.canManageStaff) {
      pages.add(const StaffManagementPage());
    }

    return pages;
  }

  List<BottomNavigationBarItem> _buildNavItems(BarAccess activeBar) {
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.point_of_sale),
        label: 'Cashier',
      ),
    ];

    if (activeBar.canEditMenu) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.restaurant_menu),
        label: 'Menu',
      ));
    }

    if (activeBar.canManageStaff) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.people),
        label: 'Staff',
      ));
    }

    return items;
  }
}
