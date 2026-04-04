enum NotificationType {
  orderUpdate,
  system,
  promotion,
}

class NotificationModel {
  final int id;
  final int userId;
  final String title;
  final String message;
  final NotificationType type;
  final bool isRead;
  final String? referenceId;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.referenceId,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      message: json['message'],
      type: _parseType(json['notification_type']),
      isRead: json['is_read'] ?? false,
      referenceId: json['reference_id']?.toString(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  static NotificationType _parseType(String? type) {
    switch (type) {
      case 'order_update':
        return NotificationType.orderUpdate;
      case 'promotion':
        return NotificationType.promotion;
      case 'system':
      default:
        return NotificationType.system;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'notification_type': _typeToString(type),
      'is_read': isRead,
      'reference_id': referenceId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static String _typeToString(NotificationType type) {
    switch (type) {
      case NotificationType.orderUpdate:
        return 'order_update';
      case NotificationType.promotion:
        return 'promotion';
      case NotificationType.system:
        return 'system';
    }
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      referenceId: referenceId,
      createdAt: createdAt,
    );
  }
}
