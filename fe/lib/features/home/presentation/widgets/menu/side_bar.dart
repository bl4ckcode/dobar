import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';
import 'package:barz/shared/domain/models/bottom_nav_bar/menu_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/router/app_routes.dart';

class SideBar extends StatefulWidget {
  const SideBar({super.key});

  @override
  State<SideBar> createState() => _SideBarState();
}

class _SideBarState extends State<SideBar> {
  Menu selectedSideMenu = sidebarMenus.first;

  void _handleMenuTap(Menu menu) {
    setState(() {
      selectedSideMenu = menu;
    });

    switch (menu.page) {
      case 'Home':
        Navigator.of(context).pop();
        break;
      case 'Search':
        Navigator.of(context).pop();
        break;
      case 'Favorites':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Favorites coming soon!')));
        break;
      case 'Help':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Help & Support coming soon!')),
        );
        break;
      case 'History':
        AppRoute.orders.push(context);
        break;
      case 'Notifications':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications coming soon!')),
        );
        break;
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: errorRed),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
        context.read<SessionBloc>().add(const SessionEvent.logout());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        width: 288,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF17203A),
          borderRadius: BorderRadius.all(Radius.circular(30)),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserCard(),
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 32, bottom: 16),
                child: Text(
                  "Browse".toUpperCase(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium!.copyWith(color: Colors.white70),
                ),
              ),
              ...sidebarMenus.map(
                (menu) => SideMenu(
                  menu: menu,
                  selectedMenu: selectedSideMenu,
                  press: () => _handleMenuTap(menu),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 40, bottom: 16),
                child: Text(
                  "History".toUpperCase(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium!.copyWith(color: Colors.white70),
                ),
              ),
              ...sidebarMenus2.map(
                (menu) => SideMenu(
                  menu: menu,
                  selectedMenu: selectedSideMenu,
                  press: () => _handleMenuTap(menu),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(24),
                child: ListTile(
                  onTap: _handleLogout,
                  leading: Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: errorRed.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.logout,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard() {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        final session = state.currentSession;
        final user = session?.user;

        return InfoCard(
          name: user?.displayName ?? 'Guest',
          bio: user?.email ?? 'Welcome to Barz',
        );
      },
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.name, required this.bio});

  final String name, bio;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.white24,
        child: Icon(CupertinoIcons.person, color: Colors.white),
      ),
      title: Text(name, style: const TextStyle(color: Colors.white)),
      subtitle: Text(bio, style: const TextStyle(color: Colors.white70)),
    );
  }
}

class SideMenu extends StatelessWidget {
  const SideMenu({
    super.key,
    required this.menu,
    required this.press,
    required this.selectedMenu,
  });

  final Menu menu;
  final VoidCallback press;
  final Menu selectedMenu;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedMenu == menu;
    final navItem = menu.navItem;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 24),
          child: Divider(color: Colors.white24, height: 1),
        ),
        Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              width: isSelected ? 288 : 0,
              height: 56,
              left: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF6792FF),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ),
            ListTile(
              onTap: press,
              leading: SizedBox(
                height: 36,
                width: 36,
                child: Icon(
                  isSelected ? navItem.displayIcon : navItem.icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              title: Text(
                menu.page,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
