import 'invitation_preview.dart';

class PendingInvitation {
  final int id;
  final int barId;
  final String code;
  final InvitationPreview preview;
  const PendingInvitation({
    required this.id,
    required this.barId,
    required this.code,
    required this.preview,
  });
  factory PendingInvitation.fromJson(Map<String, dynamic> json) =>
      PendingInvitation(
        id: json['invitation_id'] as int,
        barId: json['bar_id'] as int,
        code: json['invitation_code'] as String,
        preview: InvitationPreview.fromJson(json),
      );
}
