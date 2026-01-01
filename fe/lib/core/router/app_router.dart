import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/ui/shell/wireframe_shell.dart';
import 'package:barz/ui/screens/create_bar_screen.dart';
import 'package:barz/features/bars/presentation/pages/bar_detail_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const WireframeShell(),
    ),
    GoRoute(
      path: '/bar/:barId',
      builder: (context, state) {
        final barId = int.parse(state.pathParameters['barId']!);
        return BarDetailPage(barId: barId);
      },
    ),
    GoRoute(
      path: '/create-bar',
      builder: (context, state) => const CreateBarScreen(),
    ),
  ],
);
