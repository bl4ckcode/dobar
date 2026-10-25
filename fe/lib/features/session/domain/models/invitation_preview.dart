/// Recipient-bound invitation preview data.
///
/// Returned only after the server confirms the authenticated user
/// matches the invitation's verified contact. Never derived locally.
class InvitationPreview {
  final String venueName;
  final String? venueAddress;
  final String? venueImageUrl;
  final String role;
  final String maskedRecipient;
  final DateTime expiresAt;
  final List<String> permissions;

  const InvitationPreview({
    required this.venueName,
    this.venueAddress,
    this.venueImageUrl,
    required this.role,
    required this.maskedRecipient,
    required this.expiresAt,
    required this.permissions,
  });

  factory InvitationPreview.fromJson(Map<String, dynamic> json) {
    return InvitationPreview(
      venueName: json['venue_name'] as String,
      venueAddress: json['venue_address'] as String?,
      venueImageUrl: json['venue_image_url'] as String?,
      role: json['role'] as String? ?? 'staff',
      maskedRecipient: json['masked_recipient'] as String? ?? '',
      expiresAt: DateTime.parse(json['expires_at'] as String),
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
