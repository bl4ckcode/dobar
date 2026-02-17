abstract class AuthResponse {
  String get accessToken;
  String get refreshToken;
  String get tokenType;
  int get expiresIn;
  bool get isNewUser;
  bool get mfaRequired;
  String? get mfaToken;

  factory AuthResponse({
    required String accessToken,
    required String refreshToken,
    String tokenType,
    int expiresIn,
    bool isNewUser,
    bool mfaRequired,
    String? mfaToken,
  }) = _AuthResponseImpl;

  factory AuthResponse.fromJson(Map<String, dynamic> json) =
      _AuthResponseImpl.fromJson;
}

class _AuthResponseImpl implements AuthResponse {
  @override
  final String accessToken;
  @override
  final String refreshToken;
  @override
  final String tokenType;
  @override
  final int expiresIn;
  @override
  final bool isNewUser;
  @override
  final bool mfaRequired;
  @override
  final String? mfaToken;

  const _AuthResponseImpl({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
    this.expiresIn = 3600,
    this.isNewUser = false,
    this.mfaRequired = false,
    this.mfaToken,
  });

  factory _AuthResponseImpl.fromJson(Map<String, dynamic> json) {
    final mfaRequired = json['mfa_required'] as bool? ?? false;

    if (mfaRequired) {
      return _AuthResponseImpl(
        accessToken: '',
        refreshToken: '',
        mfaRequired: true,
        mfaToken: json['mfa_token'] as String?,
      );
    }

    return _AuthResponseImpl(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int? ?? 3600,
      isNewUser: json['is_new_user'] as bool? ?? false,
    );
  }
}
