import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';
import 'package:barz/ui/business/business_shell.dart';
import 'wireframe_shell.dart';

/// The main app shell that switches between client and business views.
/// 
/// This widget is only shown for authenticated users (router handles auth guard).
/// It initializes the user session and determines which shell to show:
/// - [WireframeShell] for clients (no bar access)
/// - [BusinessShell] for bar owners/staff (has bar access)
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final SessionBloc _sessionBloc;

  @override
  void initState() {
    super.initState();
    _sessionBloc = getItInjector<SessionBloc>();
    // Initialize session - we know user is authenticated (router guards this)
    _sessionBloc.add(const SessionEvent.initialize());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SessionBloc>.value(
      value: _sessionBloc,
      child: BlocBuilder<SessionBloc, SessionState>(
        builder: (context, state) {
          return state.when(
            initial: () => const _LoadingView(),
            loading: () => const _LoadingView(),
            ready: (session, forceClientMode) {
              // Determine which shell to show based on bar access and role
              if (forceClientMode || session.barAccess.isEmpty) {
                return const WireframeShell();
              } else {
                return const BusinessShell();
              }
            },
            // On error, show client view with error message option
            error: (message) => const WireframeShell(),
            loggedOut: () => const WireframeShell(),
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
