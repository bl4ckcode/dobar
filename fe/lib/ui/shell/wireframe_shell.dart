import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/location/presentation/bloc/location_bloc.dart';
import 'package:barz/features/location/presentation/bloc/location_event.dart';
import 'package:barz/features/location/presentation/bloc/location_state.dart';
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:barz/features/cart/presentation/bloc/cart_state.dart';
import '../screens/home_connected.dart';
import '../screens/find_connected.dart';
import '../screens/profile_wireframe.dart';

class _NavBarMetrics {
  static const double barHeight = 56.0;
  static const double notchMargin = 4.0;
  static const double fabDiameter = 64.0;
  static const double notchWidth = fabDiameter + (2 * notchMargin);
}

class WireframeShell extends StatefulWidget {
  const WireframeShell({super.key});

  @override
  State<WireframeShell> createState() => _WireframeShellState();
}

class _WireframeShellState extends State<WireframeShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    HomeConnected(),
    FindConnected(),
    ProfileWireframe(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _loadDataWithLocation(
    BuildContext context,
    LocationState locationState,
  ) {
    // Legacy data loading removed in favor of HomeBloc in HomeConnected
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getItInjector<LocationBloc>()..add(GetCurrentLocation()),
        ),
        BlocProvider.value(value: getItInjector<CartBloc>()),
      ],
      child: BlocListener<LocationBloc, LocationState>(
        listener: (context, state) {
          if (!state.isLoading) {
            _loadDataWithLocation(context, state);
          }
        },
        child: Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              IndexedStack(index: _selectedIndex, children: _pages),
              if (const bool.fromEnvironment('dart.vm.product') == false)
                Positioned(
                  top: 48,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'debug_showcase_fab',
                    onPressed: () => AppRoute.showcase.push(context),
                    backgroundColor: barzGold.withValues(alpha: 0.9),
                    foregroundColor: barzDark,
                    tooltip: 'Design System Showcase (Debug)',
                    child: const Icon(Icons.palette, size: 20),
                  ),
                ),
            ],
          ),
          floatingActionButton: _CenterDockedFab(
            onPressed: () => AppRoute.checkin.push(context),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomAppBar(
            height: _NavBarMetrics.barHeight,
            color: barzDark,
            shape: const CircularNotchedRectangle(),
            notchMargin: _NavBarMetrics.notchMargin,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'Home',
                  isSelected: _selectedIndex == 0,
                  onTap: () => _onItemTapped(0),
                ),
                _NavItem(
                  icon: Icons.search_outlined,
                  selectedIcon: Icons.search,
                  label: 'Find',
                  isSelected: _selectedIndex == 1,
                  onTap: () => _onItemTapped(1),
                ),
                SizedBox(width: _NavBarMetrics.notchWidth),
                BlocBuilder<CartBloc, CartState>(
                  builder: (context, state) {
                    final itemCount = (state is CartLoaded)
                        ? state.cart.items.length
                        : 0;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _NavItem(
                          icon: Icons.shopping_cart_outlined,
                          selectedIcon: Icons.shopping_cart,
                          label: 'Cart',
                          isSelected: false,
                          onTap: () => AppRoute.cart.push(context),
                        ),
                        if (itemCount > 0)
                          Positioned(
                            top: 4,
                            right: 4,
                            child:
                                Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.deepOrange,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        itemCount > 9
                                            ? '9+'
                                            : itemCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                    .animate(
                                      onPlay: (controller) =>
                                          controller.repeat(reverse: true),
                                    )
                                    .scale(
                                      begin: const Offset(1, 1),
                                      end: const Offset(1.2, 1.2),
                                      duration: 1000.ms,
                                      curve: Curves.easeInOut,
                                    ),
                          ),
                      ],
                    );
                  },
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: 'Profile',
                  isSelected: _selectedIndex == 2,
                  onTap: () => _onItemTapped(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterDockedFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _CenterDockedFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return Transform.translate(
      offset: const Offset(0, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _NavBarMetrics.fabDiameter,
            height: _NavBarMetrics.fabDiameter,
            child:
                FloatingActionButton(
                      heroTag: 'shell_checkin_fab',
                      onPressed: onPressed,
                      backgroundColor: colors.buttonPrimary,
                      foregroundColor: colors.buttonOnPrimary,
                      elevation: 4,
                      shape: const CircleBorder(),
                      child: const Icon(Icons.qr_code_scanner, size: 28),
                    )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.1, 1.1),
                      duration: 1500.ms,
                      curve: Curves.easeInOut,
                    ),
          ),
          const SizedBox(height: 4),
          Text(
            'Check-in',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.navLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? colors.navIconSelected : colors.navIcon,
          size: 24,
        ),
      ),
    );
  }
}
