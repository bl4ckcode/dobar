import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/bars/presentation/bloc/bar_bloc.dart';
import 'package:barz/features/bars/presentation/bloc/bar_event.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_bloc.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_event.dart';
import 'package:barz/features/location/presentation/bloc/location_bloc.dart';
import 'package:barz/features/location/presentation/bloc/location_event.dart';
import 'package:barz/features/location/presentation/bloc/location_state.dart';
import 'package:barz/core/router/app_routes.dart';

const double _defaultLat = -23.5505;
const double _defaultLng = -46.6333;

class _NavBarMetrics {
  static const double barHeight = 56.0;
  static const double notchMargin = 4.0;
  static const double fabDiameter = 64.0;
  static const double notchWidth = fabDiameter + (2 * notchMargin);
}

class ClientRootShell extends StatefulWidget {
  final Widget child;

  const ClientRootShell({super.key, required this.child});

  @override
  State<ClientRootShell> createState() => _ClientRootShellState();
}

class _ClientRootShellState extends State<ClientRootShell> {
  bool _dataLoaded = false;

  void _loadDataWithLocation(BuildContext context, LocationState locationState) {
    if (_dataLoaded) return;
    
    final lat = locationState.currentLocation?.latitude ?? _defaultLat;
    final lng = locationState.currentLocation?.longitude ?? _defaultLng;
    
    context.read<BarBloc>().add(LoadNearbyBars(lat: lat, lng: lng));
    context.read<PromotionsBloc>().add(LoadPromotions(
      latitude: lat,
      longitude: lng,
    ));
    _dataLoaded = true;
  }

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final route = AppRouteX.fromLocation(location);
    
    switch (route) {
      case AppRoute.home:
        return 0;
      case AppRoute.orders:
        return 1;
      default:
        if (location.startsWith('/profile')) return 2;
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getItInjector<LocationBloc>()..add(GetCurrentLocation()),
        ),
        BlocProvider(
          create: (_) => getItInjector<BarBloc>(),
        ),
        BlocProvider(
          create: (_) => getItInjector<PromotionsBloc>(),
        ),
      ],
      child: BlocListener<LocationBloc, LocationState>(
        listener: (context, state) {
          if (!state.isLoading) {
            _loadDataWithLocation(context, state);
          }
        },
        child: Scaffold(
          body: widget.child,
          floatingActionButton: _CenterDockedFab(
            onPressed: () => context.push(AppRoute.checkin.path),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
                  isSelected: _getSelectedIndex(context) == 0,
                  onTap: () => context.go(AppRoute.home.path),
                ),
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long,
                  label: 'Orders',
                  isSelected: _getSelectedIndex(context) == 1,
                  onTap: () => context.go(AppRoute.orders.path),
                ),
                SizedBox(width: _NavBarMetrics.notchWidth),
                _NavItem(
                  icon: Icons.shopping_cart_outlined,
                  selectedIcon: Icons.shopping_cart,
                  label: 'Cart',
                  isSelected: false,
                  onTap: () => context.push(AppRoute.cart.path),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: 'Profile',
                  isSelected: _getSelectedIndex(context) == 2,
                  onTap: () => context.go('/profile'),
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
    return SizedBox(
      width: _NavBarMetrics.fabDiameter,
      height: _NavBarMetrics.fabDiameter,
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: barzGold,
        foregroundColor: barzDark,
        elevation: 0,
        shape: const CircleBorder(),
        child: const Icon(Icons.qr_code_scanner, size: 32),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? barzGold : Colors.white60,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? barzGold : Colors.white60,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
