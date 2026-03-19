import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';
import 'wireframe_shell.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final SessionBloc _sessionBloc;
  bool _redirectedToOnboarding = false;

  @override
  void initState() {
    super.initState();
    _sessionBloc = getItInjector<SessionBloc>();
    _sessionBloc.add(const SessionEvent.initialize());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SessionBloc>.value(
      value: _sessionBloc,
      child: BlocConsumer<SessionBloc, SessionState>(
        listener: (context, state) {
          state.whenOrNull(
            ready: (session, forceClientMode, error) {
              if (!forceClientMode &&
                  (session.isBusiness || session.barAccess.isNotEmpty)) {
                context.go(AppRoute.businessDashboard.path);
              }
            },
            loggedOut: () {
              AppRoute.login.go(context);
            },
          );
        },
        builder: (context, state) {
          return state.when(
            initial: () => const _LoadingView(),
            loading: () => const _LoadingView(),
            ready: (session, forceClientMode, error) {
              if (!_redirectedToOnboarding &&
                  !session.user.hasCompletedOnboarding) {
                _redirectedToOnboarding = true;
                final phone = session.user.phoneNumber;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  context.go('/onboarding', extra: {'phone': phone});
                });
                return const _LoadingView();
              }

              if (forceClientMode) {
                return const WireframeShell();
              }

              if (session.isBusiness || session.barAccess.isNotEmpty) {
                return const _LoadingView();
              }

              return const WireframeShell();
            },
            error: (message) => const _LoadingView(),
            loggedOut: () => const _LoadingView(),
          );
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}
