enum CountryCode {
  br,
  pt,
  us,
  es,
  mx,
  ar,
  other,
}

class CountryFormConfig {
  final CountryCode code;
  final String name;
  final String phoneCode;
  final String currency;
  final String currencySymbol;
  final bool requiresBusinessId;
  final String? businessIdLabel;
  final String? businessIdMask;
  final String? businessIdHint;
  final bool requiresStateRegistration;
  final List<String> addressFields;

  const CountryFormConfig({
    required this.code,
    required this.name,
    required this.phoneCode,
    required this.currency,
    required this.currencySymbol,
    this.requiresBusinessId = false,
    this.businessIdLabel,
    this.businessIdMask,
    this.businessIdHint,
    this.requiresStateRegistration = false,
    this.addressFields = const ['street', 'number', 'neighborhood', 'city', 'state', 'postalCode'],
  });

  static CountryFormConfig forCountry(String countryCode) {
    final code = countryCode.toUpperCase();
    return _configs[code] ?? _configs['OTHER']!;
  }

  static const Map<String, CountryFormConfig> _configs = {
    'BR': CountryFormConfig(
      code: CountryCode.br,
      name: 'Brasil',
      phoneCode: '+55',
      currency: 'BRL',
      currencySymbol: 'R\$',
      requiresBusinessId: true,
      businessIdLabel: 'CNPJ',
      businessIdMask: '##.###.###/####-##',
      businessIdHint: '00.000.000/0000-00',
      requiresStateRegistration: true,
      addressFields: ['street', 'number', 'complement', 'neighborhood', 'city', 'state', 'cep'],
    ),
    'PT': CountryFormConfig(
      code: CountryCode.pt,
      name: 'Portugal',
      phoneCode: '+351',
      currency: 'EUR',
      currencySymbol: '€',
      requiresBusinessId: true,
      businessIdLabel: 'NIF',
      businessIdMask: '#########',
      businessIdHint: '123456789',
      addressFields: ['street', 'number', 'floor', 'postalCode', 'city', 'district'],
    ),
    'US': CountryFormConfig(
      code: CountryCode.us,
      name: 'United States',
      phoneCode: '+1',
      currency: 'USD',
      currencySymbol: '\$',
      requiresBusinessId: true,
      businessIdLabel: 'EIN',
      businessIdMask: '##-#######',
      businessIdHint: '12-3456789',
      addressFields: ['street', 'suite', 'city', 'state', 'zipCode'],
    ),
    'ES': CountryFormConfig(
      code: CountryCode.es,
      name: 'España',
      phoneCode: '+34',
      currency: 'EUR',
      currencySymbol: '€',
      requiresBusinessId: true,
      businessIdLabel: 'CIF',
      businessIdMask: 'A########',
      businessIdHint: 'B12345678',
      addressFields: ['street', 'number', 'floor', 'postalCode', 'city', 'province'],
    ),
    'MX': CountryFormConfig(
      code: CountryCode.mx,
      name: 'México',
      phoneCode: '+52',
      currency: 'MXN',
      currencySymbol: '\$',
      requiresBusinessId: true,
      businessIdLabel: 'RFC',
      businessIdMask: 'AAAA######AAA',
      businessIdHint: 'XAXX010101000',
      addressFields: ['street', 'extNumber', 'intNumber', 'neighborhood', 'city', 'state', 'postalCode'],
    ),
    'AR': CountryFormConfig(
      code: CountryCode.ar,
      name: 'Argentina',
      phoneCode: '+54',
      currency: 'ARS',
      currencySymbol: '\$',
      requiresBusinessId: true,
      businessIdLabel: 'CUIT',
      businessIdMask: '##-########-#',
      businessIdHint: '20-12345678-9',
      addressFields: ['street', 'number', 'floor', 'apartment', 'city', 'province', 'postalCode'],
    ),
    'OTHER': CountryFormConfig(
      code: CountryCode.other,
      name: 'Other',
      phoneCode: '+1',
      currency: 'USD',
      currencySymbol: '\$',
      requiresBusinessId: false,
      addressFields: ['street', 'city', 'state', 'postalCode', 'country'],
    ),
  };

  static List<String> get supportedCountries => _configs.keys.where((k) => k != 'OTHER').toList();
}
