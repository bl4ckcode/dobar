import 'package:barz/features/checkin/presentation/checkin_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/session/shell_session.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/location/presentation/bloc/location_cubit.dart';
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:barz/features/cart/presentation/bloc/cart_state.dart';
import '../screens/home_connected.dart';
import '../screens/find_connected.dart';
import '../screens/profile_wireframe.dart';
import '../../features/cart/presentation/pages/cart_page.dart';

class _NavBarMetrics {
  static const double barHeight = 56.0;
  static const double notchMargin = 4.0;
  static const double fabDiameter = 64.0;
  static const double notchWidth = fabDiameter + (2 * notchMargin);
}

class WireframeShell extends StatefulWidget {
  /// Test seam: replaces the production tab pages (index 0..3).
  @visibleForTesting
  final Map<int, WidgetBuilder>? tabBuilders;

  const WireframeShell({super.key, this.tabBuilders});

  @override
  State<WireframeShell> createState() => _WireframeShellState();
}

class _WireframeShellState extends State<WireframeShell> {
  static const int _homeTab = 0;
  static const int _findTab = 1;
  static const int _cartTab = 2;
  static const int _profileTab = 3;

  int _selectedIndex = _homeTab;
  final GlobalKey<FindConnectedViewState> _findConnectedKey = GlobalKey();
  late final ShellSession _session = getItInjector<ShellSession>();
  late ScrollController _scroll = _newScrollController(_selectedIndex);

  ScrollController _newScrollController(int tab) =>
      ScrollController(initialScrollOffset: _session.scrollOffsets[tab] ?? 0);

  @override
  void initState() {
    super.initState();
    // Browsing never prompts: only pick up a position when permission was
    // already granted. Check-in/ordering explain and request it on demand.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LocationCubit>().restoreIfGranted();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Only the selected tab is mounted; build it on demand so hidden tabs hold
  /// no controllers, animations, listeners or requests.
  Widget _buildTab(int index) {
    final override = widget.tabBuilders?[index];
    final Widget page = override != null
        ? Builder(builder: override)
        : switch (index) {
            _homeTab => const HomeConnected(),
            _findTab => FindConnected(viewKey: _findConnectedKey),
            _cartTab => const CartPage(showBackButton: false),
            _ => const ProfileWireframe(),
          };
    return KeyedSubtree(
      key: ValueKey('shell-tab-$index'),
      child: PrimaryScrollController(controller: _scroll, child: page),
    );
  }

  Future<void> _onItemTapped(int index) async {
    if (index == _selectedIndex) return;
    if (index == _cartTab) {
      final cart = getItInjector<CartBloc>().state;
      final venue = cart is CartLoaded
          ? cart.barId ?? cart.cart.items.firstOrNull?.barId
          : cart is CheckoutSuccess
          ? cart.result.barId
          : null;
      if (venue != null && !await CheckinGate.ensure(context, venue)) return;
      if (!mounted) return;
    }
    // Save the leaving tab's scroll offset, then swap controllers.
    if (_scroll.hasClients) {
      _session.scrollOffsets[_selectedIndex] = _scroll.offset;
    }
    // Account/benefit changes happen in Profile: refresh Home on return.
    if (_selectedIndex == _profileTab) _session.invalidateHome();
    final previous = _scroll;
    setState(() {
      _selectedIndex = index;
      _scroll = _newScrollController(index);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    if (index == _findTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _findConnectedKey.currentState?.loadBarsIfNeeded();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getItInjector<CartBloc>(),
      child: BlocListener<CartBloc, CartState>(
        listenWhen: (prev, curr) => curr is CheckoutSuccess,
        // A purchase changes promo/cashback/coupon counts: refresh Home.
        listener: (context, state) => _session.invalidateHome(),
        child: Scaffold(
          extendBody: true,
          body: _buildTab(_selectedIndex),
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
                          isSelected: _selectedIndex == 2,
                          onTap: () => _onItemTapped(2),
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
                  isSelected: _selectedIndex == 3,
                  onTap: () => _onItemTapped(3),
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
