class NotificationPreferences {
  final bool pushNotificationsEnabled;
  final bool orderUpdatesEnabled;
  final bool promotionsEnabled;

  const NotificationPreferences({
    this.pushNotificationsEnabled = true,
    this.orderUpdatesEnabled = true,
    this.promotionsEnabled = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      pushNotificationsEnabled: json['push_notifications_enabled'] ?? true,
      orderUpdatesEnabled: json['order_updates_enabled'] ?? true,
      promotionsEnabled: json['promotions_enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push_notifications_enabled': pushNotificationsEnabled,
      'order_updates_enabled': orderUpdatesEnabled,
      'promotions_enabled': promotionsEnabled,
    };
  }

  NotificationPreferences copyWith({
    bool? pushNotificationsEnabled,
    bool? orderUpdatesEnabled,
    bool? promotionsEnabled,
  }) {
    return NotificationPreferences(
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      orderUpdatesEnabled: orderUpdatesEnabled ?? this.orderUpdatesEnabled,
      promotionsEnabled: promotionsEnabled ?? this.promotionsEnabled,
    );
  }
}
