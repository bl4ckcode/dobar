class DeactivateResult {
  final int barId;
  final String status;
  final String deactivatedAt;
  final String? estimatedReturnDate;
  final String message;

  DeactivateResult({
    required this.barId,
    required this.status,
    required this.deactivatedAt,
    this.estimatedReturnDate,
    required this.message,
  });

  factory DeactivateResult.fromJson(Map<String, dynamic> json) =>
      DeactivateResult(
        barId: json['bar_id'] as int,
        status: json['status'] as String,
        deactivatedAt: json['deactivated_at'] as String,
        estimatedReturnDate: json['estimated_return_date'] as String?,
        message: json['message'] as String,
      );
}
