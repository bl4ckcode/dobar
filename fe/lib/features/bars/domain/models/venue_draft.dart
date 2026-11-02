const venueSteps = [
  'find',
  'details',
  'receiving',
  'photos',
  'hours',
  'review',
];
const venueDays = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

class VenueDraft {
  final String id;
  final int version;
  final Map<String, dynamic> payload;
  final Map<String, String> steps;
  final String nextStep;
  final Map<String, dynamic>? bankSummary;
  final List<Map<String, dynamic>> assets;
  final int? barId;
  final String? updatedAt;

  const VenueDraft({
    required this.id,
    required this.version,
    required this.payload,
    required this.steps,
    required this.nextStep,
    this.bankSummary,
    this.assets = const [],
    this.barId,
    this.updatedAt,
  });

  factory VenueDraft.fromJson(Map<String, dynamic> json) => VenueDraft(
    id: json['id'] as String,
    version: json['version'] as int,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
    steps: Map<String, String>.from(json['steps'] as Map),
    nextStep: json['next_step'] as String,
    bankSummary: json['bank_summary'] == null
        ? null
        : Map<String, dynamic>.from(json['bank_summary'] as Map),
    assets: (json['assets'] as List? ?? [])
        .map((a) => Map<String, dynamic>.from(a as Map))
        .toList(),
    barId: json['bar_id'] as int?,
    updatedAt: json['updated_at'] as String?,
  );
}

class VenueDraftException implements Exception {
  final int? status;
  final Map<String, dynamic> details;
  const VenueDraftException(this.status, [this.details = const {}]);
}
