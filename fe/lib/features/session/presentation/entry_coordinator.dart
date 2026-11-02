import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/features/session/data/storage/invitation_intent_store.dart';
import 'package:barz/features/session/domain/models/entry_destination.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';

class EntryCoordinator {
  final SessionBloc sessionBloc;
  EntryCoordinator(this.sessionBloc);

  Future<String?> resolve(String path) async {
    final intent = InvitationIntentStore.instance;
    if (intent.code != null) return invitationLocation(intent.code!);
    final state = await sessionBloc.initializeForEntry();
    if (state is! SessionReady) {
      return path == AppRoute.home.path ? null : AppRoute.home.path;
    }
    final session = state.session;
    switch (resolveEntry(session, forceClientMode: state.forceClientMode)) {
      case EntryDestination.invitation:
        final code = session.pendingInvitations.single.code;
        await intent.save(code);
        return invitationLocation(code);
      case EntryDestination.chooser:
        return '${AppRoute.staffInvitationAccept.path}?choose=true';
      case EntryDestination.onboarding:
        return AppRoute.onboarding.path;
      case EntryDestination.workspace:
        return path.startsWith('/business')
            ? null
            : workspaceLocation(session.activeBar!);
      case EntryDestination.customer:
        return path == AppRoute.home.path ? null : AppRoute.home.path;
    }
  }

  static String workspaceLocation(BarAccess access) =>
      access.hasPermission(Permission.analyticsView)
      ? AppRoute.businessDashboard.path
      : AppRoute.businessCashier.path;

  static String invitationLocation(String code) => Uri(
    path: AppRoute.staffInvitationAccept.path,
    queryParameters: {'code': code},
  ).toString();
}
