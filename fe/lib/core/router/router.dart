import 'package:barz/features/home/presentation/pages/home_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppRouter {
  static String currentRoute = "/";

  static Route<dynamic> route(RouteSettings settings) {
    currentRoute = settings.name ?? "/";

    switch (settings.name) {
      case '/home_page':
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => const HomePage(),
        );

      default:
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name} \n must add default placeholder page'),
            ),
          ),
        );
    }
  }
}