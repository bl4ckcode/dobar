class ContactSettings {
  final int barId;
  final String? phone;
  final String? email;
  final String? website;
  final String? instagram;
  final String? facebook;
  final String? whatsapp;
  final bool? whatsappEnabled;
  final String? updatedAt;

  ContactSettings({
    required this.barId,
    this.phone,
    this.email,
    this.website,
    this.instagram,
    this.facebook,
    this.whatsapp,
    this.whatsappEnabled,
    this.updatedAt,
  });

  factory ContactSettings.fromJson(Map<String, dynamic> json) =>
      ContactSettings(
        barId: json['bar_id'] as int,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        website: json['website'] as String?,
        instagram: json['instagram'] as String?,
        facebook: json['facebook'] as String?,
        whatsapp: json['whatsapp'] as String?,
        whatsappEnabled: json['whatsapp_enabled'] as bool?,
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (website != null) 'website': website,
        if (instagram != null) 'instagram': instagram,
        if (facebook != null) 'facebook': facebook,
        if (whatsapp != null) 'whatsapp': whatsapp,
        if (whatsappEnabled != null) 'whatsapp_enabled': whatsappEnabled,
      };
}
