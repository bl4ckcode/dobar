import 'package:equatable/equatable.dart';

/// Represents a user's check-in at a bar/restaurant
class CheckinModel extends Equatable {
  final int id;
  final int userId;
  final int barId;
  final String barName;
  final String? barImageUrl;
  final String? tableNumber;
  final CheckinStatus status;
  final DateTime checkedInAt;
  final DateTime? checkedOutAt;

  const CheckinModel({
    required this.id,
    required this.userId,
    required this.barId,
    required this.barName,
    this.barImageUrl,
    this.tableNumber,
    required this.status,
    required this.checkedInAt,
    this.checkedOutAt,
  });

  factory CheckinModel.fromJson(Map<String, dynamic> json) {
    return CheckinModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      barId: json['bar_id'] ?? 0,
      barName: json['bar_name'] ?? '',
      barImageUrl: json['bar_image_url'],
      tableNumber: json['table_number'],
      status: CheckinStatus.fromString(json['status']),
      checkedInAt: DateTime.parse(json['checked_in_at']),
      checkedOutAt: json['checked_out_at'] != null
          ? DateTime.parse(json['checked_out_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'bar_id': barId,
      'bar_name': barName,
      'bar_image_url': barImageUrl,
      'table_number': tableNumber,
      'status': status.name,
      'checked_in_at': checkedInAt.toIso8601String(),
      'checked_out_at': checkedOutAt?.toIso8601String(),
    };
  }

  CheckinModel copyWith({
    String? tableNumber,
    CheckinStatus? status,
    DateTime? checkedOutAt,
  }) {
    return CheckinModel(
      id: id,
      userId: userId,
      barId: barId,
      barName: barName,
      barImageUrl: barImageUrl,
      tableNumber: tableNumber ?? this.tableNumber,
      status: status ?? this.status,
      checkedInAt: checkedInAt,
      checkedOutAt: checkedOutAt ?? this.checkedOutAt,
    );
  }

  /// Duration of the check-in
  Duration get duration {
    final endTime = checkedOutAt ?? DateTime.now();
    return endTime.difference(checkedInAt);
  }

  /// Whether the check-in is currently active
  bool get isActive => status == CheckinStatus.active;

  @override
  List<Object?> get props => [
        id,
        userId,
        barId,
        barName,
        barImageUrl,
        tableNumber,
        status,
        checkedInAt,
        checkedOutAt,
      ];
}

/// Check-in status
enum CheckinStatus {
  active,
  completed,
  cancelled;

  static CheckinStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'active':
        return CheckinStatus.active;
      case 'completed':
        return CheckinStatus.completed;
      case 'cancelled':
        return CheckinStatus.cancelled;
      default:
        return CheckinStatus.active;
    }
  }
}

/// QR code scan result
class QrScanResult {
  final int barId;
  final String? tableNumber;
  final String? specialCode;

  QrScanResult({
    required this.barId,
    this.tableNumber,
    this.specialCode,
  });

  /// Parse QR code data
  /// Expected format: barz://bar/{barId}?table={tableNumber}
  factory QrScanResult.fromQrCode(String qrCode) {
    final uri = Uri.tryParse(qrCode);
    if (uri == null) {
      throw FormatException('Invalid QR code format: $qrCode');
    }

    // Handle barz:// scheme
    if (uri.scheme == 'barz' && uri.host == 'bar') {
      final barId = int.tryParse(uri.pathSegments.firstOrNull ?? '');
      if (barId == null) {
        throw FormatException('Invalid bar ID in QR code');
      }
      return QrScanResult(
        barId: barId,
        tableNumber: uri.queryParameters['table'],
        specialCode: uri.queryParameters['code'],
      );
    }

    // Handle https scheme (web fallback)
    if (uri.scheme == 'https' && uri.pathSegments.contains('bar')) {
      final barIndex = uri.pathSegments.indexOf('bar');
      if (barIndex + 1 < uri.pathSegments.length) {
        final barId = int.tryParse(uri.pathSegments[barIndex + 1]);
        if (barId != null) {
          return QrScanResult(
            barId: barId,
            tableNumber: uri.queryParameters['table'],
            specialCode: uri.queryParameters['code'],
          );
        }
      }
    }

    throw FormatException('Unrecognized QR code format');
  }
}
