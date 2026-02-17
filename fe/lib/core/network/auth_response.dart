class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final bool isNewUser;
  final bool mfaRequired;
  final String? mfaToken;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
    this.expiresIn = 3600,
    this.isNewUser = false,
    this.mfaRequired = false,
    this.mfaToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final mfaRequired = json['mfa_required'] as bool? ?? false;

    if (mfaRequired) {
      return AuthResponse(
        accessToken: '',
        refreshToken: '',
        mfaRequired: true,
        mfaToken: json['mfa_token'] as String?,
      );
    }

    return AuthResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int? ?? 3600,
      isNewUser: json['is_new_user'] as bool? ?? false,
    );
  }
}
