enum LegalDocumentType {
  termsOfService,
  privacyPolicy;

  String get apiValue {
    switch (this) {
      case LegalDocumentType.termsOfService:
        return 'TERMS_OF_SERVICE';
      case LegalDocumentType.privacyPolicy:
        return 'PRIVACY_POLICY';
    }
  }

  String get displayName {
    switch (this) {
      case LegalDocumentType.termsOfService:
        return 'Terms of Service';
      case LegalDocumentType.privacyPolicy:
        return 'Privacy Policy';
    }
  }
}

enum LegalDocumentLanguage {
  portuguese,
  english,
  spanish;

  String get apiValue {
    switch (this) {
      case LegalDocumentLanguage.portuguese:
        return 'PT';
      case LegalDocumentLanguage.english:
        return 'EN';
      case LegalDocumentLanguage.spanish:
        return 'ES';
    }
  }

  String get displayName {
    switch (this) {
      case LegalDocumentLanguage.portuguese:
        return 'Português';
      case LegalDocumentLanguage.english:
        return 'English';
      case LegalDocumentLanguage.spanish:
        return 'Español';
    }
  }

  static LegalDocumentLanguage fromLocale(String locale) {
    if (locale.startsWith('pt')) return LegalDocumentLanguage.portuguese;
    if (locale.startsWith('es')) return LegalDocumentLanguage.spanish;
    return LegalDocumentLanguage.english;
  }
}

class LegalDocument {
  final LegalDocumentType type;
  final LegalDocumentLanguage language;
  final String content;

  LegalDocument({
    required this.type,
    required this.language,
    required this.content,
  });
}
