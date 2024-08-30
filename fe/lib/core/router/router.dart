import 'package:barz/features/authentication/presentation/pages/login_page.dart';
import 'package:barz/features/home/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';

class AppRouter {
  static const String login = '/login';
  static const String home = '/home';

  static Route<dynamic> route(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return _buildRouteWithAnimation(const LoginPage());
      case home:
        return _buildRouteWithAnimation(const HomePage());
      default:
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Page not found')),
      );
    });
  }

  // This method builds a route with a custom animation
  static PageRouteBuilder _buildRouteWithAnimation(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // You can customize the transition here
        // Example: Fade transition with slide
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 1500), // Adjust the duration as needed
    );
  }
}
