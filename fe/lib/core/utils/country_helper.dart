/// Supported countries for the Dobar app
enum SupportedCountry {
  brazil('BR', '+55', '🇧🇷', 'Brazil', 'stone'),
  argentina('AR', '+54', '🇦🇷', 'Argentina', 'mercadopago'),
  usa('US', '+1', '🇺🇸', 'United States', 'stripe'),
  mexico('MX', '+52', '🇲🇽', 'Mexico', 'mercadopago'),
  chile('CL', '+56', '🇨🇱', 'Chile', 'mercadopago'),
  colombia('CO', '+57', '🇨🇴', 'Colombia', 'mercadopago'),
  peru('PE', '+51', '🇵🇪', 'Peru', 'mercadopago');

  final String code;
  final String phonePrefix;
  final String flag;
  final String name;
  final String paymentGateway;

  const SupportedCountry(
    this.code,
    this.phonePrefix,
    this.flag,
    this.name,
    this.paymentGateway,
  );

  /// Get display name with flag
  String get displayName => '$flag $name';

  /// Find country by code
  static SupportedCountry? fromCode(String? code) {
    if (code == null) return null;
    try {
      return SupportedCountry.values.firstWhere(
        (c) => c.code.toUpperCase() == code.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Find country by phone prefix
  static SupportedCountry? fromPhonePrefix(String prefix) {
    // Normalize prefix
    final normalizedPrefix = prefix.startsWith('+') ? prefix : '+$prefix';

    try {
      return SupportedCountry.values.firstWhere(
        (c) => normalizedPrefix.startsWith(c.phonePrefix),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Helper class for country-related operations
class CountryHelper {
  /// Detect country from phone number
  /// Returns country code (BR, AR, US, etc.) or default 'BR'
  static String detectCountryFromPhone(String? phone) {
    if (phone == null || phone.isEmpty) return 'BR';

    final country = SupportedCountry.fromPhonePrefix(phone);
    return country?.code ?? 'BR';
  }

  /// Get all supported country codes
  static List<String> get supportedCountryCodes {
    return SupportedCountry.values.map((c) => c.code).toList();
  }

  /// Get all countries for dropdown
  static List<SupportedCountry> get allCountries {
    return SupportedCountry.values.toList();
  }

  /// Check if country code is supported
  static bool isSupported(String code) {
    return SupportedCountry.fromCode(code) != null;
  }
}
