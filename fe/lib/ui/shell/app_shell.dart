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
/// This is the root widget for authenticated users. It:
/// 1. Initializes the session on mount
/// 2. Shows loading while session is being fetched
/// 3. Switches between [WireframeShell] (client) and [BusinessShell] (business)
///    based on the user's bar access
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SessionBloc>(
      create: (context) {
        final bloc = getItInjector<SessionBloc>();
        // Initialize session on creation
        bloc.add(const SessionEvent.initialize());
        return bloc;
      },
      child: BlocBuilder<SessionBloc, SessionState>(
        builder: (context, state) {
          return state.when(
            initial: () => const _LoadingView(),
            loading: () => const _LoadingView(),
            ready: (session, forceClientMode) {
              // Determine which shell to show
              if (forceClientMode || session.barAccess.isEmpty) {
                return const WireframeShell();
              } else {
                return const BusinessShell();
              }
            },
            error: (message) => _ErrorView(
              message: message,
              onRetry: () {
                context.read<SessionBloc>().add(const SessionEvent.initialize());
              },
            ),
            loggedOut: () {
              // TODO: Navigate to login screen
              return const _LoadingView();
            },
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

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
