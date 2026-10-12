class PrivacySettings {
  final bool dataSharingEnabled;
  final bool locationEnabled;

  const PrivacySettings({
    this.dataSharingEnabled = false,
    this.locationEnabled = false,
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    return PrivacySettings(
      dataSharingEnabled: json['data_sharing_enabled'] ?? false,
      locationEnabled: json['location_enabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data_sharing_enabled': dataSharingEnabled,
      'location_enabled': locationEnabled,
    };
  }

  PrivacySettings copyWith({bool? dataSharingEnabled, bool? locationEnabled}) {
    return PrivacySettings(
      dataSharingEnabled: dataSharingEnabled ?? this.dataSharingEnabled,
      locationEnabled: locationEnabled ?? this.locationEnabled,
    );
  }
}
