import 'package:barz/core/router/app_routes.dart';
import 'package:barz/features/authentication/presentation/bloc/login_state.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

enum PostLoginDestination { invitation, onboarding, home }

PostLoginDestination resolvePostLoginDestination({
  required Success state,
  String? pendingInvitationCode,
}) {
  if (pendingInvitationCode?.trim().isNotEmpty == true) {
    return PostLoginDestination.invitation;
  }
  if (state.isNewUser || state.needsOnboarding) {
    return PostLoginDestination.onboarding;
  }
  return PostLoginDestination.home;
}

void navigateAfterLogin(
  BuildContext context, {
  required Success state,
  String? pendingInvitationCode,
}) {
  switch (resolvePostLoginDestination(
    state: state,
    pendingInvitationCode: pendingInvitationCode,
  )) {
    case PostLoginDestination.invitation:
      final code = Uri.encodeComponent(pendingInvitationCode!.trim());
      context.go('${AppRoute.staffInvitationAccept.path}?code=$code');
      return;
    case PostLoginDestination.onboarding:
      AppRoute.goOnboarding(context, phone: state.phoneNumber);
      return;
    case PostLoginDestination.home:
      AppRoute.home.go(context);
      return;
  }
}
