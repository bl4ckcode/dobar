class LoginRouteArguments {
  final String? pendingInvitationCode;
  final String? preferredProvider;

  const LoginRouteArguments({
    this.pendingInvitationCode,
    this.preferredProvider,
  });
}

class MfaChallengeArguments {
  final String token;
  final String? pendingInvitationCode;

  const MfaChallengeArguments({
    required this.token,
    this.pendingInvitationCode,
  });
}

class CompleteRegistrationArguments {
  final String? prefilledEmail;
  final String? prefilledName;
  final String? prefilledPhone;
  final bool termsAccepted;
  final bool privacyAccepted;
  final bool returnToCheckout;

  const CompleteRegistrationArguments({
    this.prefilledEmail,
    this.prefilledName,
    this.prefilledPhone,
    this.termsAccepted = false,
    this.privacyAccepted = false,
    this.returnToCheckout = false,
  });
}

class CreateBarArguments {
  final bool fromOnboarding;

  const CreateBarArguments({this.fromOnboarding = false});
}
