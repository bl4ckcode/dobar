class ReactivateResult {
  final int barId;
  final String status;
  final String reactivatedAt;
  final String message;

  ReactivateResult({
    required this.barId,
    required this.status,
    required this.reactivatedAt,
    required this.message,
  });

  factory ReactivateResult.fromJson(Map<String, dynamic> json) =>
      ReactivateResult(
        barId: json['bar_id'] as int,
        status: json['status'] as String,
        reactivatedAt: json['reactivated_at'] as String,
        message: json['message'] as String,
      );
}
