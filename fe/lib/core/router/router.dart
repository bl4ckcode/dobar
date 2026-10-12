import 'package:barz/features/authentication/presentation/pages/login_page.dart';
import 'package:barz/features/bars/presentation/pages/bar_detail_page.dart';
import 'package:barz/features/bars/presentation/pages/bars_page.dart';
import 'package:barz/features/cart/presentation/pages/cart_page.dart';
import 'package:barz/features/home/presentation/pages/home_page.dart';
import 'package:barz/features/orders/presentation/pages/order_detail_page.dart';
import 'package:barz/features/orders/presentation/pages/orders_page.dart';
import 'package:flutter/material.dart';

class AppRouter {
  static const String login = '/login';
  static const String home = '/home';
  static const String cart = '/cart';
  static const String orders = '/orders';
  static const String orderDetail = '/order_detail';
  static const String bars = '/bars';
  static const String barDetail = '/bar_detail';

  static Route<dynamic> route(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return _buildRouteWithAnimation(const LoginPage());
      case home:
        return _buildRouteWithAnimation(const HomePage());
      case bars:
        final args = settings.arguments as Map<String, double>;
        return _buildRouteWithAnimation(
          BarsPage(latitude: args['latitude']!, longitude: args['longitude']!),
        );
      case barDetail:
        final barId = settings.arguments as int;
        return _buildRouteWithAnimation(BarDetailPage(barId: barId));
      case cart:
        return _buildRouteWithAnimation(const CartPage());
      case orders:
        return _buildRouteWithAnimation(const OrdersPage());
      case orderDetail:
        final orderId = settings.arguments as int;
        return _buildRouteWithAnimation(OrderDetailPage(orderId: orderId));
      default:
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(
      builder: (_) {
        return Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: const Center(child: Text('Page not found')),
        );
      },
    );
  }

  static PageRouteBuilder _buildRouteWithAnimation(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 1500),
    );
  }
}
