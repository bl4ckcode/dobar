class DeleteResult {
  final String message;
  final Map<String, int>? deletedRecords;
  final String? receiptId;

  DeleteResult({
    required this.message,
    this.deletedRecords,
    this.receiptId,
  });

  factory DeleteResult.fromJson(Map<String, dynamic> json) => DeleteResult(
        message: json['message'] as String,
        deletedRecords:
            (json['deleted_records'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as int)),
        receiptId: json['receipt_id'] as String?,
      );
}
