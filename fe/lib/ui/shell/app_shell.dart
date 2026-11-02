import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'wireframe_shell.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: getItInjector<SessionBloc>(),
    child: BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        if (state is SessionReady) return const WireframeShell();
        final l10n = AppLocalizations.of(context)!;
        return Scaffold(
          body: Center(
            child: state is SessionError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.invitation_load_error_title),
                      FilledButton(
                        onPressed: () async {
                          await getItInjector<SessionBloc>().initializeForEntry(
                            force: true,
                          );
                          if (context.mounted) GoRouter.of(context).refresh();
                        },
                        child: Text(l10n.invitation_retry),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        );
      },
    ),
  );
}
