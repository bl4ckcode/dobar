import 'package:barz/core/router/app_routes.dart';
import 'package:barz/features/authentication/presentation/bloc/login_state.dart';
import 'package:flutter/widgets.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/data/storage/invitation_intent_store.dart';

Future<void> navigateAfterLogin(
  BuildContext context, {
  required Success state,
  String? pendingInvitationCode,
}) async {
  if (pendingInvitationCode != null) {
    await InvitationIntentStore.instance.save(pendingInvitationCode);
  }
  await getItInjector<SessionBloc>().initializeForEntry(force: true);
  if (context.mounted) AppRoute.home.go(context);
}
